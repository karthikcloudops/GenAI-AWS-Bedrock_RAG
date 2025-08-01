#!/bin/bash

# Deploy Frontend Script
# This script builds the React frontend and deploys it to S3

set -e

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

# Check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 16+"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI"
        exit 1
    fi
    
    print_status "All dependencies are installed"
}

# Get Terraform outputs
get_terraform_outputs() {
    print_status "Getting Terraform outputs..."
    
    if [ ! -d "terraform" ]; then
        print_error "terraform directory not found. Please run this script from the project root"
        exit 1
    fi
    
    cd terraform
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Get the frontend bucket name and API endpoint
    FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
    API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
    
    if [ -z "$FRONTEND_BUCKET" ]; then
        print_error "Could not get frontend bucket name from Terraform outputs"
        print_warning "Make sure you have deployed the infrastructure first: terraform apply"
        exit 1
    fi
    
    if [ -z "$API_ENDPOINT" ]; then
        print_error "Could not get API endpoint from Terraform outputs"
        print_warning "Make sure you have deployed the infrastructure first: terraform apply"
        exit 1
    fi
    
    print_status "Frontend bucket: $FRONTEND_BUCKET"
    print_status "API endpoint: $API_ENDPOINT"
    
    cd ..
}

# Build the frontend
build_frontend() {
    print_status "Building frontend..."
    
    if [ ! -d "app/frontend" ]; then
        print_error "Frontend directory not found: app/frontend"
        exit 1
    fi
    
    cd app/frontend
    
    # Install dependencies if node_modules doesn't exist
    if [ ! -d "node_modules" ]; then
        print_status "Installing dependencies..."
        npm install
    fi
    
    # Create .env file with API endpoint
    print_status "Creating environment configuration..."
    cat > .env << EOF
REACT_APP_API_URL=$API_ENDPOINT
EOF
    
    # Build the application
    print_status "Building React application..."
    npm run build
    
    if [ ! -d "build" ]; then
        print_error "Build failed. build directory not found"
        exit 1
    fi
    
    print_status "Frontend built successfully"
    cd ../..
}

# Deploy to S3
deploy_to_s3() {
    print_status "Deploying to S3..."
    
    # Sync build directory to S3
    aws s3 sync app/frontend/build/ s3://$FRONTEND_BUCKET/ --delete
    
    if [ $? -eq 0 ]; then
        print_status "Frontend deployed successfully to S3"
    else
        print_error "Failed to deploy to S3"
        exit 1
    fi
}

# Invalidate CloudFront cache
invalidate_cache() {
    print_status "Invalidating CloudFront cache..."
    
    cd terraform
    DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    cd ..
    
    if [ -n "$DISTRIBUTION_ID" ]; then
        aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
        print_status "CloudFront cache invalidation initiated"
    else
        print_warning "Could not get CloudFront distribution ID. Cache invalidation skipped."
    fi
}

# Main execution
main() {
    print_status "Starting frontend deployment..."
    
    check_dependencies
    get_terraform_outputs
    build_frontend
    deploy_to_s3
    invalidate_cache
    
    print_status "Frontend deployment completed successfully!"
    print_status "Your application should be available at the CloudFront URL shortly."
    print_status "You can get the URL by running: terraform output frontend_url"
}

# Run main function
main "$@" 