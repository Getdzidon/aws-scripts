#!/bin/bash

# Note: Make sure AWS CLI is configured and user has permissions
# Note: Have appropriate permissions for ec2:StartInstances, ec2:TerminateInstances, etc.

echo "🔍 Fetching EC2 instances..."

# Fetch instance info: Name, ID, State
instances=$(aws ec2 describe-instances \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, State.Name]" \
  --output text)

# Exit early if no instances found
if [[ -z "$instances" ]]; then
  echo "❌ No EC2 instances found in your AWS account. Exiting"
  exit 1
fi

# Build array line-by-line and format
instance_array=()
while IFS=$'\t' read -r name id state; do
  # Only add if ID and state are not empty (Name might be null)
  if [[ -n "$id" && -n "$state" ]]; then
    # Fallback to "(no name)" if name is null
    name=${name:-"(no name)"}
    formatted_line=$(printf "%-25s %-20s %-10s" "$name" "$id" "$state")
    instance_array+=("$formatted_line")
  fi
done <<< "$instances"

# Check if any valid instances were found
if [ ${#instance_array[@]} -eq 0 ]; then
  echo "❌ No EC2 instances available to manage."
  exit 1
fi

echo ""
echo "🖥️  Available EC2 Instances:"
echo ""

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

    echo "What do you want to do with this instance?"
    PS3="Enter a number corresponding to the action (or Ctrl+C to cancel): "
    select ACTION in "Stop" "Terminate_&_Delete" "Cancel"; do
      case $ACTION in
        "Stop")
          echo ""
          echo "⚠️ You chose to STOP $INSTANCE_ID"
          echo ""
          read -p "Are you sure? (y/n): " confirm
          echo ""

          if [[ "$confirm" == "y" ]]; then
            aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --output table
            echo "⏳ Waiting for instance to stop..."
            aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
            echo "✅ Instance $INSTANCE_ID is now stopped."
          else
            echo "🚫 Stop action canceled."
          fi
          break
          ;;
        
        "Terminate_&_Delete")
          echo "⚠️ You chose to TERMINATE $INSTANCE_ID"
          read -p "❗ This is permanent. Are you sure? (y/n): " confirm
          if [[ "$confirm" == "y" ]]; then
            aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --output table
            echo "⏳ Waiting for instance to terminate..."
            aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
            echo "✅ Instance $INSTANCE_ID has been terminated."
          else
            echo "🚫 Terminate and Delete action canceled."
          fi
          break
          ;;
        
        "Cancel")
          echo "🚫 Action canceled."
          break
          ;;
        *)
          echo "❌ Invalid option. Choose Stop, Terminate, or Cancel."
          ;;
      esac
    done

    break
  else
    echo "❌ Invalid selection. Try again."
  fi
done
