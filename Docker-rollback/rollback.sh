#!/bin/bash

ECR_REGISTRY="000000000000.dkr.ecr.us-east-2.amazonaws.com"
ECR_REPOSITORY="factorygpt-backend"
AWS_ACCOUNT="000000000000"

# Export AWS_ACCOUNT environment variable
#export AWS_ACCOUNT=${{ secrets.AWS_ACCOUNT }}

# ECR login
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.us-east-2.amazonaws.com



################## CHECK IF THERE IS A NEW IMAGE ON ECR #############################
# Get the digest of the remote image with "latest" tag
REMOTE_DIGEST=$(aws ecr describe-images \
    --repository-name $ECR_REPOSITORY \
    --image-ids imageTag=latest \
    --query 'imageDetails[0].imageDigest' \
    --output text)

# Get the digest of the local image with the "latest" tag
LOCAL_DIGEST=$(docker image inspect $ECR_REGISTRY/$ECR_REPOSITORY:latest \
    --format='{{index .RepoDigests 0}}' | cut -d@ -f2)

echo "Checking if the latest image in ECR differs from latest on the local machine..."
if [ "$REMOTE_DIGEST" == "$LOCAL_DIGEST" ]; then
    echo "No new image. The application is already up to date. Remote and local image digests match."
    exit 0
fi
######################################################################################



# Backup the currently running image
echo "New version of the application detected"
echo "Backing up current image"
docker tag $ECR_REGISTRY/$ECR_REPOSITORY:latest $ECR_REGISTRY/$ECR_REPOSITORY:rollback

# Pull the latest image
echo "Pulling latest image..."
docker pull $ECR_REGISTRY/$ECR_REPOSITORY:latest

# Restart the service with new image
docker compose up -d

# Wait for health check (adjust timing as needed)
echo "Waiting for health check..."
sleep 60  # Give time for the container to stabilize

# Check container health
if curl -f http://localhost:80/health; then
  echo "Newest version app is healthy! No rollback needed!!"
  docker image rm -f $(docker images | grep rollback | awk -F' ' '{print $3}')
else
  echo "Health check failed. Rollback initiated!!"
  docker tag $ECR_REGISTRY/$ECR_REPOSITORY:latest $ECR_REGISTRY/$ECR_REPOSITORY:broken
  docker tag $ECR_REGISTRY/$ECR_REPOSITORY:rollback $ECR_REGISTRY/$ECR_REPOSITORY:latest
  docker rmi $ECR_REGISTRY/$ECR_REPOSITORY:rollback
  docker compose up -d
  docker image rm -f $(docker images | grep broken | awk -F' ' '{print $3}')

  # Wait to ensure rollback is initializing
  echo "Waiting to ensure rollback initializes"
  sleep 60  # Give time for the container to stabilize

  # Check rollback container health
  if curl -f http://localhost:80/health; then
    echo "Rollback is healthy"
  else
    echo "Rollback Health check failed"; exit 1
  fi

fi
