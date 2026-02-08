#!/bin/bash

#####--- IAM User Management Script ---#####

main_menu() {
  clear
  echo "======================================"
  echo "👤 IAM User Management"
  echo "======================================"
  echo "1) Create IAM User"
  echo "2) List IAM Users"
  echo "3) Attach Policy to User"
  echo "4) Create Access Key for User"
  echo "5) Delete IAM User"
  echo "6) Exit"
  echo "======================================"

  read -p "Choose an option: " choice

  case $choice in
    1) create_user ;;
    2) list_users ;;
    3) attach_policy ;;
    4) create_access_key ;;
    5) delete_user ;;
    6) echo -e "\n 👋 Exiting..."; exit 0 ;;
    *) echo -e "\n ❌ Invalid selection"; sleep 1; main_menu ;;
  esac
}

# Create IAM User
create_user() {
  echo -e "\n 👤 Creating IAM User..."
  
  read -p "Enter username: " USERNAME
  
  if [ -z "$USERNAME" ]; then
    echo -e "\n ❌ Username cannot be empty."
    sleep 2
    main_menu
    return
  fi
  
  echo -e "\n 🚀 Creating user '$USERNAME'..."
  aws iam create-user --user-name "$USERNAME"
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ User '$USERNAME' created successfully!"
    
    # Ask if user wants to attach policies
    echo -e "\n 🔒 Attach policies now?"
    PS3=$'\nChoose: '
    select ATTACH in "Yes" "No"; do
      if [ "$ATTACH" = "Yes" ]; then
        attach_policy_to_user "$USERNAME"
      fi
      break
    done
    
    # Ask if user wants to create access key
    echo -e "\n 🔑 Create access key now?"
    PS3=$'\nChoose: '
    select CREATE_KEY in "Yes" "No"; do
      if [ "$CREATE_KEY" = "Yes" ]; then
        create_access_key_for_user "$USERNAME"
      fi
      break
    done
  else
    echo -e "\n ❌ Failed to create user.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# List IAM Users
list_users() {
  echo -e "\n 🔍 Fetching IAM users...\n"
  
  users=$(aws iam list-users --query 'Users[].[UserName,CreateDate,Arn]' --output text)
  
  if [ -z "$users" ]; then
    echo -e "\n ❌ No users found.\n"
  else
    echo -e "👥 IAM Users:\n"
    echo "$users" | awk '{printf "%-30s %-25s %s\n", $1, $2, $3}'
    echo ""
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Select user from list
select_user() {
  users=$(aws iam list-users --query 'Users[].UserName' --output text)
  
  if [ -z "$users" ]; then
    echo -e "\n ❌ No users found.\n"
    return 1
  fi
  
  user_array=($users)
  PS3=$'\nSelect a user: '
  select USERNAME in "${user_array[@]}" "Cancel"; do
    if [ "$USERNAME" = "Cancel" ]; then
      return 1
    elif [ -n "$USERNAME" ]; then
      return 0
    fi
  done
}

# Attach policy to user (internal function)
attach_policy_to_user() {
  local USER=$1
  
  echo -e "\n 🔒 Select policy to attach:"
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
        POLICY_ARN="arn:aws:iam::aws:policy/$POLICY"
        ;;
    esac
    
    if [ -n "$POLICY_ARN" ]; then
      echo -e "\n 📎 Attaching policy to user '$USER'..."
      aws iam attach-user-policy --user-name "$USER" --policy-arn "$POLICY_ARN"
      
      if [ $? -eq 0 ]; then
        echo -e "\n ✅ Policy attached successfully!"
      else
        echo -e "\n ❌ Failed to attach policy."
      fi
    fi
    break
  done
}

# Attach Policy (menu option)
attach_policy() {
  echo -e "\n 🔍 Fetching IAM users..."
  select_user || { main_menu; return; }
  
  attach_policy_to_user "$USERNAME"
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Create access key for user (internal function)
create_access_key_for_user() {
  local USER=$1
  
  echo -e "\n 🔑 Creating access key for user '$USER'..."
  OUTPUT=$(aws iam create-access-key --user-name "$USER" --output json)
  
  if [ $? -eq 0 ]; then
    ACCESS_KEY=$(echo "$OUTPUT" | grep -o '"AccessKeyId": "[^"]*' | cut -d'"' -f4)
    SECRET_KEY=$(echo "$OUTPUT" | grep -o '"SecretAccessKey": "[^"]*' | cut -d'"' -f4)
    
    echo -e "\n ✅ Access key created successfully!\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  SAVE THESE CREDENTIALS - THEY WON'T BE SHOWN AGAIN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Access Key ID:     $ACCESS_KEY"
    echo "Secret Access Key: $SECRET_KEY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  else
    echo -e "\n ❌ Failed to create access key."
  fi
}

# Create Access Key (menu option)
create_access_key() {
  echo -e "\n 🔍 Fetching IAM users..."
  select_user || { main_menu; return; }
  
  create_access_key_for_user "$USERNAME"
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Delete IAM User
delete_user() {
  echo -e "\n 🔍 Fetching IAM users..."
  select_user || { main_menu; return; }
  
  echo -e "\n ⚠️  You chose to DELETE user: $USERNAME"
  read -p "❗ This is permanent. Are you sure? (y/n): " confirm
  
  if [[ "$confirm" == "y" ]]; then
    echo -e "\n 🗑️  Deleting user '$USERNAME'..."
    
    # Delete access keys first
    echo "Removing access keys..."
    ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USERNAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
    for KEY in $ACCESS_KEYS; do
      aws iam delete-access-key --user-name "$USERNAME" --access-key-id "$KEY"
    done
    
    # Detach managed policies
    echo "Detaching policies..."
    POLICIES=$(aws iam list-attached-user-policies --user-name "$USERNAME" --query 'AttachedPolicies[].PolicyArn' --output text)
    for POLICY in $POLICIES; do
      aws iam detach-user-policy --user-name "$USERNAME" --policy-arn "$POLICY"
    done
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-user-policies --user-name "$USERNAME" --query 'PolicyNames[]' --output text)
    for POLICY in $INLINE_POLICIES; do
      aws iam delete-user-policy --user-name "$USERNAME" --policy-name "$POLICY"
    done
    
    # Delete user
    aws iam delete-user --user-name "$USERNAME"
    
    if [ $? -eq 0 ]; then
      echo -e "\n ✅ User '$USERNAME' deleted successfully!\n"
    else
      echo -e "\n ❌ Failed to delete user.\n"
    fi
  else
    echo -e "\n 🚫 Delete action canceled.\n"
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
