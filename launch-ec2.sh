#!/bin/bash

# Ensure AWS CLI is configured and user has necessary permissions for EC2 operations

echo "🔍 Fetching available EC2 Key Pairs..."
# List available key pairs
keypairs=$(aws ec2 describe-key-pairs --query "KeyPairs[].KeyName" --region eu-central-1 --output text)

if [ -z "$keypairs" ]; then
  echo "❌ No key pairs found in your AWS account."
  exit 1
fi

# Prompt the user to select a keypair from the available list
echo ""
echo "🔑 Available Key Pairs:"
select keypair in $keypairs; do
  if [ -n "$keypair" ]; then
    echo "✅ You selected Key Pair: $keypair"
    break
  else
    echo "❌ Invalid selection. Please select a valid key pair."
  fi
done

# Prompt for the instance type
echo ""
echo "💻 Select the EC2 instance type:"
instance_types=("t2.micro" "t2.small" "t2.medium" "t3.micro" "t3.small" "t3.medium")
select instance_type in "${instance_types[@]}"; do
  if [ -n "$instance_type" ]; then
    echo "✅ You selected Instance Type: $instance_type"
    break
  else
    echo "❌ Invalid selection. Please select a valid instance type."
  fi
done

# Fetch existing security groups
echo ""
echo "🔒 Fetching existing security groups..."
security_groups=$(aws ec2 describe-security-groups --query "SecurityGroups[].GroupName" --region eu-central-1 --output text)

if [ -z "$security_groups" ]; then
  echo "❌ No security groups found in your AWS account."
  exit 1
fi

# Prompt the user to select a security group
echo ""
echo "🔐 Available Security Groups:"
select security_group in $security_groups; do
  if [ -n "$security_group" ]; then
    echo "✅ You selected Security Group: $security_group"
    break
  else
    echo "❌ Invalid selection. Please select a valid security group."
  fi
done

# Set the correct AMI ID for Ubuntu 20.04
ami_id="ami-03250b0e01c28d196"

# Debugging output
echo "Debug: Using AMI ID: $ami_id"

if [ -z "$ami_id" ]; then
  echo "❌ No AMI ID found."
  exit 1
fi

echo "✅ Using AMI ID: $ami_id"

# Launch the EC2 instance (this part will only run once)
echo ""
echo "🚀 Launching the EC2 instance with the following details:"
echo "🔑 Key Pair:    $keypair"
echo "Instance Type:  $instance_type"
echo "Security Group: $security_group"
echo "AMI ID:         $ami_id"

# Run the EC2 instance and ensure it's only triggered once
instance_id=$(aws ec2 run-instances \
  --image-id "$ami_id" \
  --instance-type "$instance_type" \
  --key-name "$keypair" \
  --security-groups "$security_group" \
  --region eu-central-1 \
  --query "Instances[0].InstanceId" \
  --output text)

if [ "$instance_id" == "None" ]; then
  echo "❌ Failed to launch the EC2 instance."
  exit 1
fi

echo "✅ EC2 instance launched successfully! Instance ID: $instance_id"

# Add a name tag to the instance
echo "🏷️ Tagging the instance with the name 'GH-Actions-Demo'..."
aws ec2 create-tags --resources "$instance_id" --tags Key=Name,Value=GH-Actions-Demo --region eu-central-1

echo "✅ Instance tagged with Name=GH-Actions-Demo"

# Wait for the instance to be running
echo "⏳ Waiting for instance to be in 'running' state..."
aws ec2 wait instance-running --instance-ids "$instance_id" --region eu-central-1

# Fetch the public IP address of the instance
public_ip=$(aws ec2 describe-instances \
  --instance-ids "$instance_id" \
  --region eu-central-1 \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "✅ Instance is now running! Public IP: $public_ip"

# SSH access (just showing the command for you to SSH into the instance)
echo ""
echo "Use the following command to SSH into your instance:"
echo "ssh -i /c/Users/getdz/Downloads/$keypair.pem ubuntu@$public_ip"
