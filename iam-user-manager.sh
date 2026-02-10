#!/bin/bash

#####--- IAM User Management Script ---#####
#####---Important comments at the bottom of the script---#####

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

main_menu() {
  clear
  echo -e "${CYAN}======================================${NC}"
  echo -e "${WHITE}👤 IAM User Management${NC}"
  echo -e "${CYAN}======================================${NC}"
  echo -e "${GREEN}1)${NC} Create IAM User"
  echo -e "${GREEN}2)${NC} List IAM Users"
  echo -e "${GREEN}3)${NC} Attach Policy to User"
  echo -e "${GREEN}4)${NC} Create Access Key for User"
  echo -e "${GREEN}5)${NC} Show Access Keys for User"
  echo -e "${GREEN}6)${NC} Delete IAM User"
  echo -e "${GREEN}7)${NC} Exit"
  echo -e "${CYAN}======================================${NC}"

  read -p "Choose an option: " choice

  case $choice in
    1) create_user ;;
    2) list_users ;;
    3) attach_policy ;;
    4) create_access_key ;;
    5) show_access_keys ;;
    6) delete_user ;;
    7) echo -e "\n${YELLOW} 👋 Exiting...${NC}"; exit 0 ;;
    *) echo -e "\n${RED} ❌ Invalid selection${NC}"; sleep 1; main_menu ;;
  esac
}

# Create IAM User
create_user() {
  echo -e "\n${BLUE} 👤 Creating IAM User...${NC}"
  
  read -p "Enter username: " USERNAME
  
  # Check if username is empty using -z flag
  if [ -z "$USERNAME" ]; then
    echo -e "\n${RED} ❌ Username cannot be empty.${NC}"
    sleep 2
    main_menu
    return
  fi
  
  echo -e "\n${CYAN} 🚀 Creating user '${WHITE}$USERNAME${CYAN}'...${NC}"
  aws iam create-user --user-name "$USERNAME"
  
  # Check exit status ($? = 0 means success)
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN} ✅ User '${WHITE}$USERNAME${GREEN}' created successfully!${NC}"
    
    # Ask if user wants to attach policies
    echo -e "\n${YELLOW} 🔒 Attach policies now?${NC}"
    PS3=$'\nChoose: '
    select ATTACH in "Yes" "No"; do
      if [ "$ATTACH" = "Yes" ]; then
        attach_policy_to_user "$USERNAME"
      fi
      break
    done
    
    # Ask if user wants to create access key
    echo -e "\n${YELLOW} 🔑 Create access key now?${NC}"
    PS3=$'\nChoose: '
    select CREATE_KEY in "Yes" "No"; do
      if [ "$CREATE_KEY" = "Yes" ]; then
        create_access_key_for_user "$USERNAME"
      fi
      break
    done
  else
    echo -e "\n${RED} ❌ Failed to create user.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# List IAM Users
list_users() {
  echo -e "\n${CYAN} 🔍 Fetching IAM users...${NC}\n"
  
  # Query users with username, creation date, and ARN
  users=$(aws iam list-users --query 'Users[].[UserName,CreateDate,Arn]' --output text)
  
  if [ -z "$users" ]; then
    echo -e "\n${RED} ❌ No users found.${NC}\n"
  else
    echo -e "${GREEN}👥 IAM Users:${NC}\n"
    # Use awk to format output with colors
    echo "$users" | awk -v cyan="$CYAN" -v white="$WHITE" -v nc="$NC" '{printf cyan"%-30s"nc" "white"%-25s %s"nc"\n", $1, $2, $3}'
    echo ""
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Select user from list (reusable helper function)
select_user() {
  users=$(aws iam list-users --query 'Users[].UserName' --output text)
  
  if [ -z "$users" ]; then
    echo -e "\n${RED} ❌ No users found.${NC}\n"
    return 1  # Return non-zero to indicate failure
  fi
  
  # Convert space-separated string to array
  user_array=($users)
  PS3=$'\nSelect a user: '
  # select creates numbered menu from array
  select USERNAME in "${user_array[@]}" "Cancel"; do
    if [ "$USERNAME" = "Cancel" ]; then
      return 1
    elif [ -n "$USERNAME" ]; then
      return 0  # Return 0 to indicate success, USERNAME variable is set
    fi
  done
}

# Attach policy to user (internal function)
attach_policy_to_user() {
  local USER=$1
  
  echo -e "\n${YELLOW} 🔒 Select policy to attach:${NC}"
  PS3=$'\nChoose policy: '
  select POLICY in \
    "AdministratorAccess" \
    "PowerUserAccess" \
    "ReadOnlyAccess" \
    "AmazonEC2FullAccess" \
    "AmazonS3FullAccess" \
    "AmazonEC2ContainerRegistryPowerUser" \
    "AmazonECS_FullAccess" \
    "IAMFullAccess" \
    "Custom ARN" \
    "Skip"; do
    
    case $POLICY in
      "Skip")
        return
        ;;
      "Custom ARN")
        read -p "Enter policy ARN: " POLICY_ARN
        ;;
      *)
        # Build full ARN for AWS managed policy
        POLICY_ARN="arn:aws:iam::aws:policy/$POLICY"
        ;;
    esac
    
    if [ -n "$POLICY_ARN" ]; then
      echo -e "\n${CYAN} 📎 Attaching policy to user '${WHITE}$USER${CYAN}'...${NC}"
      aws iam attach-user-policy --user-name "$USER" --policy-arn "$POLICY_ARN"
      
      if [ $? -eq 0 ]; then
        echo -e "\n${GREEN} ✅ Policy attached successfully!${NC}"
      else
        echo -e "\n${RED} ❌ Failed to attach policy.${NC}"
      fi
    fi
    break
  done
}

# Attach Policy (menu option)
attach_policy() {
  echo -e "\n${CYAN} 🔍 Fetching IAM users...${NC}"
  # || means "if select_user fails, execute the block"
  select_user || { main_menu; return; }
  
  attach_policy_to_user "$USERNAME"
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Create access key for user (internal function)
create_access_key_for_user() {
  local USER=$1
  
  echo -e "\n${CYAN} 🔑 Creating access key for user '${WHITE}$USER${CYAN}'...${NC}"
  OUTPUT=$(aws iam create-access-key --user-name "$USER" --output json)
  
  if [ $? -eq 0 ]; then
    # Extract AccessKeyId from JSON output using grep and cut
    ACCESS_KEY=$(echo "$OUTPUT" | grep -o '"AccessKeyId": "[^"]*' | cut -d'"' -f4)
    # Extract SecretAccessKey from JSON output
    SECRET_KEY=$(echo "$OUTPUT" | grep -o '"SecretAccessKey": "[^"]*' | cut -d'"' -f4)
    
    echo -e "\n${GREEN} ✅ Access key created successfully!${NC}\n"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}⚠️  SAVE THESE CREDENTIALS - THEY WON'T BE SHOWN AGAIN${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Access Key ID:${NC}     ${WHITE}$ACCESS_KEY${NC}"
    echo -e "${CYAN}Secret Access Key:${NC} ${WHITE}$SECRET_KEY${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
  else
    echo -e "\n${RED} ❌ Failed to create access key.${NC}"
  fi
}

# Create Access Key (menu option)
create_access_key() {
  echo -e "\n${CYAN} 🔍 Fetching IAM users...${NC}"
  select_user || { main_menu; return; }
  
  create_access_key_for_user "$USERNAME"
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Show Access Keys
show_access_keys() {
  echo -e "\n${CYAN} 🔍 Fetching IAM users...${NC}"
  select_user || { main_menu; return; }
  
  echo -e "\n${GREEN} 🔑 Access keys for user '${WHITE}$USERNAME${GREEN}':${NC}\n"
  
  # List all access keys for the user with ID, status, and creation date
  keys=$(aws iam list-access-keys --user-name "$USERNAME" --query 'AccessKeyMetadata[].[AccessKeyId,Status,CreateDate]' --output text)
  
  if [ -z "$keys" ]; then
    echo -e "${RED} ❌ No access keys found for this user.${NC}\n"
  else
    # Format output with colors using awk
    echo "$keys" | awk -v cyan="$CYAN" -v green="$GREEN" -v white="$WHITE" -v nc="$NC" '{printf cyan"%-25s "nc green"%-10s "nc white"%s"nc"\n", $1, $2, $3}'
    echo ""
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Delete IAM User
delete_user() {
  echo -e "\n${CYAN} 🔍 Fetching IAM users...${NC}"
  select_user || { main_menu; return; }
  
  echo -e "\n${YELLOW} ⚠️  You chose to DELETE user: ${WHITE}$USERNAME${NC}"
  read -p "❗ This is permanent. Are you sure? (y/n): " confirm
  
  if [[ "$confirm" == "y" ]]; then
    echo -e "\n${RED} 🗑️  Deleting user '${WHITE}$USERNAME${RED}'...${NC}"
    
    # Delete access keys first (required before deleting user)
    echo -e "${YELLOW}Removing access keys...${NC}"
    ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USERNAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
    for KEY in $ACCESS_KEYS; do
      aws iam delete-access-key --user-name "$USERNAME" --access-key-id "$KEY"
    done
    
    # Detach managed policies (required before deleting user)
    echo -e "${YELLOW}Detaching policies...${NC}"
    POLICIES=$(aws iam list-attached-user-policies --user-name "$USERNAME" --query 'AttachedPolicies[].PolicyArn' --output text)
    for POLICY in $POLICIES; do
      aws iam detach-user-policy --user-name "$USERNAME" --policy-arn "$POLICY"
    done
    
    # Delete inline policies (required before deleting user)
    INLINE_POLICIES=$(aws iam list-user-policies --user-name "$USERNAME" --query 'PolicyNames[]' --output text)
    for POLICY in $INLINE_POLICIES; do
      aws iam delete-user-policy --user-name "$USERNAME" --policy-name "$POLICY"
    done
    
    # Delete user after cleanup
    aws iam delete-user --user-name "$USERNAME"
    
    if [ $? -eq 0 ]; then
      echo -e "\n${GREEN} ✅ User '${WHITE}$USERNAME${GREEN}' deleted successfully!${NC}\n"
    else
      echo -e "\n${RED} ❌ Failed to delete user.${NC}\n"
    fi
  else
    echo -e "\n${YELLOW} 🚫 Delete action canceled.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

main_menu


####--- NOTES ---####

# Prerequisites:
# - AWS CLI installed and configured
# - IAM permissions to create/manage users

# Required IAM Permissions:
# - iam:CreateUser
# - iam:ListUsers
# - iam:AttachUserPolicy
# - iam:CreateAccessKey
# - iam:DeleteUser
# - iam:DeleteAccessKey
# - iam:DetachUserPolicy
# - iam:ListAccessKeys
# - iam:ListAttachedUserPolicies

# Common AWS Managed Policies:
# - AdministratorAccess - Full access to all AWS services
# - PowerUserAccess - Full access except IAM/Organizations
# - ReadOnlyAccess - Read-only access to all services
# - AmazonEC2FullAccess - Full EC2 access
# - AmazonS3FullAccess - Full S3 access
# - AmazonEC2ContainerRegistryPowerUser - ECR access
# - AmazonECS_FullAccess - Full ECS access

# Security Best Practices:
# - Use least privilege principle
# - Enable MFA for users with console access
# - Rotate access keys regularly
# - Use IAM roles instead of access keys when possible
