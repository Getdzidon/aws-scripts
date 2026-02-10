#!/bin/bash

#####--- EC2 Complete Management Script ---#####
#####---Important comments at the bottom of the script---#####

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

DEFAULT_REGION="eu-central-1"
DEFAULT_AMI="ami-03250b0e01c28d196"
KEY_PATH="/c/Users/getdz/Downloads"
REGION="$DEFAULT_REGION"

select_region() {
  echo -e "\n${CYAN} 🌍 Select AWS Region:${NC}"
  PS3=$'\nChoose region (default: eu-central-1): '
  select REGION in "eu-central-1 (Frankfurt)" "us-east-1 (N. Virginia)" "us-west-2 (Oregon)" "ap-southeast-1 (Singapore)" "Use default" "Custom"; do
    case $REGION in
      "eu-central-1 (Frankfurt)") REGION="eu-central-1"; break ;;
      "us-east-1 (N. Virginia)") REGION="us-east-1"; break ;;
      "us-west-2 (Oregon)") REGION="us-west-2"; break ;;
      "ap-southeast-1 (Singapore)") REGION="ap-southeast-1"; break ;;
      "Use default") REGION="$DEFAULT_REGION"; break ;;
      "Custom") read -p "Enter region code: " REGION; break ;;
    esac
  done
  echo -e "${GREEN}✅ Using region: ${WHITE}$REGION${NC}"
}

main_menu() {
  clear
  echo -e "${CYAN}==========================================${NC}"
  echo -e "${WHITE}🖥️  EC2 Complete Management${NC}"
  echo -e "${CYAN}==========================================${NC}"
  echo -e "${GREEN}1)${NC} Launch EC2 (Default VPC)"
  echo -e "${GREEN}2)${NC} Launch EC2 (Custom VPC)"
  echo -e "${GREEN}3)${NC} Launch EC2 with Custom Port"
  echo -e "${GREEN}4)${NC} Launch EC2 with User Data"
  echo -e "${GREEN}5)${NC} Manage Existing Instances"
  echo -e "${GREEN}6)${NC} Get Instance Details"
  echo -e "${GREEN}7)${NC} Connect to Instance (SSH)"
  echo -e "${GREEN}8)${NC} Create AMI from Instance"
  echo -e "${GREEN}9)${NC} Modify Instance Type"
  echo -e "${GREEN}10)${NC} Manage Elastic IPs"
  echo -e "${GREEN}11)${NC} Monitor Instance"
  echo -e "${GREEN}12)${NC} Bulk Operations"
  echo -e "${GREEN}13)${NC} Filter/Search Instances"
  echo -e "${GREEN}14)${NC} List All Instances"
  echo -e "${GREEN}15)${NC} Change Region (Current: ${WHITE}$REGION${GREEN})${NC}"
  echo -e "${GREEN}16)${NC} Exit"
  echo -e "${CYAN}==========================================${NC}"

  read -p "Choose an option: " choice

  case $choice in
    1) launch_ec2 "default" ;;
    2) launch_ec2 "custom" ;;
    3) launch_with_port ;;
    4) launch_with_userdata ;;
    5) manage_instances ;;
    6) get_instance_details ;;
    7) connect_to_instance ;;
    8) create_ami ;;
    9) modify_instance_type ;;
    10) manage_elastic_ips ;;
    11) monitor_instance ;;
    12) bulk_operations ;;
    13) filter_instances ;;
    14) list_instances ;;
    15) select_region; main_menu ;;
    16) echo -e "\n${YELLOW} 👋 Exiting...${NC}"; exit 0 ;;
    *) echo -e "\n${RED} ❌ Invalid selection${NC}"; sleep 1; main_menu ;;
  esac
}

launch_ec2() {
  VPC_TYPE=$1
  echo -e "\n 🚀 Launching EC2 in $VPC_TYPE VPC..."
  
  read -p "Enter AMI ID (default: $DEFAULT_AMI): " AMI_ID
  AMI_ID=${AMI_ID:-$DEFAULT_AMI}   # ${VAR:-default} uses default value if VAR is empty or unset
  
  read -p "Enter instance name tag: " TAG_NAME
  TAG_NAME=${TAG_NAME:-Demo-EC2-Instance}
  
  echo -e "\n 🔑 Fetching Key Pairs..."
  # Query AWS for available key pairs and store in array
  KEYS=( $(aws ec2 describe-key-pairs --region "$REGION" --query "KeyPairs[].KeyName" --output text) )
  PS3=$'\nSelect a key pair: '
  # [ -n "$KEY" ] checks if KEY is not empty
  select KEY in "${KEYS[@]}"; do
    [ -n "$KEY" ] && break || echo -e "\n ❌ Invalid selection."
  done
  
  echo -e "\n 💻 Select Instance Type:"
  TYPES=("t2.micro" "t2.small" "t2.medium" "t3.micro" "t3.small" "t3.medium")
  PS3=$'\nChoose instance type: '
  select TYPE in "${TYPES[@]}"; do
    [ -n "$TYPE" ] && break || echo -e "\n ❌ Invalid selection."
  done
  
  echo -e "\n 🔒 Fetching Security Groups..."
  SG_IDS=( $(aws ec2 describe-security-groups --region "$REGION" --query "SecurityGroups[].GroupId" --output text) )
  PS3=$'\nSelect a security group: '
  select SG in "${SG_IDS[@]}"; do
    [ -n "$SG" ] && break || echo -e "\n ❌ Invalid selection."
  done
  
  if [ "$VPC_TYPE" = "custom" ]; then
    echo -e "\n 🌐 Select Subnet:"
    SUBNETS=( $(aws ec2 describe-subnets --region "$REGION" --filters Name=default-for-az,Values=false --query "Subnets[].SubnetId" --output text) )
    PS3=$'\nChoose subnet: '
    select SUBNET in "${SUBNETS[@]}"; do
      [ -n "$SUBNET" ] && break || echo -e "\n ❌ Invalid selection."
    done
    SUBNET_OPTION="--subnet-id $SUBNET"
  else
    SUBNET_OPTION=""
  fi
  
  echo -e "\n 🚀 Launching instance..."
  INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" --image-id "$AMI_ID" --count 1 --instance-type "$TYPE" --key-name "$KEY" \
                --security-group-ids "$SG" $SUBNET_OPTION \
                --query 'Instances[0].InstanceId' --output text)
  
  # Check exit status ($? = 0 means success)
  if [ $? -eq 0 ]; then
    # Tag the instance with a name
    aws ec2 create-tags --region "$REGION" --resources "$INSTANCE_ID" --tags Key=Name,Value="$TAG_NAME"
    echo -e "\n ✅ Instance launched: $INSTANCE_ID"
    echo -e "⏳ Waiting for instance to run..."
    # Wait until instance is in running state
    aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"
    PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" --query "Reservations[].Instances[].PublicIpAddress" --output text)
    echo -e "🌐 Public IP: $PUBLIC_IP"
    echo -e "\n 🔐 SSH Command:"
    echo -e "ssh -i $KEY_PATH/$KEY.pem ubuntu@$PUBLIC_IP\n"
  else
    echo -e "\n ❌ Failed to launch instance.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

launch_with_port() {
  echo -e "\n 🚀 Launching EC2 with Custom Port..."
  
  read -p "Enter AMI ID (default: $DEFAULT_AMI): " AMI_ID
  AMI_ID=${AMI_ID:-$DEFAULT_AMI}
  
  read -p "Enter instance name tag: " TAG_NAME
  TAG_NAME=${TAG_NAME:-Demo-EC2-Instance}
  
  echo -e "\n 🔑 Fetching Key Pairs..."
  KEYS=( $(aws ec2 describe-key-pairs --region "$REGION" --query "KeyPairs[].KeyName" --output text) )
  PS3=$'\nSelect a key pair: '
  select KEY in "${KEYS[@]}"; do
    [ -n "$KEY" ] && break
  done
  
  echo -e "\n 💻 Select Instance Type:"
  TYPES=("t2.micro" "t2.small" "t2.medium" "t3.micro" "t3.small" "t3.medium")
  PS3=$'\nChoose instance type: '
  select TYPE in "${TYPES[@]}"; do
    [ -n "$TYPE" ] && break
  done
  
  echo -e "\n 🔒 Fetching Security Groups..."
  # Query security groups with both ID and name
  SG_DATA=$(aws ec2 describe-security-groups --region "$REGION" --query "SecurityGroups[].[GroupId,GroupName]" --output text)
  
  sg_array=()
  # Read tab-separated values and build array with formatted strings
  while IFS=$'\t' read -r id name; do
    sg_array+=("$id ($name)")
  done <<< "$SG_DATA"
  
  PS3=$'\nSelect a security group: '
  select SG_CHOICE in "${sg_array[@]}"; do
    if [ -n "$SG_CHOICE" ]; then
      # Extract just the ID from the formatted string
      SG_ID=$(echo "$SG_CHOICE" | awk '{print $1}')
      break
    fi
  done
  
  echo -e "\n 🌐 Add custom port rule?"
  PS3=$'\nChoose: '
  select ADD_PORT in "Yes" "No"; do
    if [ "$ADD_PORT" = "Yes" ]; then
      read -p "Enter port number (e.g., 22, 80, 443): " CUSTOM_PORT
      read -p "Enter CIDR block (default: 0.0.0.0/0): " CUSTOM_CIDR
      CUSTOM_CIDR=${CUSTOM_CIDR:-0.0.0.0/0}
      
      echo -e "\n 🔐 Adding ingress rule..."
      # 2>/dev/null suppresses error messages if rule already exists
      aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" --protocol tcp --port "$CUSTOM_PORT" --cidr "$CUSTOM_CIDR" 2>/dev/null
      
      if [ $? -eq 0 ]; then
        echo -e "✅ Port $CUSTOM_PORT opened from $CUSTOM_CIDR"
      else
        echo -e "ℹ️  Rule may already exist"
      fi
    fi
    break
  done
  
  echo -e "\n 🚀 Launching instance..."
  INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" --image-id "$AMI_ID" --count 1 --instance-type "$TYPE" --key-name "$KEY" \
                --security-group-ids "$SG_ID" \
                --query 'Instances[0].InstanceId' --output text)
  
  if [ $? -eq 0 ]; then
    aws ec2 create-tags --region "$REGION" --resources "$INSTANCE_ID" --tags Key=Name,Value="$TAG_NAME"
    echo -e "\n ✅ Instance launched: $INSTANCE_ID"
    echo -e "⏳ Waiting for instance to run..."
    aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"
    PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" --query "Reservations[].Instances[].PublicIpAddress" --output text)
    echo -e "🌐 Public IP: $PUBLIC_IP\n"
  else
    echo -e "\n ❌ Failed to launch instance.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

launch_with_userdata() {
  echo -e "\n 🚀 Launching EC2 with User Data..."
  
  read -p "Enter AMI ID (default: $DEFAULT_AMI): " AMI_ID
  AMI_ID=${AMI_ID:-$DEFAULT_AMI}
  
  read -p "Enter instance name tag: " TAG_NAME
  TAG_NAME=${TAG_NAME:-Demo-EC2-Instance}
  
  echo -e "\n 🔑 Fetching Key Pairs..."
  KEYS=( $(aws ec2 describe-key-pairs --region "$REGION" --query "KeyPairs[].KeyName" --output text) )
  PS3=$'\nSelect a key pair: '
  select KEY in "${KEYS[@]}"; do
    [ -n "$KEY" ] && break
  done
  
  echo -e "\n 💻 Select Instance Type:"
  TYPES=("t2.micro" "t2.small" "t2.medium" "t3.micro" "t3.small" "t3.medium")
  PS3=$'\nChoose instance type: '
  select TYPE in "${TYPES[@]}"; do
    [ -n "$TYPE" ] && break
  done
  
  echo -e "\n 🔒 Fetching Security Groups..."
  SG_IDS=( $(aws ec2 describe-security-groups --region "$REGION" --query "SecurityGroups[].GroupId" --output text) )
  PS3=$'\nSelect a security group: '
  select SG in "${SG_IDS[@]}"; do
    [ -n "$SG" ] && break
  done
  
  echo -e "\n 📝 Enter User Data Script:"
  echo "Example: #!/bin/bash"
  echo "         sudo apt update -y && sudo apt upgrade -y"
  echo "         sudo apt install nginx -y"
  echo ""
  read -p "Enter user data file path (or press Enter to skip): " USERDATA_FILE
  
  if [ -n "$USERDATA_FILE" ] && [ -f "$USERDATA_FILE" ]; then
    USERDATA_OPTION="--user-data file://$USERDATA_FILE"
  else
    USERDATA_OPTION=""
  fi
  
  echo -e "\n 🚀 Launching instance..."
  INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" --image-id "$AMI_ID" --count 1 --instance-type "$TYPE" --key-name "$KEY" \
                --security-group-ids "$SG" $USERDATA_OPTION \
                --query 'Instances[0].InstanceId' --output text)
  
  if [ $? -eq 0 ]; then
    aws ec2 create-tags --region "$REGION" --resources "$INSTANCE_ID" --tags Key=Name,Value="$TAG_NAME"
    echo -e "\n ✅ Instance launched: $INSTANCE_ID\n"
  else
    echo -e "\n ❌ Failed to launch instance.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

manage_instances() {
  echo -e "\n 🔍 Fetching EC2 instances..."
  instances=$(aws ec2 describe-instances --region "$REGION" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name]" \
    --output text)
  
  instance_array=()
  while IFS=$'\t' read -r name id state; do
    formatted_line=$(printf "%-25s %-20s %-10s" "$name" "$id" "$state")
    instance_array+=("$formatted_line")
  done <<< "$instances"
  
  if [ ${#instance_array[@]} -eq 0 ]; then
    echo -e "\n ❌ No instances found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
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
      
      echo -e "\n 📋 Choose action:"
      PS3=$'\nSelect action: '
      select ACTION in "Start" "Stop" "Reboot" "Hibernate" "Terminate" "Cancel"; do
        case $ACTION in
          Start)
            echo -e "\n ⚠️  Starting $INSTANCE_ID"
            read -p "Confirm? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
              aws ec2 start-instances --region "$REGION" --instance-ids "$INSTANCE_ID"
              echo -e "\n ⏳ Waiting for instance to run..."
              aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"
              echo -e "✅ Instance is running."
            fi
            break
            ;;
          Stop)
            echo -e "\n ⚠️  Stopping $INSTANCE_ID"
            read -p "Confirm? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
              aws ec2 stop-instances --region "$REGION" --instance-ids "$INSTANCE_ID"
              echo -e "\n ⏳ Waiting for instance to stop..."
              aws ec2 wait instance-stopped --region "$REGION" --instance-ids "$INSTANCE_ID"
              echo -e "✅ Instance stopped."
            fi
            break
            ;;
          Reboot)
            echo -e "\n ⚠️  Rebooting $INSTANCE_ID"
            read -p "Confirm? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
              aws ec2 reboot-instances --region "$REGION" --instance-ids "$INSTANCE_ID"
              echo -e "✅ Instance rebooting."
            fi
            break
            ;;
          Hibernate)
            echo -e "\n ⚠️  Hibernating $INSTANCE_ID"
            read -p "Confirm? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
              aws ec2 stop-instances --region "$REGION" --instance-ids "$INSTANCE_ID" --hibernate
              echo -e "✅ Instance hibernating."
            fi
            break
            ;;
          Terminate)
            echo -e "\n ⚠️  Terminating $INSTANCE_ID"
            read -p "❗ This is permanent. Confirm? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
              aws ec2 terminate-instances --region "$REGION" --instance-ids "$INSTANCE_ID"
              echo -e "\n ⏳ Waiting for termination..."
              aws ec2 wait instance-terminated --region "$REGION" --instance-ids "$INSTANCE_ID"
              echo -e "✅ Instance terminated."
            fi
            break
            ;;
          Cancel)
            echo -e "\n 🚫 Canceled."
            break
            ;;
        esac
      done
      
      read -p "Press Enter to return to main menu..."
      main_menu
      return
    fi
  done
}

get_instance_details() {
  echo -e "\n 🔍 Fetching EC2 instances..."
  instances=$(aws ec2 describe-instances --region "$REGION" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId]" \
    --output text)
  
  instance_array=()
  while IFS=$'\t' read -r name id; do
    instance_array+=("$name ($id)")
  done <<< "$instances"
  
  if [ ${#instance_array[@]} -eq 0 ]; then
    echo -e "\n ❌ No instances found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  PS3=$'\nSelect an instance: '
  select choice in "${instance_array[@]}"; do
    if [ -n "$choice" ]; then
      INSTANCE_ID=$(echo "$choice" | grep -oP '\(i-[a-z0-9]+\)' | tr -d '()')
      
      echo -e "\n📊 Instance Details:\n"
      aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress,PrivateIpAddress,PublicDnsName,LaunchTime,Placement.AvailabilityZone]' \
        --output table
      
      read -p "Press Enter to return to main menu..."
      main_menu
      return
    fi
  done
}

connect_to_instance() {
  echo -e "\n 🔍 Fetching running instances..."
  instances=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, PublicIpAddress, KeyName]" \
    --output text)
  
  if [ -z "$instances" ]; then
    echo -e "\n ❌ No running instances found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  instance_array=()
  while IFS=$'\t' read -r name id ip key; do
    instance_array+=("$name ($id) - $ip")
  done <<< "$instances"
  
  PS3=$'\nSelect an instance: '
  select choice in "${instance_array[@]}"; do
    if [ -n "$choice" ]; then
      PUBLIC_IP=$(echo "$choice" | grep -oP '\d+\.\d+\.\d+\.\d+')
      INSTANCE_ID=$(echo "$choice" | grep -oP 'i-[a-z0-9]+')
      KEY_NAME=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" --query 'Reservations[].Instances[].KeyName' --output text)
      
      echo -e "\n🔐 SSH Command:"
      echo "ssh -i $KEY_PATH/$KEY_NAME.pem ubuntu@$PUBLIC_IP"
      echo ""
      read -p "Execute SSH connection now? (y/n): " confirm
      
      if [[ "$confirm" == "y" ]]; then
        ssh -i "$KEY_PATH/$KEY_NAME.pem" ubuntu@$PUBLIC_IP
      fi
      
      read -p "Press Enter to return to main menu..."
      main_menu
      return
    fi
  done
}

create_ami() {
  echo -e "\n 🔍 Fetching EC2 instances..."
  instances=$(aws ec2 describe-instances --region "$REGION" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name]" \
    --output text)
  
  instance_array=()
  while IFS=$'\t' read -r name id state; do
    instance_array+=("$name ($id) [$state]")
  done <<< "$instances"
  
  if [ ${#instance_array[@]} -eq 0 ]; then
    echo -e "\n ❌ No instances found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  PS3=$'\nSelect an instance: '
  select choice in "${instance_array[@]}"; do
    if [ -n "$choice" ]; then
      INSTANCE_ID=$(echo "$choice" | grep -oP 'i-[a-z0-9]+')
      
      read -p "Enter AMI name: " AMI_NAME
      read -p "Enter AMI description: " AMI_DESC
      
      echo -e "\n 📸 Creating AMI..."
      AMI_ID=$(aws ec2 create-image --region "$REGION" --instance-id "$INSTANCE_ID" --name "$AMI_NAME" --description "$AMI_DESC" --query 'ImageId' --output text)
      
      if [ $? -eq 0 ]; then
        echo -e "\n ✅ AMI created: $AMI_ID\n"
      else
        echo -e "\n ❌ Failed to create AMI.\n"
      fi
      
      read -p "Press Enter to return to main menu..."
      main_menu
      return
    fi
  done
}

modify_instance_type() {
  echo -e "\n 🔍 Fetching stopped instances..."
  instances=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=instance-state-name,Values=stopped" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, InstanceType]" \
    --output text)
  
  if [ -z "$instances" ]; then
    echo -e "\n ❌ No stopped instances found. Instance must be stopped to modify type.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  instance_array=()
  while IFS=$'\t' read -r name id type; do
    instance_array+=("$name ($id) - Current: $type")
  done <<< "$instances"
  
  PS3=$'\nSelect an instance: '
  select choice in "${instance_array[@]}"; do
    if [ -n "$choice" ]; then
      INSTANCE_ID=$(echo "$choice" | grep -oP 'i-[a-z0-9]+')
      
      echo -e "\n 💻 Select New Instance Type:"
      TYPES=("t2.micro" "t2.small" "t2.medium" "t3.micro" "t3.small" "t3.medium" "t3.large")
      PS3=$'\nChoose instance type: '
      select NEW_TYPE in "${TYPES[@]}"; do
        [ -n "$NEW_TYPE" ] && break
      done
      
      echo -e "\n 🔄 Modifying instance type..."
      aws ec2 modify-instance-attribute --region "$REGION" --instance-id "$INSTANCE_ID" --instance-type "{\"Value\": \"$NEW_TYPE\"}"
      
      if [ $? -eq 0 ]; then
        echo -e "\n ✅ Instance type changed to $NEW_TYPE\n"
      else
        echo -e "\n ❌ Failed to modify instance type.\n"
      fi
      
      read -p "Press Enter to return to main menu..."
      main_menu
      return
    fi
  done
}

manage_elastic_ips() {
  echo -e "\n 🌐 Elastic IP Management"
  PS3=$'\nChoose action: '
  select ACTION in "Allocate New EIP" "Associate EIP" "Disassociate EIP" "Release EIP" "List EIPs" "Cancel"; do
    case $ACTION in
      "Allocate New EIP")
        echo -e "\n 🚀 Allocating Elastic IP..."
        # Allocate new Elastic IP in VPC domain
        EIP=$(aws ec2 allocate-address --region "$REGION" --domain vpc --query 'PublicIp' --output text)
        echo -e "\n ✅ Allocated EIP: $EIP\n"
        ;;
      "Associate EIP")
        echo -e "\n 🔍 Fetching instances..."
        instances=$(aws ec2 describe-instances --region "$REGION" \
          --filters "Name=instance-state-name,Values=running" \
          --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId]" \
          --output text)
        
        instance_array=()
        while IFS=$'\t' read -r name id; do
          instance_array+=("$name ($id)")
        done <<< "$instances"
        
        PS3=$'\nSelect instance: '
        select inst in "${instance_array[@]}"; do
          # Extract instance ID using grep with Perl regex
          INSTANCE_ID=$(echo "$inst" | grep -oP 'i-[a-z0-9]+')
          break
        done
        
        read -p "Enter Elastic IP to associate: " EIP
        # Get allocation ID from the Elastic IP
        ALLOC_ID=$(aws ec2 describe-addresses --region "$REGION" --filters "Name=public-ip,Values=$EIP" --query 'Addresses[].AllocationId' --output text)
        
        aws ec2 associate-address --region "$REGION" --instance-id "$INSTANCE_ID" --allocation-id "$ALLOC_ID"
        echo -e "\n ✅ EIP associated\n"
        ;;
      "Disassociate EIP")
        read -p "Enter Elastic IP to disassociate: " EIP
        # Get association ID to disassociate
        ASSOC_ID=$(aws ec2 describe-addresses --region "$REGION" --filters "Name=public-ip,Values=$EIP" --query 'Addresses[].AssociationId' --output text)
        
        aws ec2 disassociate-address --region "$REGION" --association-id "$ASSOC_ID"
        echo -e "\n ✅ EIP disassociated\n"
        ;;
      "Release EIP")
        read -p "Enter Elastic IP to release: " EIP
        ALLOC_ID=$(aws ec2 describe-addresses --region "$REGION" --filters "Name=public-ip,Values=$EIP" --query 'Addresses[].AllocationId' --output text)
        
        aws ec2 release-address --region "$REGION" --allocation-id "$ALLOC_ID"
        echo -e "\n ✅ EIP released\n"
        ;;
      "List EIPs")
        echo -e "\n 🌐 Elastic IPs:\n"
        aws ec2 describe-addresses --region "$REGION" --query 'Addresses[].[PublicIp,InstanceId,AllocationId]' --output table
        echo ""
        ;;
      "Cancel")
        ;;
    esac
    break
  done
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

monitor_instance() {
  echo -e "\n 🔍 Fetching running instances..."
  instances=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId]" \
    --output text)
  
  if [ -z "$instances" ]; then
    echo -e "\n ❌ No running instances found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  instance_array=()
  # Parse tab-separated instance data
  while IFS=$'\t' read -r name id; do
    instance_array+=("$name ($id)")
  done <<< "$instances"
  
  PS3=$'\nSelect an instance: '
  select choice in "${instance_array[@]}"; do
    if [ -n "$choice" ]; then
      # Extract instance ID using grep with Perl regex
      INSTANCE_ID=$(echo "$choice" | grep -oP 'i-[a-z0-9]+')
      
      echo -e "\n 📊 Monitoring Options:"
      PS3=$'\nChoose: '
      select MON in "System Status" "Instance Status" "Console Output" "Cancel"; do
        case $MON in
          "System Status")
            echo -e "\n 🖥️  System Status:\n"
            # Show full system status check results
            aws ec2 describe-instance-status --region "$REGION" --instance-ids "$INSTANCE_ID" --output table
            ;;
          "Instance Status")
            echo -e "\n 📈 Instance Status:\n"
            # Show instance state and status checks
            aws ec2 describe-instance-status --region "$REGION" --instance-ids "$INSTANCE_ID" --query 'InstanceStatuses[].[InstanceState.Name,SystemStatus.Status,InstanceStatus.Status]' --output table
            ;;
          "Console Output")
            echo -e "\n 📝 Console Output (last 64KB):\n"
            # Get console output and show last 50 lines
            aws ec2 get-console-output --region "$REGION" --instance-id "$INSTANCE_ID" --query 'Output' --output text | tail -50
            ;;
          "Cancel")
            ;;
        esac
        break
      done
      
      read -p "Press Enter to return to main menu..."
      main_menu
      return
    fi
  done
}

bulk_operations() {
  echo -e "\n 🔍 Fetching EC2 instances..."
  instances=$(aws ec2 describe-instances --region "$REGION" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name]" \
    --output text)
  
  if [ -z "$instances" ]; then
    echo -e "\n ❌ No instances found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  echo -e "\n 🖥️  Available Instances:\n"
  # Format output with awk for better readability
  echo "$instances" | awk '{printf "%-25s %-20s %-10s\n", $1, $2, $3}'
  echo ""
  
  # User enters space-separated instance IDs
  read -p "Enter instance IDs (space-separated): " INSTANCE_IDS
  
  echo -e "\n 📋 Bulk Action:"
  PS3=$'\nChoose action: '
  select ACTION in "Start All" "Stop All" "Reboot All" "Terminate All" "Cancel"; do
    case $ACTION in
      "Start All")
        read -p "⚠️  Start all selected instances? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
          # Start multiple instances at once
          aws ec2 start-instances --region "$REGION" --instance-ids $INSTANCE_IDS
          echo -e "\n ✅ Starting instances...\n"
        fi
        ;;
      "Stop All")
        read -p "⚠️  Stop all selected instances? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
          aws ec2 stop-instances --region "$REGION" --instance-ids $INSTANCE_IDS
          echo -e "\n ✅ Stopping instances...\n"
        fi
        ;;
      "Reboot All")
        read -p "⚠️  Reboot all selected instances? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
          aws ec2 reboot-instances --region "$REGION" --instance-ids $INSTANCE_IDS
          echo -e "\n ✅ Rebooting instances...\n"
        fi
        ;;
      "Terminate All")
        read -p "❗ PERMANENTLY terminate all selected instances? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
          aws ec2 terminate-instances --region "$REGION" --instance-ids $INSTANCE_IDS
          echo -e "\n ✅ Terminating instances...\n"
        fi
        ;;
      "Cancel")
        ;;
    esac
    break
  done
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

filter_instances() {
  echo -e "\n 🔍 Filter Instances"
  PS3=$'\nFilter by: '
  select FILTER in "Name" "State" "Instance Type" "Cancel"; do
    case $FILTER in
      "Name")
        read -p "Enter name to search: " SEARCH_NAME
        echo -e "\n 🖥️  Matching Instances:\n"
        # Use wildcard pattern matching for name tag
        aws ec2 describe-instances --region "$REGION" \
          --filters "Name=tag:Name,Values=*$SEARCH_NAME*" \
          --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name, InstanceType]" \
          --output table
        ;;
      "State")
        echo -e "\n Select State:"
        PS3=$'\nChoose: '
        select STATE in "running" "stopped" "terminated" "pending"; do
          echo -e "\n 🖥️  Instances in $STATE state:\n"
          # Filter by instance state
          aws ec2 describe-instances --region "$REGION" \
            --filters "Name=instance-state-name,Values=$STATE" \
            --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, InstanceType]" \
            --output table
          break
        done
        ;;
      "Instance Type")
        read -p "Enter instance type (e.g., t2.micro): " INST_TYPE
        echo -e "\n 🖥️  Instances of type $INST_TYPE:\n"
        # Filter by instance type
        aws ec2 describe-instances --region "$REGION" \
          --filters "Name=instance-type,Values=$INST_TYPE" \
          --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name]" \
          --output table
        ;;
      "Cancel")
        ;;
    esac
    break
  done
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

list_instances() {
  echo -e "\n 🔍 Fetching all EC2 instances...\n"
  
  instances=$(aws ec2 describe-instances --region "$REGION" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name, InstanceType, PublicIpAddress]" \
    --output text)
  
  if [ -z "$instances" ]; then
    echo -e "❌ No instances found.\n"
  else
    echo -e "🖥️  EC2 Instances:\n"
    echo "$instances" | awk '{printf "%-25s %-20s %-12s %-12s %s\n", $1, $2, $3, $4, $5}'
    echo ""
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

main_menu


####--- NOTES ---####

# Prerequisites:
# - AWS CLI installed and configured
# - IAM permissions for EC2 operations
# - Key pair (.pem file) for SSH access

# Required IAM Permissions:
# - ec2:RunInstances, ec2:DescribeInstances
# - ec2:StartInstances, ec2:StopInstances, ec2:RebootInstances
# - ec2:TerminateInstances, ec2:ModifyInstanceAttribute
# - ec2:CreateImage, ec2:DescribeImages
# - ec2:AllocateAddress, ec2:AssociateAddress, ec2:ReleaseAddress
# - ec2:DescribeKeyPairs, ec2:DescribeSecurityGroups
# - ec2:DescribeSubnets, ec2:CreateTags
# - ec2:AuthorizeSecurityGroupIngress
# - ec2:DescribeInstanceStatus, ec2:GetConsoleOutput

# Configuration:
# - DEFAULT_REGION: eu-central-1 (can be changed dynamically)
# - DEFAULT_AMI: ami-03250b0e01c28d196 (Ubuntu in eu-central-1)
# - KEY_PATH: /c/Users/getdz/Downloads (location of .pem files)

# Instance Types:
# - t2.micro: 1 vCPU, 1 GB RAM (Free tier eligible)
# - t2.small: 1 vCPU, 2 GB RAM
# - t2.medium: 2 vCPU, 4 GB RAM
# - t3.micro: 2 vCPU, 1 GB RAM (Newer generation)
# - t3.small: 2 vCPU, 2 GB RAM
# - t3.medium: 2 vCPU, 4 GB RAM

# Instance States:
# - pending: Instance is launching
# - running: Instance is running
# - stopping: Instance is stopping
# - stopped: Instance is stopped
# - shutting-down: Instance is terminating
# - terminated: Instance is terminated

# Elastic IP:
# - Static public IPv4 address
# - Can be associated/disassociated from instances
# - Charged when not associated with a running instance

# User Data:
# - Script that runs on instance launch
# - Useful for automated setup and configuration
# - Must start with #!/bin/bash for bash scripts

# Bash Syntax Notes:
# - ${VAR:-default} uses default value if VAR is empty
# - [ -n "$var" ] checks if variable is not empty
# - $? contains exit status of last command (0 = success)
# - || means "if previous command fails, execute next"
# - 2>/dev/null suppresses error messages
