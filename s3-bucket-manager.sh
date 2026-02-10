#!/bin/bash

#####--- s3 Bucket Management Script ---#####
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
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  # Query all buckets with name and creation date
  buckets=$(aws s3api list-buckets --query "Buckets[].[Name,CreationDate]" --output text)

  # Check if buckets variable is empty using -z flag
  if [ -z "$buckets" ]; then
    echo -e "\n${RED} ❌ No buckets found.${NC}\n"
  else
    echo -e "\n${GREEN}📦 Available S3 Buckets:${NC}\n"
    # Use awk to format output with colors
    echo "$buckets" | awk -v cyan="$CYAN" -v white="$WHITE" -v nc="$NC" '{printf cyan"%-40s "nc white"%s"nc"\n", $1, $2}'
    echo ""
  fi

  read -p "Press Enter to return to main menu..."
  main_menu
}

create_bucket() {
  echo -e "\n${BLUE} 🛠️ Creating new S3 bucket...${NC}"
  
  read -p "Enter bucket name: " BUCKET_NAME

  if [ -z "$BUCKET_NAME" ]; then
    echo -e "\n${RED} ❌ Bucket name cannot be empty.${NC}"
    sleep 2
    main_menu
    return
  fi

  echo -e "\n${YELLOW} 🔒 Select ACL (Access Control List):${NC}"
  PS3=$'\nChoose ACL: '
  select ACL_CHOICE in "private" "public-read" "public-read-write" "authenticated-read" "Cancel"; do
    if [ "$ACL_CHOICE" = "Cancel" ]; then
      main_menu
      return
    elif [ -n "$ACL_CHOICE" ]; then
      break
    fi
  done

  echo -e "\n${YELLOW} 🌐 Block all public access?${NC}"
  PS3=$'\nChoose option: '
  select PUBLIC_ACCESS in "Yes (Recommended - Block all public access)" "No (Allow public access)"; do
    case $PUBLIC_ACCESS in
      "Yes (Recommended - Block all public access)")
        BLOCK_PUBLIC="true"
        break
        ;;
      "No (Allow public access)")
        echo -e "\n${RED} ⚠️ WARNING: This will allow public access to the bucket.${NC}"
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

  echo -e "\n${CYAN} 🚀 Creating bucket '${WHITE}$BUCKET_NAME${CYAN}' in region $REGION...${NC}"
  
  # us-east-1 doesn't require LocationConstraint parameter
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --acl "$ACL_CHOICE"
  else
    # Other regions require LocationConstraint in bucket configuration
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" --acl "$ACL_CHOICE"
  fi

  # Check exit status ($? = 0 means success)
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN} ✅ Bucket '${WHITE}$BUCKET_NAME${GREEN}' created successfully!${NC}"
    
    if [ "$BLOCK_PUBLIC" = "false" ]; then
      echo -e "\n${YELLOW} 🔓 Disabling public access block...${NC}"
      # 2>/dev/null suppresses error messages
      aws s3api delete-public-access-block --bucket "$BUCKET_NAME" 2>/dev/null
      echo -e "\n${GREEN} ✅ Public access block disabled!${NC}\n"
    else
      echo -e "\n${GREEN} 🔒 Public access block is enabled (default).${NC}\n"
    fi
  else
    echo -e "\n${RED} ❌ Failed to create bucket. Check name availability and permissions.${NC}\n"
  fi

  read -p "Press Enter to return to main menu..."
  main_menu
}

delete_bucket() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text)

  if [ -z "$buckets" ]; then
    echo -e "\n${RED} ❌ No buckets found.${NC}\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi

  # Convert space-separated string to array
  bucket_array=($buckets)
  
  echo -e "\n${GREEN}📦 Available S3 Buckets:${NC}\n"
  # PS3 sets the prompt for select menu
  PS3=$'\nSelect a bucket to delete: '
  
  # select creates numbered menu from array
  select BUCKET in "${bucket_array[@]}" "Cancel"; do
    if [ "$BUCKET" = "Cancel" ]; then
      echo -e "\n${YELLOW} 🚫 Canceled.${NC}\n"
      main_menu
      return
    elif [ -n "$BUCKET" ]; then
      echo -e "\n${YELLOW} ⚠️ You chose to DELETE bucket: ${WHITE}$BUCKET${NC}"
      read -p "❗ This is permanent. Are you sure? (y/n): " confirm

      if [[ "$confirm" == "y" ]]; then
        echo -e "\n${RED} 🗑️ Deleting bucket '${WHITE}$BUCKET${RED}'...${NC}"
        # rb = remove bucket, --force deletes all objects inside first
        aws s3 rb s3://"$BUCKET" --force

        if [ $? -eq 0 ]; then
          echo -e "\n${GREEN} ✅ Bucket '${WHITE}$BUCKET${GREEN}' deleted successfully!${NC}\n"
        else
          echo -e "\n${RED} ❌ Failed to delete bucket.${NC}\n"
        fi
      else
        echo -e "\n${YELLOW} 🚫 Delete action canceled.${NC}\n"
      fi
      
      read -p "Press Enter to return to main menu..."
      main_menu
      return
    else
      echo -e "\n${RED} ❌ Invalid selection.${NC}"
    fi
  done
}

# Reusable helper function to select a bucket from list
select_bucket() {
  buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text)
  if [ -z "$buckets" ]; then
    echo -e "\n${RED} ❌ No buckets found.${NC}\n"
    return 1  # Return non-zero to indicate failure
  fi
  # Convert space-separated string to array
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
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  # || means "if select_bucket fails, execute the block"
  select_bucket || { main_menu; return; }
  
  echo -e "\n${GREEN} 📂 Contents of bucket '${WHITE}$BUCKET${GREEN}':${NC}\n"
  # --recursive lists all objects, --human-readable shows sizes in KB/MB, --summarize shows totals
  aws s3 ls s3://"$BUCKET" --recursive --human-readable --summarize
  echo ""
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

upload_file() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  select_bucket || { main_menu; return; }
  
  read -p "Enter local file path to upload: " FILE_PATH
  
  # -f checks if file exists and is a regular file
  if [ ! -f "$FILE_PATH" ]; then
    echo -e "\n${RED} ❌ File not found.${NC}\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  echo -e "\n${CYAN} 📤 Uploading file to bucket '${WHITE}$BUCKET${CYAN}'...${NC}"
  aws s3 cp "$FILE_PATH" s3://"$BUCKET"/
  
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN} ✅ File uploaded successfully!${NC}\n"
  else
    echo -e "\n${RED} ❌ Upload failed.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

download_file() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  select_bucket || { main_menu; return; }
  
  echo -e "\n${GREEN} 📂 Files in bucket '${WHITE}$BUCKET${GREEN}':${NC}\n"
  # awk extracts 4th column (filename) from s3 ls output
  files=$(aws s3 ls s3://"$BUCKET" --recursive | awk '{print $4}')
  
  if [ -z "$files" ]; then
    echo -e "\n${RED} ❌ No files in bucket.${NC}\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  echo "$files"
  echo ""
  read -p "Enter file name to download: " FILE_NAME
  read -p "Enter local destination path (or . for current dir): " DEST_PATH
  
  echo -e "\n${CYAN} 📥 Downloading file...${NC}"
  aws s3 cp s3://"$BUCKET"/"$FILE_NAME" "$DEST_PATH"/
  
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN} ✅ File downloaded successfully!${NC}\n"
  else
    echo -e "\n${RED} ❌ Download failed.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

bucket_info() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  select_bucket || { main_menu; return; }
  
  echo -e "\n${GREEN} 📊 Bucket Info for '${WHITE}$BUCKET${GREEN}':${NC}\n"
  echo -e "${YELLOW}Calculating size and object count...${NC}"
  # tail -2 shows last 2 lines which contain total objects and total size
  aws s3 ls s3://"$BUCKET" --recursive --summarize | tail -2
  echo ""
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

empty_bucket() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  select_bucket || { main_menu; return; }
  
  echo -e "\n${YELLOW} ⚠️ You chose to EMPTY bucket: ${WHITE}$BUCKET${NC}"
  read -p "❗ This will delete all objects. Are you sure? (y/n): " confirm
  
  if [[ "$confirm" == "y" ]]; then
    echo -e "\n${RED} 🗑️ Emptying bucket '${WHITE}$BUCKET${RED}'...${NC}"
    # rm with --recursive deletes all objects but keeps the bucket
    aws s3 rm s3://"$BUCKET" --recursive
    
    if [ $? -eq 0 ]; then
      echo -e "\n${GREEN} ✅ Bucket emptied successfully!${NC}\n"
    else
      echo -e "\n${RED} ❌ Failed to empty bucket.${NC}\n"
    fi
  else
    echo -e "\n${YELLOW} 🚫 Action canceled.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

enable_website_hosting() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  select_bucket || { main_menu; return; }
  
  read -p "Enter index document (default: index.html): " INDEX_DOC
  # ${VAR:-default} uses default value if VAR is empty or unset
  INDEX_DOC=${INDEX_DOC:-index.html}
  
  read -p "Enter error document (default: 404.html): " ERROR_DOC
  ERROR_DOC=${ERROR_DOC:-404.html}
  
  echo -e "\n${CYAN} 🌐 Enabling static website hosting...${NC}"
  # Configure bucket for static website hosting
  aws s3 website s3://"$BUCKET"/ --index-document "$INDEX_DOC" --error-document "$ERROR_DOC"
  
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN} ✅ Website hosting enabled!${NC}\n"
    echo -e "${CYAN}Website URL:${NC} ${WHITE}http://$BUCKET.s3-website.$REGION.amazonaws.com${NC}"
    echo ""
  else
    echo -e "\n${RED} ❌ Failed to enable website hosting.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

manage_versioning() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  select_bucket || { main_menu; return; }
  
  echo -e "\n${YELLOW} 🔒 Versioning Options:${NC}"
  PS3=$'\nChoose action: '
  select ACTION in "Enable" "Suspend" "Cancel"; do
    case $ACTION in
      "Enable")
        aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
        echo -e "\n${GREEN} ✅ Versioning enabled!${NC}\n"
        break
        ;;
      "Suspend")
        aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Suspended
        echo -e "\n${GREEN} ✅ Versioning suspended!${NC}\n"
        break
        ;;
      "Cancel")
        echo -e "\n${YELLOW} 🚫 Canceled.${NC}\n"
        break
        ;;
    esac
  done
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

add_tags() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  select_bucket || { main_menu; return; }
  
  read -p "Enter tag key: " TAG_KEY
  read -p "Enter tag value: " TAG_VALUE
  
  # || means OR - checks if either variable is empty
  if [ -z "$TAG_KEY" ] || [ -z "$TAG_VALUE" ]; then
    echo -e "\n${RED} ❌ Tag key and value cannot be empty.${NC}\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  echo -e "\n${CYAN} 🏷️ Adding tag to bucket...${NC}"
  aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging "TagSet=[{Key=$TAG_KEY,Value=$TAG_VALUE}]"
  
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN} ✅ Tag added successfully!${NC}\n"
  else
    echo -e "\n${RED} ❌ Failed to add tag.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

set_bucket_policy() {
  echo -e "\n${CYAN} 🔍 Fetching S3 buckets...${NC}"
  select_bucket || { main_menu; return; }
  
  echo -e "\n${YELLOW} ⚠️ This will make all objects in '${WHITE}$BUCKET${YELLOW}' publicly readable.${NC}"
  read -p "Are you sure? (y/n): " confirm
  
  if [[ "$confirm" == "y" ]]; then
    # JSON policy allowing public read access to all objects in bucket
    POLICY='{"Version":"2012-10-17","Statement":[{"Sid":"PublicReadGetObject","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::'$BUCKET'/*"}]}'
    
    echo -e "\n${CYAN} 🔐 Setting bucket policy...${NC}"
    aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$POLICY"
    # Remove public access block to allow policy to work (2>/dev/null suppresses errors)
    aws s3api delete-public-access-block --bucket "$BUCKET" 2>/dev/null
    
    if [ $? -eq 0 ]; then
      echo -e "\n${GREEN} ✅ Public read policy applied!${NC}\n"
    else
      echo -e "\n${RED} ❌ Failed to set policy.${NC}\n"
    fi
  else
    echo -e "\n${YELLOW} 🚫 Action canceled.${NC}\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

main_menu


####--- NOTES ---####

# Prerequisites:
# - AWS CLI installed and configured
# - IAM permissions for S3 operations

# Required IAM Permissions:
# - s3:CreateBucket, s3:DeleteBucket
# - s3:ListBucket, s3:ListAllMyBuckets
# - s3:PutObject, s3:GetObject, s3:DeleteObject
# - s3:PutBucketPolicy, s3:PutBucketTagging
# - s3:PutBucketVersioning, s3:PutBucketWebsite
# - s3:PutPublicAccessBlock, s3:DeletePublicAccessBlock

# S3 Bucket Naming Rules:
# - Must be 3-63 characters long
# - Can contain lowercase letters, numbers, hyphens
# - Must start and end with a letter or number
# - Must be globally unique across all AWS accounts

# ACL Options:
# - private: Owner gets full control, no one else has access
# - public-read: Owner gets full control, everyone can read
# - public-read-write: Owner gets full control, everyone can read/write
# - authenticated-read: Owner gets full control, authenticated AWS users can read

# Public Access Block:
# - Recommended to keep enabled for security
# - Blocks all public access to bucket and objects
# - Can be disabled for public websites or CDN origins

# Bash Syntax Notes:
# - ${VAR:-default} uses default value if VAR is empty or unset
# - [ -z "$var" ] checks if variable is empty
# - [ -f "$file" ] checks if file exists and is a regular file
# - $? contains exit status of last command (0 = success)
# - || means "if previous command fails, execute next command"
# - 2>/dev/null suppresses error messages
