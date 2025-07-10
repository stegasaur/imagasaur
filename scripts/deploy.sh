#!/bin/bash

# Imagasaur Deployment Script
# This script deploys the entire application to AWS

set -e

echo "🚀 Starting Imagasaur deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install it first."
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install it first."
    exit 1
fi

print_status "All required tools are installed."

# Step 1: Deploy Infrastructure
print_status "Step 1: Deploying infrastructure with Terraform..."
cd terraform

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Plan the deployment
print_status "Planning Terraform deployment..."
terraform plan -out=tfplan

# Apply the plan
print_status "Applying Terraform configuration..."
terraform apply tfplan

# Get outputs
FRONTEND_URL=$(terraform output -raw frontend_url)
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
UPLOADS_BUCKET=$(terraform output -raw uploads_bucket)
PROCESSED_BUCKET=$(terraform output -raw processed_bucket)

print_status "Infrastructure deployed successfully!"
print_status "Frontend URL: $FRONTEND_URL"
print_status "API Gateway URL: $API_GATEWAY_URL"
print_status "Uploads Bucket: $UPLOADS_BUCKET"
print_status "Processed Bucket: $PROCESSED_BUCKET"

cd ..

# Step 2: Build and deploy Lambda function
print_status "Step 2: Building and deploying Lambda function..."

cd lambda

# Install dependencies
print_status "Installing Lambda dependencies..."
pip install -r requirements.txt -t .

# Create deployment package
print_status "Creating Lambda deployment package..."
zip -r image_processor.zip . -x "*.pyc" "__pycache__/*" "*.git*"

# The Lambda function will be deployed by Terraform
print_status "Lambda function will be deployed by Terraform."

cd ..

# Step 3: Build and deploy frontend
print_status "Step 3: Building and deploying frontend..."

cd frontend

# Install dependencies
print_status "Installing frontend dependencies..."
npm install

# Build the application
print_status "Building React application..."
npm run build

# Upload to S3 (this would need to be done after infrastructure is created)
print_status "Frontend built successfully!"
print_warning "Please manually upload the build folder to the S3 bucket: $UPLOADS_BUCKET"

cd ..

# Step 4: Deploy backend (optional - for local development)
print_status "Step 4: Backend deployment..."
print_warning "For production, deploy the backend to AWS Lambda or ECS."
print_status "For local development, run: cd backend && python app.py"

print_status "🎉 Deployment completed!"
print_status "Next steps:"
echo "1. Upload the frontend build folder to S3 bucket: $UPLOADS_BUCKET"
echo "2. Configure the backend environment variables"
echo "3. Deploy the backend to your preferred AWS service"
echo "4. Update the frontend API URL to point to your deployed backend"
