#!/bin/bash


#####--- See below for notes before running this script ---#####


echo "🔍 Fetching EC2 instances..."

# Fetch instance info: Name, ID, State
instances=$(aws ec2 describe-instances \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name]" \
  --output text)

# Build array line-by-line and format
instance_array=()
while IFS=$'\t' read -r name id state; do
  formatted_line=$(printf "%-25s %-20s %-10s" "$name" "$id" "$state")
  instance_array+=("$formatted_line")
done <<< "$instances"

# Check if instance_array is empty
if [ ${#instance_array[@]} -eq 0 ]; then
  echo "❌ No instances found in your AWS account."
  exit 1
fi

echo ""
echo "🖥️  Available EC2 Instances:"
PS3="Enter the number corresponding to an EC2 instance to proceed (or Ctrl+C to cancel): "

select choice in "${instance_array[@]}"; do
  if [ -n "$choice" ]; then
    INSTANCE_ID=$(echo "$choice" | awk '{print $2}')
    INSTANCE_NAME=$(echo "$choice" | awk '{print $1}')
    INSTANCE_STATE=$(echo "$choice" | awk '{print $3}')
    
    echo ""
    echo "✅ You selected:"
    echo " - Name:  $INSTANCE_NAME"
    echo " - ID:    $INSTANCE_ID"
    echo " - State: $INSTANCE_STATE"
    echo ""

    # Choose an action
    echo "What do you want to do with this instance?"
    PS3="Enter a number corresponding to the action (or Ctrl+C to cancel): "
    select ACTION in "Start" "Stop" "Reboot" "Hibernate" "Terminate_&_Delete" "Cancel"; do
      case $ACTION in
        
        "Start")
          echo ""
          echo "⚠️ You chose to START $INSTANCE_ID"
          read -p "Are you sure? (y/n): " confirm
          echo ""

          if [[ "$confirm" == "y" ]]; then
            echo ""
            aws ec2 start-instances --instance-ids "$INSTANCE_ID" --output table
            echo "⏳ Waiting for instance to enter 'running' state..."
            aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
            echo "✅ Instance $INSTANCE_ID is now running."
          else
            echo ""
            echo "🚫 Start action canceled."
          fi
          break
          ;;

        "Stop")
          echo ""
          echo "⚠️ You chose to STOP $INSTANCE_ID"
          read -p "Are you sure? (y/n): " confirm
          echo ""

          if [[ "$confirm" == "y" ]]; then
            echo ""
            aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --output table
            echo "⏳ Waiting for instance to stop..."
            aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
            echo "✅ Instance $INSTANCE_ID is now stopped."
          else
            echo ""
            echo "🚫 Stop action canceled."
          fi
          break
          ;;

        "Reboot")
          echo ""
          echo "⚠️ You chose to REBOOT $INSTANCE_ID"
          read -p "Are you sure? (y/n): " confirm
          echo ""

          if [[ "$confirm" == "y" ]]; then
            echo ""
            aws ec2 reboot-instances --instance-ids "$INSTANCE_ID" --output table
            echo "✅ Instance $INSTANCE_ID is now rebooting."
          else
            echo ""
            echo "🚫 Reboot action canceled."
          fi
          break
          ;;

        "Hibernate")
          echo ""
          echo "⚠️ You chose to HIBERNATE $INSTANCE_ID"
          read -p "Are you sure? (y/n): " confirm
          echo ""

          if [[ "$confirm" == "y" ]]; then
            echo ""
            aws ec2 start-instances --instance-ids "$INSTANCE_ID" --output table
            aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --hibernate --output table
            echo "⏳ Waiting for instance to enter 'stopped' state..."
            aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
            echo "✅ Instance $INSTANCE_ID is now hibernated."
          else
            echo ""
            echo "🚫 Hibernate action canceled."
          fi
          break
          ;;

        "Terminate_&_Delete")
          echo ""
          echo "⚠️ You chose to TERMINATE $INSTANCE_ID"
          read -p "❗ This is permanent. Are you sure? (y/n): " confirm
          if [[ "$confirm" == "y" ]]; then
            echo ""
            aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --output table
            echo "⏳ Waiting for instance to terminate..."
            aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
            echo "✅ Instance $INSTANCE_ID has been terminated."
          else
            echo ""
            echo "🚫 Terminate and Delete action canceled."
          fi
          break
          ;;

        "Cancel")
          echo ""
          echo "🚫 Action canceled."
          break
          ;;

        *)
          echo ""
          echo "❌ Invalid option. Choose Start, Stop, Reboot, Hibernate, Terminate, or Cancel."
          ;;

      esac
    done

    break
  else
    echo ""
    echo "❌ Invalid selection. Try again."
  fi
done



####--- NOTES ---####

# Note: Make sure AWS CLI is configured and user has permissions
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

## Basic AWS CLI configuration
## If you have the AWS CLI installed, run:
#--- aws configure

## You’ll be prompted for four things:
#--- AWS Access Key ID:
#--- AWS Secret Access Key:
#--- Default region name:
#--- Default output format:

## Typical answers look like:
#--- Access Key ID and Secret come from IAM
#--- Region something like: eu-west-1 or us-east-1
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

## You’ll be guided through login and account selection. After that:
#---aws s3 ls --profile my-sso-profile

## Quick sanity check
#--- aws sts get-caller-identity

## If that returns an ARN and account ID, you’re good.

## Note: Your IAM account used for Access Key and ID mush have appropriate permissions for ec2:StartInstances, ec2:TerminateInstances, etc.
