#!/bin/bash

#####--- VPC Management Script ---#####
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

main_menu() {
  clear
  echo -e "${CYAN}======================================${NC}"
  echo -e "${WHITE}🌐 VPC Management${NC}"
  echo -e "${CYAN}======================================${NC}"
  echo -e "${GREEN}1)${NC} Full VPC Setup (VPC + Subnets + IGW + Routes)"
  echo -e "${GREEN}2)${NC} Create VPC Only"
  echo -e "${GREEN}3)${NC} Create Subnet"
  echo -e "${GREEN}4)${NC} Create Internet Gateway"
  echo -e "${GREEN}5)${NC} Create Route Table"
  echo -e "${GREEN}6)${NC} Create Security Group"
  echo -e "${GREEN}7)${NC} Manage Security Group Rules"
  echo -e "${GREEN}8)${NC} List VPCs"
  echo -e "${GREEN}9)${NC} Delete VPC"
  echo -e "${GREEN}10)${NC} Exit"
  echo -e "${CYAN}======================================${NC}"

  read -p "Choose an option: " choice

  case $choice in
    1) full_vpc_setup ;;
    2) create_vpc ;;
    3) create_subnet ;;
    4) create_igw ;;
    5) create_route_table ;;
    6) create_security_group ;;
    7) manage_sg_rules ;;
    8) list_vpcs ;;
    9) delete_vpc ;;
    10) echo -e "\n${YELLOW} 👋 Exiting...${NC}"; exit 0 ;;
    *) echo -e "\n${RED} ❌ Invalid selection${NC}"; sleep 1; main_menu ;;
  esac
}

select_region() {
  echo -e "\n${CYAN} 🌍 Select AWS Region:${NC}"
  PS3=$'\nChoose region: '
  select REGION in "eu-central-1 (Frankfurt)" "us-east-1 (N. Virginia)" "us-west-2 (Oregon)" "Custom"; do
    case $REGION in
      "eu-central-1 (Frankfurt)") REGION="eu-central-1"; break ;;
      "us-east-1 (N. Virginia)") REGION="us-east-1"; break ;;
      "us-west-2 (Oregon)") REGION="us-west-2"; break ;;
      "Custom") read -p "Enter region code: " REGION; break ;;
    esac
  done
  echo -e "\n${GREEN} ✅ Selected region: ${WHITE}$REGION${NC}"
}

create_vpc() {
  echo -e "\n${BLUE} 🌐 Creating VPC...${NC}"
  
  select_region
  
  read -p "Enter VPC name: " VPC_NAME
  read -p "Enter CIDR block (default: 10.0.0.0/16): " CIDR_BLOCK
  CIDR_BLOCK=${CIDR_BLOCK:-10.0.0.0/16}
  
  echo -e "\n${CYAN} 🚀 Creating VPC with CIDR $CIDR_BLOCK...${NC}"
  VPC_ID=$(aws ec2 create-vpc --cidr-block "$CIDR_BLOCK" --region "$REGION" --query 'Vpc.VpcId' --output text)
  
  if [ $? -eq 0 ]; then
    aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="$VPC_NAME" --region "$REGION"
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames --region "$REGION"
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support --region "$REGION"
    
    echo -e "\n${GREEN} ✅ VPC created successfully!${NC}"
    echo -e "${CYAN}📍 VPC ID:${NC} ${WHITE}$VPC_ID${NC}\n"
  else
    echo -e "\n${RED} ❌ Failed to create VPC.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

select_vpc() {
  vpcs=$(aws ec2 describe-vpcs --region "$REGION" --query 'Vpcs[].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock]' --output text)
  
  if [ -z "$vpcs" ]; then
    echo -e "\n ❌ No VPCs found.\n"
    return 1
  fi
  
  echo -e "\n🌐 Available VPCs:\n"
  echo "$vpcs" | awk '{printf "%s %-20s %s\n", $1, $2, $3}'
  echo ""
  
  read -p "Enter VPC ID: " VPC_ID
  return 0
}

create_subnet() {
  echo -e "\n 📡 Creating Subnet..."
  
  select_region
  select_vpc || { main_menu; return; }
  
  read -p "Enter subnet name: " SUBNET_NAME
  read -p "Enter CIDR block (e.g., 10.0.1.0/24): " SUBNET_CIDR
  
  echo -e "\n 🌍 Select Availability Zone:"
  AZS=$(aws ec2 describe-availability-zones --region "$REGION" --query 'AvailabilityZones[].ZoneName' --output text)
  az_array=($AZS)
  PS3=$'\nChoose AZ: '
  select AZ in "${az_array[@]}"; do
    if [ -n "$AZ" ]; then
      break
    fi
  done
  
  echo -e "\n 🔒 Subnet type:"
  PS3=$'\nChoose: '
  select SUBNET_TYPE in "Public (auto-assign public IP)" "Private"; do
    break
  done
  
  echo -e "\n 🚀 Creating subnet..."
  SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SUBNET_CIDR" --availability-zone "$AZ" --region "$REGION" --query 'Subnet.SubnetId' --output text)
  
  if [ $? -eq 0 ]; then
    aws ec2 create-tags --resources "$SUBNET_ID" --tags Key=Name,Value="$SUBNET_NAME" --region "$REGION"
    
    if [[ "$SUBNET_TYPE" == "Public"* ]]; then
      aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch --region "$REGION"
      echo -e "\n ✅ Public subnet created!"
    else
      echo -e "\n ✅ Private subnet created!"
    fi
    
    echo -e "📍 Subnet ID: $SUBNET_ID\n"
  else
    echo -e "\n ❌ Failed to create subnet.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

create_igw() {
  echo -e "\n 🌍 Creating Internet Gateway..."
  
  select_region
  select_vpc || { main_menu; return; }
  
  read -p "Enter IGW name: " IGW_NAME
  
  echo -e "\n 🚀 Creating Internet Gateway..."
  IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" --query 'InternetGateway.InternetGatewayId' --output text)
  
  if [ $? -eq 0 ]; then
    aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value="$IGW_NAME" --region "$REGION"
    aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$REGION"
    
    echo -e "\n ✅ Internet Gateway created and attached!"
    echo -e "📍 IGW ID: $IGW_ID\n"
  else
    echo -e "\n ❌ Failed to create Internet Gateway.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

create_route_table() {
  echo -e "\n 🛣️ Creating Route Table..."
  
  select_region
  select_vpc || { main_menu; return; }
  
  read -p "Enter route table name: " RT_NAME
  
  echo -e "\n 🚀 Creating route table..."
  RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
  
  if [ $? -eq 0 ]; then
    aws ec2 create-tags --resources "$RT_ID" --tags Key=Name,Value="$RT_NAME" --region "$REGION"
    
    echo -e "\n ✅ Route table created!"
    echo -e "📍 Route Table ID: $RT_ID"
    
    echo -e "\n 🌐 Add route to Internet Gateway?"
    PS3=$'\nChoose: '
    select ADD_ROUTE in "Yes" "No"; do
      if [ "$ADD_ROUTE" = "Yes" ]; then
        igws=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text)
        if [ -n "$igws" ]; then
          IGW_ID=$(echo $igws | awk '{print $1}')
          aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$REGION"
          echo -e "\n ✅ Route to IGW added!"
        else
          echo -e "\n ❌ No IGW found for this VPC."
        fi
      fi
      break
    done
    
    echo -e "\n 📡 Associate with subnet?"
    PS3=$'\nChoose: '
    select ASSOC in "Yes" "No"; do
      if [ "$ASSOC" = "Yes" ]; then
        subnets=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].[SubnetId,Tags[?Key==`Name`].Value|[0]]' --output text)
        echo -e "\n📡 Subnets:\n$subnets\n"
        read -p "Enter Subnet ID: " SUBNET_ID
        aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID" --region "$REGION"
        echo -e "\n ✅ Route table associated with subnet!"
      fi
      break
    done
  else
    echo -e "\n ❌ Failed to create route table.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

create_security_group() {
  echo -e "\n 🔒 Creating Security Group..."
  
  select_region
  select_vpc || { main_menu; return; }
  
  read -p "Enter security group name: " SG_NAME
  read -p "Enter description: " SG_DESC
  
  echo -e "\n 🚀 Creating security group..."
  SG_ID=$(aws ec2 create-security-group --group-name "$SG_NAME" --description "$SG_DESC" --vpc-id "$VPC_ID" --region "$REGION" --query 'GroupId' --output text)
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ Security Group created!"
    echo -e "📍 Security Group ID: $SG_ID"
    
    echo -e "\n 🔓 Add inbound rules now?"
    PS3=$'\nChoose: '
    select ADD_RULES in "Yes" "No"; do
      if [ "$ADD_RULES" = "Yes" ]; then
        add_inbound_rule "$SG_ID"
      fi
      break
    done
  else
    echo -e "\n ❌ Failed to create security group.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

add_inbound_rule() {
  local SG=$1
  
  echo -e "\n 🔓 Select rule type:"
  PS3=$'\nChoose: '
  select RULE_TYPE in "SSH (22)" "HTTP (80)" "HTTPS (443)" "Custom TCP" "Custom UDP" "All Traffic" "Done"; do
    case $RULE_TYPE in
      "SSH (22)")
        PORT=22
        PROTOCOL="tcp"
        ;;
      "HTTP (80)")
        PORT=80
        PROTOCOL="tcp"
        ;;
      "HTTPS (443)")
        PORT=443
        PROTOCOL="tcp"
        ;;
      "Custom TCP")
        read -p "Enter port: " PORT
        PROTOCOL="tcp"
        ;;
      "Custom UDP")
        read -p "Enter port: " PORT
        PROTOCOL="udp"
        ;;
      "All Traffic")
        PORT=0-65535
        PROTOCOL="-1"
        ;;
      "Done")
        return
        ;;
    esac
    
    read -p "Enter source CIDR (default: 0.0.0.0/0): " SOURCE_CIDR
    SOURCE_CIDR=${SOURCE_CIDR:-0.0.0.0/0}
    
    if [ "$PROTOCOL" = "-1" ]; then
      aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol all --cidr "$SOURCE_CIDR" --region "$REGION"
    else
      aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol "$PROTOCOL" --port "$PORT" --cidr "$SOURCE_CIDR" --region "$REGION"
    fi
    
    echo -e "\n ✅ Rule added!"
    
    echo -e "\n Add another rule?"
    PS3=$'\nChoose: '
    select CONTINUE in "Yes" "No"; do
      if [ "$CONTINUE" = "No" ]; then
        return
      fi
      break
    done
  done
}

add_outbound_rule() {
  local SG=$1
  
  echo -e "\n 🔓 Select outbound rule type:"
  PS3=$'\nChoose: '
  select RULE_TYPE in "SSH (22)" "HTTP (80)" "HTTPS (443)" "Custom TCP" "Custom UDP" "All Traffic" "Done"; do
    case $RULE_TYPE in
      "SSH (22)")
        PORT=22
        PROTOCOL="tcp"
        ;;
      "HTTP (80)")
        PORT=80
        PROTOCOL="tcp"
        ;;
      "HTTPS (443)")
        PORT=443
        PROTOCOL="tcp"
        ;;
      "Custom TCP")
        read -p "Enter port: " PORT
        PROTOCOL="tcp"
        ;;
      "Custom UDP")
        read -p "Enter port: " PORT
        PROTOCOL="udp"
        ;;
      "All Traffic")
        PORT=0-65535
        PROTOCOL="-1"
        ;;
      "Done")
        return
        ;;
    esac
    
    read -p "Enter destination CIDR (default: 0.0.0.0/0): " DEST_CIDR
    DEST_CIDR=${DEST_CIDR:-0.0.0.0/0}
    
    if [ "$PROTOCOL" = "-1" ]; then
      aws ec2 authorize-security-group-egress --group-id "$SG" --protocol all --cidr "$DEST_CIDR" --region "$REGION"
    else
      aws ec2 authorize-security-group-egress --group-id "$SG" --protocol "$PROTOCOL" --port "$PORT" --cidr "$DEST_CIDR" --region "$REGION"
    fi
    
    echo -e "\n ✅ Outbound rule added!"
    
    echo -e "\n Add another rule?"
    PS3=$'\nChoose: '
    select CONTINUE in "Yes" "No"; do
      if [ "$CONTINUE" = "No" ]; then
        return
      fi
      break
    done
  done
}

delete_inbound_rule() {
  local SG=$1
  
  echo -e "\n 📋 Current Inbound Rules:\n"
  aws ec2 describe-security-groups --group-ids "$SG" --region "$REGION" --query 'SecurityGroups[].IpPermissions[]' --output table
  
  echo -e "\n 🗑️ Delete inbound rule:"
  read -p "Protocol (tcp/udp/-1 for all): " PROTOCOL
  
  if [ "$PROTOCOL" = "-1" ]; then
    read -p "Source CIDR: " SOURCE_CIDR
    aws ec2 revoke-security-group-ingress --group-id "$SG" --protocol all --cidr "$SOURCE_CIDR" --region "$REGION"
  else
    read -p "Port: " PORT
    read -p "Source CIDR: " SOURCE_CIDR
    aws ec2 revoke-security-group-ingress --group-id "$SG" --protocol "$PROTOCOL" --port "$PORT" --cidr "$SOURCE_CIDR" --region "$REGION"
  fi
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ Inbound rule deleted!"
  else
    echo -e "\n ❌ Failed to delete rule."
  fi
}

delete_outbound_rule() {
  local SG=$1
  
  echo -e "\n 📋 Current Outbound Rules:\n"
  aws ec2 describe-security-groups --group-ids "$SG" --region "$REGION" --query 'SecurityGroups[].IpPermissionsEgress[]' --output table
  
  echo -e "\n 🗑️ Delete outbound rule:"
  read -p "Protocol (tcp/udp/-1 for all): " PROTOCOL
  
  if [ "$PROTOCOL" = "-1" ]; then
    read -p "Destination CIDR: " DEST_CIDR
    aws ec2 revoke-security-group-egress --group-id "$SG" --protocol all --cidr "$DEST_CIDR" --region "$REGION"
  else
    read -p "Port: " PORT
    read -p "Destination CIDR: " DEST_CIDR
    aws ec2 revoke-security-group-egress --group-id "$SG" --protocol "$PROTOCOL" --port "$PORT" --cidr "$DEST_CIDR" --region "$REGION"
  fi
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ Outbound rule deleted!"
  else
    echo -e "\n ❌ Failed to delete rule."
  fi
}

manage_sg_rules() {
  echo -e "\n 🔒 Managing Security Group Rules..."
  
  select_region
  
  sgs=$(aws ec2 describe-security-groups --region "$REGION" --query 'SecurityGroups[].[GroupId,GroupName,VpcId]' --output text)
  
  if [ -z "$sgs" ]; then
    echo -e "\n ❌ No security groups found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  echo -e "\n🔒 Security Groups:\n"
  echo "$sgs" | awk '{printf "%-25s %-30s %s\n", $1, $2, $3}'
  echo ""
  
  read -p "Enter Security Group ID: " SG_ID
  
  echo -e "\n 📋 Action:"
  PS3=$'\nChoose: '
  select ACTION in "Add Inbound Rule" "Add Outbound Rule" "View Inbound Rules" "View Outbound Rules" "Delete Inbound Rule" "Delete Outbound Rule" "Cancel"; do
    case $ACTION in
      "Add Inbound Rule")
        add_inbound_rule "$SG_ID"
        ;;
      "Add Outbound Rule")
        add_outbound_rule "$SG_ID"
        ;;
      "View Inbound Rules")
        echo -e "\n 📋 Inbound Rules:\n"
        aws ec2 describe-security-groups --group-ids "$SG_ID" --region "$REGION" --query 'SecurityGroups[].IpPermissions[]' --output table
        ;;
      "View Outbound Rules")
        echo -e "\n 📋 Outbound Rules:\n"
        aws ec2 describe-security-groups --group-ids "$SG_ID" --region "$REGION" --query 'SecurityGroups[].IpPermissionsEgress[]' --output table
        ;;
      "Delete Inbound Rule")
        delete_inbound_rule "$SG_ID"
        ;;
      "Delete Outbound Rule")
        delete_outbound_rule "$SG_ID"
        ;;
      "Cancel")
        ;;
    esac
    break
  done
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

list_vpcs() {
  echo -e "\n 🔍 Fetching VPCs..."
  
  select_region
  
  vpcs=$(aws ec2 describe-vpcs --region "$REGION" --query 'Vpcs[].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock,IsDefault]' --output text)
  
  if [ -z "$vpcs" ]; then
    echo -e "\n ❌ No VPCs found.\n"
  else
    echo -e "\n🌐 VPCs in $REGION:\n"
    echo "$vpcs" | awk '{printf "%-25s %-20s %-18s %s\n", $1, $2, $3, ($4=="True"?"[Default]":"")}'
    echo ""
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

delete_vpc() {
  echo -e "\n 🗑️ Deleting VPC..."
  
  select_region
  select_vpc || { main_menu; return; }
  
  echo -e "\n ⚠️ You chose to DELETE VPC: $VPC_ID"
  read -p "❗ This will delete all associated resources. Are you sure? (y/n): " confirm
  
  if [[ "$confirm" == "y" ]]; then
    echo -e "\n 🗑️ Deleting VPC resources..."
    
    # Delete subnets
    SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text)
    for SUBNET in $SUBNETS; do
      aws ec2 delete-subnet --subnet-id "$SUBNET" --region "$REGION" 2>/dev/null
    done
    
    # Detach and delete IGW
    IGWS=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text)
    for IGW in $IGWS; do
      aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" --region "$REGION" 2>/dev/null
      aws ec2 delete-internet-gateway --internet-gateway-id "$IGW" --region "$REGION" 2>/dev/null
    done
    
    # Delete route tables
    RTS=$(aws ec2 describe-route-tables --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
    for RT in $RTS; do
      aws ec2 delete-route-table --route-table-id "$RT" --region "$REGION" 2>/dev/null
    done
    
    # Delete security groups
    SGS=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
    for SG in $SGS; do
      aws ec2 delete-security-group --group-id "$SG" --region "$REGION" 2>/dev/null
    done
    
    # Delete VPC
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION"
    
    if [ $? -eq 0 ]; then
      echo -e "\n ✅ VPC deleted successfully!\n"
    else
      echo -e "\n ❌ Failed to delete VPC. Some resources may still exist.\n"
    fi
  else
    echo -e "\n 🚫 Delete action canceled.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

full_vpc_setup() {
  echo -e "\n 🎯 Full VPC Setup...\n"
  
  select_region
  
  # VPC
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "🌐 STEP 1: Create VPC"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "VPC name: " VPC_NAME
  read -p "CIDR block (default: 10.0.0.0/16): " CIDR_BLOCK
  CIDR_BLOCK=${CIDR_BLOCK:-10.0.0.0/16}
  
  VPC_ID=$(aws ec2 create-vpc --cidr-block "$CIDR_BLOCK" --region "$REGION" --query 'Vpc.VpcId' --output text)
  aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="$VPC_NAME" --region "$REGION"
  aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames --region "$REGION"
  echo -e "\n ✅ VPC: $VPC_ID"
  
  # Public Subnet
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "📡 STEP 2: Create Public Subnet"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "Public subnet CIDR (default: 10.0.1.0/24): " PUB_CIDR
  PUB_CIDR=${PUB_CIDR:-10.0.1.0/24}
  
  AZS=$(aws ec2 describe-availability-zones --region "$REGION" --query 'AvailabilityZones[0].ZoneName' --output text)
  PUB_SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PUB_CIDR" --availability-zone "$AZS" --region "$REGION" --query 'Subnet.SubnetId' --output text)
  aws ec2 create-tags --resources "$PUB_SUBNET" --tags Key=Name,Value="$VPC_NAME-public" --region "$REGION"
  aws ec2 modify-subnet-attribute --subnet-id "$PUB_SUBNET" --map-public-ip-on-launch --region "$REGION"
  echo -e "\n ✅ Public Subnet: $PUB_SUBNET"
  
  # IGW
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "🌍 STEP 3: Create Internet Gateway"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" --query 'InternetGateway.InternetGatewayId' --output text)
  aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value="$VPC_NAME-igw" --region "$REGION"
  aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$REGION"
  echo -e "\n ✅ IGW: $IGW_ID"
  
  # Route Table
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "🛣️ STEP 4: Create Route Table"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
  aws ec2 create-tags --resources "$RT_ID" --tags Key=Name,Value="$VPC_NAME-public-rt" --region "$REGION"
  aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$REGION"
  aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$PUB_SUBNET" --region "$REGION"
  echo -e "\n ✅ Route Table: $RT_ID"
  
  # Security Group
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "🔒 STEP 5: Create Security Group"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  SG_ID=$(aws ec2 create-security-group --group-name "$VPC_NAME-sg" --description "Security group for $VPC_NAME" --vpc-id "$VPC_ID" --region "$REGION" --query 'GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$REGION"
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$REGION"
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0 --region "$REGION"
  echo -e "\n ✅ Security Group: $SG_ID (SSH, HTTP, HTTPS allowed)"
  
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "✅ FULL VPC SETUP COMPLETE!"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "🌐 VPC: $VPC_ID"
  echo -e "📡 Subnet: $PUB_SUBNET"
  echo -e "🌍 IGW: $IGW_ID"
  echo -e "🛣️ Route Table: $RT_ID"
  echo -e "🔒 Security Group: $SG_ID"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

main_menu


####--- NOTES ---####

# Prerequisites:
# - AWS CLI installed and configured
# - IAM permissions for VPC operations

# Required IAM Permissions:
# - ec2:CreateVpc, ec2:DeleteVpc
# - ec2:CreateSubnet, ec2:DeleteSubnet
# - ec2:CreateInternetGateway, ec2:AttachInternetGateway
# - ec2:CreateRouteTable, ec2:CreateRoute
# - ec2:CreateSecurityGroup, ec2:AuthorizeSecurityGroupIngress
# - ec2:DescribeVpcs, ec2:DescribeSubnets, ec2:DescribeSecurityGroups

# Common CIDR Blocks:
# - 10.0.0.0/16 (65,536 IPs)
# - 172.16.0.0/16 (65,536 IPs)
# - 192.168.0.0/16 (65,536 IPs)

# Subnet Planning:
# - Public subnets: 10.0.1.0/24, 10.0.2.0/24
# - Private subnets: 10.0.10.0/24, 10.0.11.0/24


####--- NOTES ---####

# Prerequisites:
# - AWS CLI installed and configured
# - IAM permissions for VPC operations

# Required IAM Permissions:
# - ec2:CreateVpc, ec2:DeleteVpc, ec2:DescribeVpcs
# - ec2:CreateSubnet, ec2:DeleteSubnet, ec2:DescribeSubnets
# - ec2:CreateInternetGateway, ec2:AttachInternetGateway, ec2:DetachInternetGateway
# - ec2:CreateRouteTable, ec2:CreateRoute, ec2:AssociateRouteTable
# - ec2:CreateSecurityGroup, ec2:AuthorizeSecurityGroupIngress, ec2:AuthorizeSecurityGroupEgress
# - ec2:RevokeSecurityGroupIngress, ec2:RevokeSecurityGroupEgress
# - ec2:CreateTags, ec2:ModifyVpcAttribute

# Common CIDR Blocks:
# - 10.0.0.0/16 (65,536 IPs)
# - 172.16.0.0/16 (65,536 IPs)
# - 192.168.0.0/16 (65,536 IPs)

# Subnet Planning:
# - Public subnets: 10.0.1.0/24, 10.0.2.0/24
# - Private subnets: 10.0.10.0/24, 10.0.11.0/24

# Network Modes:
# - awsvpc: Each task gets its own ENI (required for Fargate)
# - bridge: Tasks share host's network stack
# - host: Tasks use host's network directly

# Security Group Rules:
# - Inbound: Controls incoming traffic to resources
# - Outbound: Controls outgoing traffic from resources
# - Protocol: tcp, udp, icmp, or -1 (all)
# - Port range: Single port or range (e.g., 80 or 1024-65535)
