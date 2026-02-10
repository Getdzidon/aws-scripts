#!/bin/bash

#####--- See below for notes before running this script ---#####

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Default AWS region for S3 operations
REGION="eu-central-1"

main_menu() {
  clear
  echo -e "${CYAN}==============================${NC}"
  echo -e "${WHITE}🪣 S3 Bucket Management${NC}"
  echo -e "${CYAN}==============================${NC}"
  echo -e "${GREEN}1)${NC} List All S3 Buckets"
  echo -e "${GREEN}2)${NC} Create New S3 Bucket"
  echo -e "${GREEN}3)${NC} Delete S3 Bucket"
  echo -e "${GREEN}4)${NC} List Bucket Contents"
  echo -e "${GREEN}5)${NC} Upload File to Bucket"
  echo -e "${GREEN}6)${NC} Download File from Bucket"
  echo -e "${GREEN}7)${NC} Get Bucket Size/Info"
  echo -e "${GREEN}8)${NC} Empty Bucket"
  echo -e "${GREEN}9)${NC} Enable Static Website Hosting"
  echo -e "${GREEN}10)${NC} Enable/Disable Versioning"
  echo -e "${GREEN}11)${NC} Add Tags to Bucket"
  echo -e "${GREEN}12)${NC} Set Bucket Policy (Public Read)"
  echo -e "${GREEN}13)${NC} Exit"
  echo -e "${CYAN}==============================${NC}"

  read -p "Choose an option: " choice

  case $choice in
    1) list_buckets ;;
    2) create_bucket ;;
    3) delete_bucket ;;
    4) list_bucket_contents ;;
    5) upload_file ;;
    6) download_file ;;
    7) bucket_info ;;
    8) empty_bucket ;;
    9) enable_website_hosting ;;
    10) manage_versioning ;;
    11) add_tags ;;
    12) set_bucket_policy ;;
    13) echo -e "\n${YELLOW} 👋 Exiting...${NC}"; exit 0 ;;
    *) echo -e "\n${RED} ❌ Invalid selection${NC}"; sleep 1; main_menu ;;
  esac
}

list_buckets() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  # Query all buckets with name and creation date
  buckets=$(aws s3api list-buckets --query "Buckets[].[Name,CreationDate]" --output text)

  # Check if buckets variable is empty using -z flag
  if [ -z "$buckets" ]; then
    echo -e "\n ❌ No buckets found.\n"
  else
    echo -e "\n📦 Available S3 Buckets:\n"
    echo "$buckets" | awk '{printf "%-40s %s\n", $1, $2}'
    echo ""
  fi

  read -p "Press Enter to return to main menu..."
  main_menu
}

create_bucket() {
  echo -e "\n 🛠️ Creating new S3 bucket..."
  
  read -p "Enter bucket name: " BUCKET_NAME

  if [ -z "$BUCKET_NAME" ]; then
    echo -e "\n ❌ Bucket name cannot be empty."
    sleep 2
    main_menu
    return
  fi

  # ACL selection
  echo -e "\n 🔒 Select ACL (Access Control List):"
  PS3=$'\nChoose ACL: '
  select ACL_CHOICE in "private" "public-read" "public-read-write" "authenticated-read" "Cancel"; do
    if [ "$ACL_CHOICE" = "Cancel" ]; then
      main_menu
      return
    elif [ -n "$ACL_CHOICE" ]; then
      break
    fi
  done

  # Block Public Access selection
  echo -e "\n 🌐 Block all public access?"
  PS3=$'\nChoose option: '
  select PUBLIC_ACCESS in "Yes (Recommended - Block all public access)" "No (Allow public access)"; do
    case $PUBLIC_ACCESS in
      "Yes (Recommended - Block all public access)")
        BLOCK_PUBLIC="true"
        break
        ;;
      "No (Allow public access)")
        echo -e "\n ⚠️ WARNING: This will allow public access to the bucket."
        read -p "Are you sure? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
          BLOCK_PUBLIC="false"
          break
        else
          main_menu
          return
        fi
        ;;
    esac
  done

  echo -e "\n 🚀 Creating bucket '$BUCKET_NAME' in region $REGION..."
  
  # us-east-1 doesn't require LocationConstraint parameter
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --acl "$ACL_CHOICE"
  else
    # Other regions require LocationConstraint in bucket configuration
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" --acl "$ACL_CHOICE"
  fi

  # Check exit status of previous command ($? = 0 means success)
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ Bucket '$BUCKET_NAME' created successfully!"
    
    # Configure public access block settings
    if [ "$BLOCK_PUBLIC" = "false" ]; then
      echo -e "\n 🔓 Disabling public access block..."
      aws s3api delete-public-access-block --bucket "$BUCKET_NAME" 2>/dev/null
      echo -e "\n ✅ Public access block disabled!\n"
    else
      echo -e "\n 🔒 Public access block is enabled (default).\n"
    fi
  else
    echo -e "\n ❌ Failed to create bucket. Check name availability and permissions.\n"
  fi

  read -p "Press Enter to return to main menu..."
  main_menu
}

delete_bucket() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text)

  if [ -z "$buckets" ]; then
    echo -e "\n ❌ No buckets found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi

  # Convert space-separated string to array
  bucket_array=($buckets)
  
  echo -e "\n📦 Available S3 Buckets:\n"
  # PS3 sets the prompt for select menu
  PS3=$'\nSelect a bucket to delete: '
  
  # select creates numbered menu from array
  select BUCKET in "${bucket_array[@]}" "Cancel"; do
    if [ "$BUCKET" = "Cancel" ]; then
      echo -e "\n 🚫 Canceled.\n"
      main_menu
      return
    elif [ -n "$BUCKET" ]; then
      echo -e "\n ⚠️ You chose to DELETE bucket: $BUCKET"
      read -p "❗ This is permanent. Are you sure? (y/n): " confirm

      if [[ "$confirm" == "y" ]]; then
        echo -e "\n 🗑️ Deleting bucket '$BUCKET'..."
        # rb = remove bucket, --force deletes all objects inside first
        aws s3 rb s3://"$BUCKET" --force

        if [ $? -eq 0 ]; then
          echo -e "\n ✅ Bucket '$BUCKET' deleted successfully!\n"
        else
          echo -e "\n ❌ Failed to delete bucket.\n"
        fi
      else
        echo -e "\n 🚫 Delete action canceled.\n"
      fi
      
      read -p "Press Enter to return to main menu..."
      main_menu
      return
    else
      echo -e "\n ❌ Invalid selection."
    fi
  done
}

# Reusable function to select a bucket from list
select_bucket() {
  buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text)
  if [ -z "$buckets" ]; then
    echo -e "\n ❌ No buckets found.\n"
    return 1  # Return non-zero to indicate failure
  fi
  bucket_array=($buckets)
  PS3=$'\nSelect a bucket: '
  select BUCKET in "${bucket_array[@]}" "Cancel"; do
    if [ "$BUCKET" = "Cancel" ]; then
      return 1
    elif [ -n "$BUCKET" ]; then
      return 0  # Return 0 to indicate success, BUCKET variable is set
    fi
  done
}

list_bucket_contents() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  # || means "if select_bucket fails, execute the block"
  select_bucket || { main_menu; return; }
  
  echo -e "\n 📂 Contents of bucket '$BUCKET':\n"
  # --recursive lists all objects, --human-readable shows sizes in KB/MB, --summarize shows totals
  aws s3 ls s3://"$BUCKET" --recursive --human-readable --summarize
  echo ""
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

upload_file() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  select_bucket || { main_menu; return; }
  
  read -p "Enter local file path to upload: " FILE_PATH
  
  # -f checks if file exists and is a regular file
  if [ ! -f "$FILE_PATH" ]; then
    echo -e "\n ❌ File not found.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  echo -e "\n 📤 Uploading file to bucket '$BUCKET'..."
  aws s3 cp "$FILE_PATH" s3://"$BUCKET"/
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ File uploaded successfully!\n"
  else
    echo -e "\n ❌ Upload failed.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

download_file() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  select_bucket || { main_menu; return; }
  
  echo -e "\n 📂 Files in bucket '$BUCKET':\n"
  # awk extracts 4th column (filename) from s3 ls output
  files=$(aws s3 ls s3://"$BUCKET" --recursive | awk '{print $4}')
  
  if [ -z "$files" ]; then
    echo -e "\n ❌ No files in bucket.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  echo "$files"
  echo ""
  read -p "Enter file name to download: " FILE_NAME
  read -p "Enter local destination path (or . for current dir): " DEST_PATH
  
  echo -e "\n 📥 Downloading file..."
  aws s3 cp s3://"$BUCKET"/"$FILE_NAME" "$DEST_PATH"/
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ File downloaded successfully!\n"
  else
    echo -e "\n ❌ Download failed.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

bucket_info() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  select_bucket || { main_menu; return; }
  
  echo -e "\n 📊 Bucket Info for '$BUCKET':\n"
  echo "Calculating size and object count..."
  # tail -2 shows last 2 lines which contain total objects and total size
  aws s3 ls s3://"$BUCKET" --recursive --summarize | tail -2
  echo ""
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

empty_bucket() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  select_bucket || { main_menu; return; }
  
  echo -e "\n ⚠️ You chose to EMPTY bucket: $BUCKET"
  read -p "❗ This will delete all objects. Are you sure? (y/n): " confirm
  
  if [[ "$confirm" == "y" ]]; then
    echo -e "\n 🗑️ Emptying bucket '$BUCKET'..."
    # rm with --recursive deletes all objects but keeps the bucket
    aws s3 rm s3://"$BUCKET" --recursive
    
    if [ $? -eq 0 ]; then
      echo -e "\n ✅ Bucket emptied successfully!\n"
    else
      echo -e "\n ❌ Failed to empty bucket.\n"
    fi
  else
    echo -e "\n 🚫 Action canceled.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

enable_website_hosting() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  select_bucket || { main_menu; return; }
  
  read -p "Enter index document (default: index.html): " INDEX_DOC
  # ${VAR:-default} uses default value if VAR is empty or unset
  INDEX_DOC=${INDEX_DOC:-index.html}
  
  read -p "Enter error document (default: 404.html): " ERROR_DOC
  ERROR_DOC=${ERROR_DOC:-404.html}
  
  echo -e "\n 🌐 Enabling static website hosting..."
  # Configure bucket for static website hosting
  aws s3 website s3://"$BUCKET"/ --index-document "$INDEX_DOC" --error-document "$ERROR_DOC"
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ Website hosting enabled!\n"
    # Display the website endpoint URL
    echo "Website URL: http://$BUCKET.s3-website.$REGION.amazonaws.com"
    echo ""
  else
    echo -e "\n ❌ Failed to enable website hosting.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

manage_versioning() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  select_bucket || { main_menu; return; }
  
  echo -e "\n 🔒 Versioning Options:"
  PS3=$'\nChoose action: '
  select ACTION in "Enable" "Suspend" "Cancel"; do
    case $ACTION in
      "Enable")
        aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
        echo -e "\n ✅ Versioning enabled!\n"
        break
        ;;
      "Suspend")
        aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Suspended
        echo -e "\n ✅ Versioning suspended!\n"
        break
        ;;
      "Cancel")
        echo -e "\n 🚫 Canceled.\n"
        break
        ;;
    esac
  done
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

add_tags() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  select_bucket || { main_menu; return; }
  
  read -p "Enter tag key: " TAG_KEY
  read -p "Enter tag value: " TAG_VALUE
  
  # || means OR - checks if either variable is empty
  if [ -z "$TAG_KEY" ] || [ -z "$TAG_VALUE" ]; then
    echo -e "\n ❌ Tag key and value cannot be empty.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  echo -e "\n 🏷️ Adding tag to bucket..."
  aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging "TagSet=[{Key=$TAG_KEY,Value=$TAG_VALUE}]"
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ Tag added successfully!\n"
  else
    echo -e "\n ❌ Failed to add tag.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

set_bucket_policy() {
  echo -e "\n 🔍 Fetching S3 buckets..."
  select_bucket || { main_menu; return; }
  
  echo -e "\n ⚠️ This will make all objects in '$BUCKET' publicly readable."
  read -p "Are you sure? (y/n): " confirm
  
  if [[ "$confirm" == "y" ]]; then
    # JSON policy allowing public read access to all objects in bucket
    POLICY='{"Version":"2012-10-17","Statement":[{"Sid":"PublicReadGetObject","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::'$BUCKET'/*"}]}'
    
    echo -e "\n 🔐 Setting bucket policy..."
    aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$POLICY"
    # Remove public access block to allow policy to work (2>/dev/null suppresses errors)
    aws s3api delete-public-access-block --bucket "$BUCKET" 2>/dev/null
    
    if [ $? -eq 0 ]; then
      echo -e "\n ✅ Public read policy applied!\n"
    else
      echo -e "\n ❌ Failed to set policy.\n"
    fi
  else
    echo -e "\n 🚫 Action canceled.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

main_menu


####--- NOTES ---####

# Note: Make sure AWS CLI is configured and user has permissions
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

## Basic AWS CLI configuration
## If you have the AWS CLI installed, run:
#--- aws configure

## You'll be prompted for four things:
#--- AWS Access Key ID:
#--- AWS Secret Access Key:
#--- Default region name:
#--- Default output format:

## Typical answers look like:
#--- Access Key ID and Secret come from IAM
#--- Region something like: eu-central-1 or us-east-1
#--- Output format: usually json

## That writes credentials to:
#--- ~/.aws/credentials
#--- ~/.aws/config

## Using named profiles (recommended)
# For multiple accounts or roles:
#--- aws configure --profile dev

## Then use it like:
#--- aws s3 ls --profile dev

## Or set it once per shell:
#--- export AWS_PROFILE=dev

## SSO configuration
# If your org uses AWS SSO:
#--- aws configure sso

## You'll be guided through login and account selection. After that:
#--- aws s3 ls --profile my-sso-profile

## Quick sanity check
#--- aws sts get-caller-identity

## If that returns an ARN and account ID, you're good.

## Note: Your IAM account must have appropriate permissions for s3:CreateBucket, s3:DeleteBucket, s3:ListBucket, etc.

## S3 Bucket Naming Rules:
#--- Must be 3-63 characters long
#--- Can contain lowercase letters, numbers, hyphens
#--- Must start and end with a letter or number
#--- Must be globally unique across all AWS accounts
