#!/bin/bash

# Ensure AWS CLI is configured and permissions are granted for EC2 operations

main_menu() {
  clear
  echo "============================="
  echo "🚀 EC2 Instance Management"
  echo "============================="
  echo "1) Launch EC2 in Default VPC"
  echo "2) Launch EC2 in Custom VPC"
  echo "3) Manage Existing EC2 Instances"
  echo "4) Exit"
  echo "============================="

  read -p "Choose an option: " choice

  case $choice in
    1) create_ec2_instance "default" ;;
    2) create_ec2_instance "custom" ;;
    3) manage_instances ;;
    4) echo -e "\n 👋 Exiting..."; exit 0 ;;
    *) echo -e "\n ❌ Invalid selection"; sleep 1; main_menu ;;
  esac
}

create_ec2_instance() {
  VPC_TYPE=$1
  echo -e "\n 🛠️ Launching EC2 in $VPC_TYPE VPC..."
  
  read -p "Enter the AMI ID (e.g., ami-03250b0e01c28d196): " AMI_ID

  echo -e "\n 🔑 Fetching EC2 Key Pairs..."
  KEYS=( $(aws ec2 describe-key-pairs --query "KeyPairs[].KeyName" --output text) )
  PS3=$'\n Select a key pair: '
  select KEY in "${KEYS[@]}"; do
    [ -n "$KEY" ] && break || echo -e "\n ❌ Invalid selection."
  done

  echo -e "\n 💻 Select the EC2 instance type:"
  TYPES=("t2.micro" "t2.small" "t2.medium" "t3.micro" "t3.small" "t3.medium")
  PS3=$'\n Choose an instance type: '
  select TYPE in "${TYPES[@]}"; do
    [ -n "$TYPE" ] && break || echo -e "\n ❌ Invalid selection."
  done

  echo -e "\n 🔒 Fetching security groups..."
  SG_IDS=( $(aws ec2 describe-security-groups --query "SecurityGroups[].GroupId" --output text) )
  PS3=$'\n Select a security group: '
  select SG in "${SG_IDS[@]}"; do
    [ -n "$SG" ] && break || echo -e "\n ❌ Invalid selection."
  done

  if [ "$VPC_TYPE" = "custom" ]; then
    echo -e "\n 🌐 Select Subnet in Custom VPC:"
    SUBNETS=( $(aws ec2 describe-subnets --filters Name=default-for-az,Values=false --query "Subnets[].SubnetId" --output text) )
    PS3=$'\n Choose a subnet: '
    select SUBNET in "${SUBNETS[@]}"; do
      [ -n "$SUBNET" ] && break || echo -e "\n ❌ Invalid selection."
    done
    SUBNET_OPTION="--subnet-id $SUBNET"
  else
    SUBNET_OPTION=""
  fi

  echo -e "\n 🚀 Launching EC2 instance..."
  INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --count 1 --instance-type "$TYPE" --key-name "$KEY" \
                --security-group-ids "$SG" $SUBNET_OPTION \
                --query 'Instances[0].InstanceId' --output text)
  echo -e "\n ✅ Launched Instance: $INSTANCE_ID"
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[].Instances[].PublicIpAddress" --output text)
  echo -e "🌐 Public IP: $PUBLIC_IP\n"
}

manage_instances() {
  echo -e "\n 🔍 Fetching EC2 instances..."
  instances=$(aws ec2 describe-instances \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name]" \
    --output text)

  instance_array=()
  while IFS=$'\t' read -r name id state; do
    formatted_line=$(printf "%-25s %-20s %-10s" "$name" "$id" "$state")
    instance_array+=("$formatted_line")
  done <<< "$instances"

  if [ ${#instance_array[@]} -eq 0 ]; then
    echo -e "\n ❌ No instances found."
    return
  fi

  echo -e "\n🖥️  Available EC2 Instances:"
  PS3=$'\nSelect an instance: '
  select choice in "${instance_array[@]}"; do
    if [ -n "$choice" ]; then
      INSTANCE_ID=$(echo "$choice" | awk '{print $2}')
      INSTANCE_NAME=$(echo "$choice" | awk '{print $1}')
      INSTANCE_STATE=$(echo "$choice" | awk '{print $3}')

      echo -e "\n ✅ Selected: $INSTANCE_NAME ($INSTANCE_ID) [$INSTANCE_STATE]"

      echo -e "\n What action would you like to perform?"
      PS3=$'\n Choose an action: '
      select ACTION in "Start" "Stop" "Reboot" "Hibernate" "Terminate" "Cancel"; do
        case $ACTION in
          Start)
            aws ec2 start-instances --instance-ids "$INSTANCE_ID"
            echo -e "\n ▶️ Instance starting..."
            break
            ;;
          Stop)
            aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
            echo -e "\n ⏹️ Instance stopping..."
            break
            ;;
          Reboot)
            aws ec2 reboot-instances --instance-ids "$INSTANCE_ID"
            echo -e "\n 🔄 Instance rebooting..."
            break
            ;;
          Hibernate)
            aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --hibernate
            echo -e "\n 💤 Instance hibernating..."
            break
            ;;
          Terminate)
            aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
            echo -e "\n 🗑️ Instance terminating..."
            break
            ;;
          Cancel)
            echo -e "\n 🚫 Canceled."
            break
            ;;
          *)
            echo -e "\n ❌ Invalid option."
            ;;
        esac
      done

      echo -e "\n🔁 Returning to main menu..."
      sleep 2
      main_menu
      return
    else
      echo -e "\n❌ Invalid selection."
    fi
  done
}

main_menu
