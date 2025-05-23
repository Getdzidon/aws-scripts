#!/bin/bash

# Note: Make sure AWS CLI is configured and user has permissions
# Note: Have appropriate permissions for ec2:StartInstances, etc.

echo "🔍 Fetching EC2 instances..."

# Get all instances with their Name, Instance ID, and current state
instances=$(aws ec2 describe-instances \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name]" \
  --output text)

# Check if instances were found
if [[ -z "$instances" ]]; then
  echo "❌ No EC2 instances found in your AWS account. Exiting."
  exit 1
fi

# Display instances in a table format
printf "\n🖥️  Available EC2 Instances:\n\n"
printf "%-25s %-20s %-10s\n" "Name" "Instance ID" "State"
echo "$instances" | while IFS=$'\t' read -r name id state; do
  name=${name:-"(no name)"}
  printf "%-25s %-20s %-10s\n" "$name" "$id" "$state"
done

echo ""
read -p "Enter the Instance ID you want to START: " INSTANCE_ID

if [ -z "$INSTANCE_ID" ]; then
  echo "❌ No Instance ID entered. Exiting."
  exit 1
fi

echo "🚀 Starting EC2 instance: $INSTANCE_ID..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID" --output table

echo "⏳ Waiting for instance to enter 'running' state..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

echo "✅ Instance $INSTANCE_ID is now running."
