#!binbash

#####--- See below for notes before running this script ---#####


# ======================== CONFIGURABLE VARIABLES ========================
REGION=eu-central-1
AMI_ID=ami-03250b0e01c28d196  # Ubuntu 20.04 LTS
TAG_NAME=GH-Actions-Demo
KEY_PATH=cUsersgetdzDownloads  # Path where your Keypair (.pem) files are stored
# =======================================================================

# Ensure AWS CLI is configured and the user has necessary permissions for EC2 operations

echo 🔍 Fetching available EC2 Key Pairs...
keypairs=$(aws ec2 describe-key-pairs --query KeyPairs[].KeyName --region $REGION --output text)

if [ -z $keypairs ]; then
  echo 
  echo ❌ No key pairs found in your AWS account.
  exit 1
fi

# Prompt user to select a key pair
echo 
echo 🔑 Available Key Pairs
PS3=➡️  Select a Key Pair 🔑 
select keypair in $keypairs; do
  if [ -n $keypair ]; then
    echo 
    echo ✅ You selected Key Pair 🔑 $keypair
    break
  else
    echo 
    echo ❌ Invalid selection. Please select a valid key pair.
  fi
done

# Prompt for EC2 instance type
echo 
echo 💻 Available EC2 Instance Types
instance_types=(t2.micro t2.small t2.medium t3.micro t3.small t3.medium)
PS3=➡️  Select an Instance Type 💻 
select instance_type in ${instance_types[@]}; do
  if [ -n $instance_type ]; then
    echo 
    echo ✅ You selected Instance Type 💻 $instance_type
    break
  else
    echo 
    echo ❌ Invalid selection. Please select a valid instance type.
  fi
done

# Fetch existing security groups
echo 
echo 🔒 Fetching existing security groups...
security_groups=$(aws ec2 describe-security-groups --query SecurityGroups[].GroupName --region $REGION --output text)

if [ -z $security_groups ]; then
  echo 
  echo ❌ No security groups found in your AWS account.
  exit 1
fi

# Prompt user to select a security group
echo 
echo 🔐 Available Security Groups
PS3=➡️  Select a Security Group 🔐 
select security_group in $security_groups; do
  if [ -n $security_group ]; then
    echo 
    echo ✅ You selected Security Group 🔐 $security_group

    # Get group ID from name
    security_group_id=$(aws ec2 describe-security-groups 
      --filters Name=group-name,Values=$security_group 
      --region $REGION 
      --query SecurityGroups[0].GroupId 
      --output text)

    # Prompt for port and CIDR
    echo 
    read -p 🌐 Enter the port number you want to allow (e.g., 22, 80, 443)  custom_port
    read -p 🌍 Enter the CIDR block to allow (e.g., 0.0.0.00 or your IP32)  custom_cidr

    echo 🔐 Adding custom ingress rule...
    aws ec2 authorize-security-group-ingress 
      --group-id $security_group_id 
      --protocol tcp 
      --port $custom_port 
      --cidr $custom_cidr 
      --region $REGION 2devnull

    if [ $ -eq 0 ]; then
      echo ✅ Ingress rule added for port $custom_port from $custom_cidr
    else
      echo ℹ️ Ingress rule may already exist or failed to apply
    fi

    break
  else
    echo 
    echo ❌ Invalid selection. Please select a valid security group.
  fi
done

echo 
echo 🧠 Using AMI ID $AMI_ID

if [ -z $AMI_ID ]; then
  echo 
  echo ❌ No AMI ID specified.
  exit 1
fi

# Launch the EC2 instance
echo 
echo 🚀 Launching EC2 instance with the following settings
echo 🔑 Key Pair        $keypair
echo 💻 Instance Type   $instance_type
echo 🔐 Security Group  $security_group
echo 🖼️ AMI ID          $AMI_ID

instance_id=$(aws ec2 run-instances 
  --image-id $AMI_ID 
  --instance-type $instance_type 
  --key-name $keypair 
  --security-groups $security_group 
  --region $REGION 
  --query Instances[0].InstanceId 
  --output text)

if [ $instance_id == None ]; then
  echo 
  echo ❌ Failed to launch the EC2 instance.
  exit 1
fi

echo ✅ EC2 instance launched! Instance ID $instance_id

# Add a Name tag to the instance
echo 🏷️ Tagging instance as '$TAG_NAME'...
aws ec2 create-tags --resources $instance_id 
  --tags Key=Name,Value=$TAG_NAME 
  --region $REGION

echo ✅ Tag 🏷️ $TAG_NAME applied

# Wait for instance to reach running state
echo ⏳ Waiting for instance to enter 'running' state...
aws ec2 wait instance-running 
  --instance-ids $instance_id 
  --region $REGION

# Fetch the instance's public IP
public_ip=$(aws ec2 describe-instances 
  --instance-ids $instance_id 
  --region $REGION 
  --query Reservations[0].Instances[0].PublicIpAddress 
  --output text)

echo ✅ Instance is now running! 🌍 Public IP $public_ip

# Output SSH command
echo 
echo 🔐 Use the following command to SSH into your instance (if port 22 was allowed)
echo ssh -i $KEY_PATH$keypair.pem ubuntu@$public_ip


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
