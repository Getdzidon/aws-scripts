#!/bin/bash

#####--- ECS Complete Setup Script ---#####

# Default region
DEFAULT_REGION="eu-central-1"

main_menu() {
  clear
  echo "======================================"
  echo "🐳 ECS Complete Setup Manager"
  echo "======================================"
  echo "1) Full ECS Setup (ECR + Cluster + Task + Service)"
  echo "2) Create ECR Repository Only"
  echo "3) Create ECS Cluster Only"
  echo "4) Create Task Definition Only"
  echo "5) Create ECS Service Only"
  echo "6) Exit"
  echo "======================================"

  read -p "Choose an option: " choice

  case $choice in
    1) full_setup ;;
    2) create_ecr ;;
    3) create_cluster ;;
    4) create_task_definition ;;
    5) create_service ;;
    6) echo -e "\n 👋 Exiting..."; exit 0 ;;
    *) echo -e "\n ❌ Invalid selection"; sleep 1; main_menu ;;
  esac
}

# Select AWS region
select_region() {
  echo -e "\n 🌍 Select AWS Region:"
  PS3=$'\nChoose region: '
  select REGION in "eu-central-1 (Frankfurt)" "us-east-1 (N. Virginia)" "us-west-2 (Oregon)" "ap-southeast-1 (Singapore)" "Custom"; do
    case $REGION in
      "eu-central-1 (Frankfurt)") REGION="eu-central-1"; break ;;
      "us-east-1 (N. Virginia)") REGION="us-east-1"; break ;;
      "us-west-2 (Oregon)") REGION="us-west-2"; break ;;
      "ap-southeast-1 (Singapore)") REGION="ap-southeast-1"; break ;;
      "Custom") read -p "Enter region code: " REGION; break ;;
    esac
  done
  echo -e "\n ✅ Selected region: $REGION"
}

# Create ECR Repository
create_ecr() {
  echo -e "\n 📦 Creating ECR Repository..."
  
  select_region
  
  read -p "Enter ECR repository name: " ECR_NAME
  
  if [ -z "$ECR_NAME" ]; then
    echo -e "\n ❌ Repository name cannot be empty."
    sleep 2
    main_menu
    return
  fi
  
  echo -e "\n 🔒 Select repository type:"
  PS3=$'\nChoose type: '
  select REPO_TYPE in "Private" "Public"; do
    case $REPO_TYPE in
      "Private")
        echo -e "\n 🚀 Creating private ECR repository..."
        aws ecr create-repository --repository-name "$ECR_NAME" --region "$REGION"
        
        if [ $? -eq 0 ]; then
          ECR_URI=$(aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$REGION" --query 'repositories[0].repositoryUri' --output text)
          echo -e "\n ✅ Private ECR repository created!"
          echo -e "📍 Repository URI: $ECR_URI\n"
        fi
        break
        ;;
      "Public")
        echo -e "\n 🚀 Creating public ECR repository..."
        aws ecr-public create-repository --repository-name "$ECR_NAME" --region us-east-1
        
        if [ $? -eq 0 ]; then
          echo -e "\n ✅ Public ECR repository created!\n"
        fi
        break
        ;;
    esac
  done
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Create ECS Cluster
create_cluster() {
  echo -e "\n 🏗️ Creating ECS Cluster..."
  
  select_region
  
  read -p "Enter ECS cluster name: " CLUSTER_NAME
  
  if [ -z "$CLUSTER_NAME" ]; then
    echo -e "\n ❌ Cluster name cannot be empty."
    sleep 2
    main_menu
    return
  fi
  
  echo -e "\n 🚀 Creating cluster '$CLUSTER_NAME'..."
  aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$REGION"
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ ECS Cluster '$CLUSTER_NAME' created successfully!\n"
  else
    echo -e "\n ❌ Failed to create cluster.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Create Task Definition
create_task_definition() {
  echo -e "\n 📋 Creating ECS Task Definition..."
  
  select_region
  
  read -p "Enter task definition family name: " TASK_FAMILY
  read -p "Enter container name: " CONTAINER_NAME
  read -p "Enter container image (e.g., ECR_URI:latest): " IMAGE
  
  echo -e "\n 💻 Select launch type:"
  PS3=$'\nChoose launch type: '
  select LAUNCH_TYPE in "FARGATE" "EC2"; do
    case $LAUNCH_TYPE in
      "FARGATE"|"EC2")
        break
        ;;
    esac
  done
  
  # Network mode
  if [ "$LAUNCH_TYPE" = "FARGATE" ]; then
    NETWORK_MODE="awsvpc"
  else
    echo -e "\n 🌐 Select network mode:"
    PS3=$'\nChoose: '
    select NETWORK_MODE in "bridge" "awsvpc" "host"; do
      break
    done
  fi
  
  # CPU and Memory selection
  if [ "$LAUNCH_TYPE" = "FARGATE" ]; then
    echo -e "\n 🧠 Select CPU (vCPU):"
    PS3=$'\nChoose CPU (your usual: 1024): '
    select CPU in "256 (0.25 vCPU)" "512 (0.5 vCPU)" "1024 (1 vCPU) [Your usual]" "2048 (2 vCPU)" "4096 (4 vCPU)"; do
      CPU=$(echo $CPU | awk '{print $1}')
      break
    done
    
    echo -e "\n 💾 Select Memory Hard Limit (MB):"
    PS3=$'\nChoose Memory (your usual: 3072): '
    select MEMORY_HARD in "512" "1024" "2048" "3072 [Your usual]" "4096" "8192"; do
      MEMORY_HARD=$(echo $MEMORY_HARD | awk '{print $1}')
      break
    done
    
    echo -e "\n 💾 Memory Soft Limit (MB) - optional:"
    read -p "Enter soft limit (your usual: 1024) or press Enter to skip: " MEMORY_SOFT
    
    MEMORY=$MEMORY_HARD
  else
    read -p "Enter CPU units (e.g., 256): " CPU
    read -p "Enter Memory hard limit (MB): " MEMORY_HARD
    read -p "Enter Memory soft limit (MB, optional): " MEMORY_SOFT
    MEMORY=$MEMORY_HARD
  fi
  
  read -p "Enter container port (default: 80): " CONTAINER_PORT
  CONTAINER_PORT=${CONTAINER_PORT:-80}
  
  # Get AWS Account ID
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  
  # Build container definition
  CONTAINER_DEF='{
    "name": "'$CONTAINER_NAME'",
    "image": "'$IMAGE'",
    "portMappings": [{"containerPort": '$CONTAINER_PORT', "protocol": "tcp"}],
    "essential": true,
    "memory": '$MEMORY_HARD
  
  if [ -n "$MEMORY_SOFT" ]; then
    CONTAINER_DEF=$CONTAINER_DEF',
    "memoryReservation": '$MEMORY_SOFT
  fi
  
  CONTAINER_DEF=$CONTAINER_DEF'
  }'
  
  # Create task definition JSON
  TASK_DEF_JSON='{
  "family": "'$TASK_FAMILY'",
  "networkMode": "'$NETWORK_MODE'",
  "requiresCompatibilities": ["'$LAUNCH_TYPE'"],
  "cpu": "'$CPU'",
  "memory": "'$MEMORY'",
  "taskRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/ecsTaskExecutionRole",
  "executionRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/ecsTaskExecutionRole",
  "containerDefinitions": ['$CONTAINER_DEF']
}'
  
  echo -e "\n 🚀 Registering task definition..."
  echo "$TASK_DEF_JSON" | aws ecs register-task-definition --region "$REGION" --cli-input-json file:///dev/stdin
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ Task definition '$TASK_FAMILY' registered successfully!\n"
  else
    echo -e "\n ❌ Failed to register task definition.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Create ECS Service
create_service() {
  echo -e "\n 🚀 Creating ECS Service..."
  
  select_region
  
  echo -e "\n 🔍 Fetching ECS clusters..."
  clusters=$(aws ecs list-clusters --region "$REGION" --query 'clusterArns[*]' --output text | xargs -n1 basename)
  
  if [ -z "$clusters" ]; then
    echo -e "\n ❌ No clusters found. Create a cluster first.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  cluster_array=($clusters)
  echo -e "\n 🏗️ Select ECS Cluster:"
  PS3=$'\nChoose cluster: '
  select CLUSTER_NAME in "${cluster_array[@]}"; do
    if [ -n "$CLUSTER_NAME" ]; then
      break
    fi
  done
  
  echo -e "\n 🔍 Fetching task definitions..."
  tasks=$(aws ecs list-task-definitions --region "$REGION" --query 'taskDefinitionArns[*]' --output text | xargs -n1 basename | cut -d: -f1 | sort -u)
  
  if [ -z "$tasks" ]; then
    echo -e "\n ❌ No task definitions found. Create a task definition first.\n"
    read -p "Press Enter to return to main menu..."
    main_menu
    return
  fi
  
  task_array=($tasks)
  echo -e "\n 📋 Select Task Definition Family:"
  PS3=$'\nChoose task: '
  select TASK_FAMILY in "${task_array[@]}"; do
    if [ -n "$TASK_FAMILY" ]; then
      break
    fi
  done
  
  echo -e "\n 🔢 Specify task definition revision?"
  PS3=$'\nChoose: '
  select REVISION_OPTION in "Use latest" "Specify manually"; do
    case $REVISION_OPTION in
      "Use latest")
        TASK_DEF="$TASK_FAMILY"
        break
        ;;
      "Specify manually")
        read -p "Enter revision number: " REVISION
        TASK_DEF="$TASK_FAMILY:$REVISION"
        break
        ;;
    esac
  done
  
  read -p "Enter service name: " SERVICE_NAME
  read -p "Enter desired task count (your usual: 2, press Enter for default): " DESIRED_COUNT
  DESIRED_COUNT=${DESIRED_COUNT:-2}
  
  echo -e "\n 🔄 Select service type:"
  PS3=$'\nChoose: '
  select SERVICE_TYPE in "REPLICA" "DAEMON"; do
    break
  done
  
  LAUNCH_TYPE=$(aws ecs describe-task-definition --task-definition "$TASK_DEF" --region "$REGION" --query 'taskDefinition.requiresCompatibilities[0]' --output text)
  
  if [ "$LAUNCH_TYPE" = "FARGATE" ]; then
    echo -e "\n 🌐 Network Configuration Required for Fargate"
    read -p "Enter subnet IDs (comma-separated): " SUBNETS
    read -p "Enter security group IDs (comma-separated): " SECURITY_GROUPS
    
    echo -e "\n 🔒 Assign public IP?"
    PS3=$'\nChoose option: '
    select PUBLIC_IP in "ENABLED" "DISABLED"; do
      break
    done
    
    echo -e "\n 🚀 Creating Fargate service with $SERVICE_TYPE deployment..."
    aws ecs create-service \
      --cluster "$CLUSTER_NAME" \
      --service-name "$SERVICE_NAME" \
      --task-definition "$TASK_DEF" \
      --desired-count "$DESIRED_COUNT" \
      --launch-type FARGATE \
      --platform-version LATEST \
      --scheduling-strategy "$SERVICE_TYPE" \
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=$PUBLIC_IP}" \
      --region "$REGION"
  else
    echo -e "\n 🚀 Creating EC2 service..."
    aws ecs create-service \
      --cluster "$CLUSTER_NAME" \
      --service-name "$SERVICE_NAME" \
      --task-definition "$TASK_DEF" \
      --desired-count "$DESIRED_COUNT" \
      --launch-type EC2 \
      --scheduling-strategy "$SERVICE_TYPE" \
      --region "$REGION"
  fi
  
  if [ $? -eq 0 ]; then
    echo -e "\n ✅ ECS Service '$SERVICE_NAME' created successfully!\n"
  else
    echo -e "\n ❌ Failed to create service.\n"
  fi
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

# Full Setup - All in one
full_setup() {
  echo -e "\n 🎯 Starting Full ECS Setup...\n"
  
  select_region
  
  # Step 1: ECR
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "📦 STEP 1: ECR Repository"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "Enter ECR repository name: " ECR_NAME
  
  echo -e "\n 🔒 Repository type:"
  PS3=$'\nChoose: '
  select REPO_TYPE in "Private" "Public"; do
    if [ "$REPO_TYPE" = "Private" ]; then
      aws ecr create-repository --repository-name "$ECR_NAME" --region "$REGION"
      ECR_URI=$(aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$REGION" --query 'repositories[0].repositoryUri' --output text)
      echo -e "\n ✅ ECR URI: $ECR_URI"
    else
      aws ecr-public create-repository --repository-name "$ECR_NAME" --region us-east-1
    fi
    break
  done
  
  # Step 2: Cluster
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "🏗️ STEP 2: ECS Cluster"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "Enter cluster name: " CLUSTER_NAME
  aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$REGION"
  echo -e "\n ✅ Cluster created: $CLUSTER_NAME"
  
  # Step 3: Task Definition
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "📋 STEP 3: Task Definition"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "Enter task family name: " TASK_FAMILY
  read -p "Enter container name: " CONTAINER_NAME
  read -p "Enter image (or use ECR URI above): " IMAGE
  
  echo -e "\n 💻 Launch type:"
  PS3=$'\nChoose: '
  select LAUNCH_TYPE in "FARGATE" "EC2"; do
    break
  done
  
  if [ "$LAUNCH_TYPE" = "FARGATE" ]; then
    echo -e "\n Select CPU (your usual: 1024):"
    select CPU in "256" "512" "1024 [Your usual]" "2048" "4096"; do 
      CPU=$(echo $CPU | awk '{print $1}')
      break
    done
    echo -e "\n Select Memory Hard Limit (your usual: 3072):"
    select MEMORY in "512" "1024" "2048" "3072 [Your usual]" "4096" "8192"; do 
      MEMORY=$(echo $MEMORY | awk '{print $1}')
      break
    done
    read -p "Memory Soft Limit (your usual: 1024, press Enter to skip): " MEMORY_SOFT
  else
    CPU="256"
    MEMORY="512"
  fi
  
  read -p "Container port (default: 80): " CONTAINER_PORT
  CONTAINER_PORT=${CONTAINER_PORT:-80}
  
  TASK_DEF_JSON=$(cat <<EOF
{
  "family": "$TASK_FAMILY",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["$LAUNCH_TYPE"],
  "cpu": "$CPU",
  "memory": "$MEMORY",
  "containerDefinitions": [
    {
      "name": "$CONTAINER_NAME",
      "image": "$IMAGE",
      "portMappings": [{"containerPort": $CONTAINER_PORT, "protocol": "tcp"}],
      "essential": true
    }
  ]
}
EOF
)
  
  echo "$TASK_DEF_JSON" | aws ecs register-task-definition --region "$REGION" --cli-input-json file:///dev/stdin
  echo -e "\n ✅ Task definition registered"
  
  # Step 4: Service
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "🚀 STEP 4: ECS Service"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "Enter service name: " SERVICE_NAME
  read -p "Desired task count (your usual: 2, press Enter for default): " DESIRED_COUNT
  DESIRED_COUNT=${DESIRED_COUNT:-2}
  
  if [ "$LAUNCH_TYPE" = "FARGATE" ]; then
    read -p "Subnet IDs (comma-separated): " SUBNETS
    read -p "Security group IDs (comma-separated): " SECURITY_GROUPS
    
    aws ecs create-service \
      --cluster "$CLUSTER_NAME" \
      --service-name "$SERVICE_NAME" \
      --task-definition "$TASK_FAMILY" \
      --desired-count "$DESIRED_COUNT" \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=ENABLED}" \
      --region "$REGION"
  else
    aws ecs create-service \
      --cluster "$CLUSTER_NAME" \
      --service-name "$SERVICE_NAME" \
      --task-definition "$TASK_FAMILY" \
      --desired-count "$DESIRED_COUNT" \
      --launch-type EC2 \
      --region "$REGION"
  fi
  
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "✅ FULL SETUP COMPLETE!"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "📦 ECR: $ECR_NAME"
  echo -e "🏗️ Cluster: $CLUSTER_NAME"
  echo -e "📋 Task: $TASK_FAMILY"
  echo -e "🚀 Service: $SERVICE_NAME"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
  
  read -p "Press Enter to return to main menu..."
  main_menu
}

main_menu


####--- NOTES ---####

# Prerequisites:
# - AWS CLI installed and configured
# - Appropriate IAM permissions for ECS, ECR
# - For Fargate: VPC with subnets and security groups
# - For EC2: ECS-optimized EC2 instances registered to cluster

# IAM Permissions Required:
# - ecr:CreateRepository, ecr:DescribeRepositories
# - ecs:CreateCluster, ecs:CreateService
# - ecs:RegisterTaskDefinition, ecs:DescribeTaskDefinition
# - ecs:ListClusters, ecs:ListTaskDefinitions

# For Fargate, ensure ecsTaskExecutionRole exists:
# aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://trust-policy.json
# aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
