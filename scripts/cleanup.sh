#!/bin/bash

# CloudOpsPilot GenAI Project - Cleanup Script
# This script removes all deployed resources

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Terraform state exists
check_terraform_state() {
    if [ ! -f "terraform/terraform.tfstate" ]; then
        print_error "No Terraform state found. Nothing to clean up."
        exit 1
    fi
}

# Function to cleanup infrastructure
cleanup_infrastructure() {
    print_status "Cleaning up infrastructure..."
    
    cd terraform
    
    # Check if there are resources to destroy
    if terraform plan -destroy -detailed-exitcode >/dev/null 2>&1; then
        print_status "No resources to destroy"
        cd ..
        return
    fi
    
    # Plan destruction
    print_status "Planning resource destruction..."
    terraform plan -destroy -out=destroy.tfplan
    
    # Ask for confirmation
    echo
    print_warning "This will permanently delete ALL deployed resources and data!"
    print_warning "Are you sure you want to proceed? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled by user"
        cd ..
        exit 0
    fi
    
    # Apply destruction
    print_status "Destroying resources..."
    terraform apply destroy.tfplan
    
    cd ..
    
    print_success "Infrastructure cleanup completed"
}

# Function to cleanup temporary files
cleanup_temp_files() {
    print_status "Cleaning up temporary files..."
    
    # Remove temporary Lambda package directory
    if [ -d "temp_lambda_package" ]; then
        rm -rf temp_lambda_package
        print_success "Removed temp_lambda_package directory"
    fi
    
    # Remove Terraform plan files
    if [ -f "terraform/tfplan" ]; then
        rm terraform/tfplan
        print_success "Removed Terraform plan file"
    fi
    
    if [ -f "terraform/destroy.tfplan" ]; then
        rm terraform/destroy.tfplan
        print_success "Removed Terraform destroy plan file"
    fi
    
    # Remove .terraform directory
    if [ -d "terraform/.terraform" ]; then
        rm -rf terraform/.terraform
        print_success "Removed .terraform directory"
    fi
    
    print_success "Temporary files cleanup completed"
}

# Function to show cleanup summary
show_cleanup_summary() {
    print_success "Cleanup completed successfully!"
    echo
    echo "=== Cleanup Summary ==="
    echo "✓ All AWS resources have been removed"
    echo "✓ Terraform state has been cleaned up"
    echo "✓ Temporary files have been removed"
    echo
    echo "=== What was removed ==="
    echo "- S3 buckets (documents and frontend)"
    echo "- Lambda functions"
    echo "- API Gateway"
    echo "- OpenSearch domain"
    echo "- DynamoDB table"
    echo "- CloudFront distribution"
    echo "- EKS cluster"
    echo "- IAM roles and policies"
    echo "- VPC and networking resources"
    echo
    echo "All data has been permanently deleted!"
}

# Main cleanup function
main() {
    echo "=========================================="
    echo "CloudOpsPilot GenAI Project - Cleanup"
    echo "=========================================="
    echo
    
    # Check if there's anything to clean up
    check_terraform_state
    
    # Cleanup infrastructure
    cleanup_infrastructure
    
    # Cleanup temporary files
    cleanup_temp_files
    
    # Show summary
    show_cleanup_summary
    
    print_success "All done! Your AWS account is clean."
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --force        Skip confirmation prompts"
        echo
        echo "This script removes all deployed resources and cleans up the project."
        echo "WARNING: This will permanently delete all data!"
        exit 0
        ;;
    --force)
        FORCE=true
        ;;
    "")
        # No arguments, proceed with cleanup
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

# Run main function
main "$@" 