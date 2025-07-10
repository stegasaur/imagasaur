#!/bin/bash
set -e

# Default values
ENVIRONMENT="dev"
REGION="us-west-2"
PROJECT_NAME="imagasaur"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -e|--environment)
      ENVIRONMENT="$2"
      shift # past argument
      shift # past value
      ;;
    -r|--region)
      REGION="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--project)
      PROJECT_NAME="$2"
      shift # past argument
      shift # past value
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Deploying $PROJECT_NAME to $ENVIRONMENT environment in $REGION"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required commands
for cmd in python3 pip3 zip aws terraform; do
  if ! command_exists "$cmd"; then
    echo "Error: $cmd is not installed or not in PATH"
    exit 1
  fi
done

# Create a temporary directory for packaging
TMP_DIR="/tmp/${PROJECT_NAME}-deploy-$(date +%s)"
mkdir -p "$TMP_DIR"

# Function to package a Lambda function
package_lambda() {
  local lambda_dir="$1"
  local output_zip="$2"
  
  echo "Packaging Lambda function in $lambda_dir..."
  
  # Create a virtual environment
  python3 -m venv "$TMP_DIR/venv"
  source "$TMP_DIR/venv/bin/activate"
  
  # Install dependencies
  pip3 install -r "$lambda_dir/requirements.txt" -t "$TMP_DIR/package"
  
  # Copy the application code
  cp "$lambda_dir/app.py" "$TMP_DIR/package/"
  
  # Create the deployment package
  cd "$TMP_DIR/package"
  zip -r "$TMP_DIR/function.zip" .
  
  # Move the package to the target location
  mkdir -p "$(dirname "$output_zip")"
  mv "$TMP_DIR/function.zip" "$output_zip"
  
  # Clean up
  deactivate
  cd - > /dev/null
  rm -rf "$TMP_DIR/venv" "$TMP_DIR/package"
  
  echo "Created package at $output_zip"
}

# Package the Lambda functions
echo "Packaging Lambda functions..."
package_lambda "backend/upload_service" "backend/upload_service/function.zip"
package_lambda "backend/processing_service" "backend/processing_service/function.zip"

# Initialize and apply Terraform
echo "Initializing Terraform..."
cd infrastructure
terraform init

echo "Applying Terraform configuration..."
terraform apply \
  -var="environment=$ENVIRONMENT" \
  -var="region=$REGION" \
  -var="project_name=$PROJECT_NAME" \
  -auto-approve

# Get the CloudFront distribution URL
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)

# Clean up
rm -rf "$TMP_DIR"

echo ""
echo "Deployment complete!"
echo ""
echo "Frontend URL: https://$CLOUDFRONT_URL"
echo "API Gateway URL: $API_GATEWAY_URL"
echo ""
echo "To test the deployment:"
echo "1. Open the Frontend URL in your browser"
echo "2. Use the web interface to upload an image"
echo "3. Check the S3 buckets for the uploaded image and generated thumbnail"

exit 0
