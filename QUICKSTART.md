# Quick Start Guide - CloudOpsPilot GenAI Project

This guide will help you deploy the entire RAG system step-by-step, even if you're new to AWS and Terraform.

## Prerequisites

Before you begin, ensure you have:

- ✅ **AWS CLI** installed and configured (`aws configure`)
- ✅ **Terraform** installed (version >= 1.0)
- ✅ **Python 3.8+** and pip installed
- ✅ **AWS account** with appropriate permissions

### Installing Prerequisites

#### 1. Install AWS CLI
```bash
# On Ubuntu/Debian
sudo apt update
sudo apt install awscli

# On macOS with Homebrew
brew install awscli

# On Windows
# Download from https://aws.amazon.com/cli/
```

#### 2. Configure AWS CLI
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., ap-southeast-2)
# Enter your output format (json)
```

#### 3. Install Terraform
```bash
# On Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# On macOS with Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# On Windows
# Download from https://www.terraform.io/downloads
```

#### 4. Install Python and pip
```bash
# On Ubuntu/Debian
sudo apt update
sudo apt install python3 python3-pip

# On macOS
brew install python3

# On Windows
# Download from https://www.python.org/downloads/
```

## 🚀 Step-by-Step Deployment

### Step 1: Clone the Repository
```bash
# Clone the repository
git clone <repository-url>
cd GenAI-AWS-Bedrock_RAG

# Verify you're in the right directory
ls -la
# You should see: app/ docs/ frontend/ scripts/ terraform/ etc.
```

### Step 2: Make Scripts Executable
```bash
# Make all scripts executable
chmod +x scripts/*.sh

# Verify scripts are executable
ls -la scripts/
```

### Step 3: Deploy Everything (Automated)
```bash
# Run the automated deployment script
./scripts/deploy.sh
```

**What this script does:**
1. ✅ Checks all prerequisites
2. ✅ Prepares Lambda deployment packages
3. ✅ Deploys all AWS infrastructure
4. ✅ Deploys the frontend
5. ✅ Uploads sample documents
6. ✅ Shows you the access URLs

### Step 4: Manual Deployment (If Automated Fails)

If the automated script doesn't work, follow these manual steps:

#### 3a. Prepare Lambda Dependencies
```bash
# Create temporary directory for Lambda package
mkdir -p temp_lambda_package
cp app/lambda/*.py temp_lambda_package/

# Install dependencies (if requirements.txt exists)
cd temp_lambda_package
pip install -r requirements.txt -t .
zip -r ../terraform/modules/compute/lambda_functions.zip .
cd ..
```

#### 3b. Deploy Infrastructure
```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform (downloads required providers)
terraform init

# Review what will be deployed
terraform plan

# Deploy the infrastructure (this may take 10-15 minutes)
terraform apply

# When prompted, type 'yes' to confirm
```

#### 3c. Deploy Frontend
```bash
# Get the frontend bucket name from Terraform output
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)

# Upload frontend files
aws s3 sync ../frontend/ s3://$FRONTEND_BUCKET --region ap-southeast-2
```

#### 3d. Upload Sample Documents
```bash
# Get the document bucket name
DOCUMENT_BUCKET=$(terraform output -raw document_bucket)

# Upload sample document
aws s3 cp ../docs/sample_knowledge_base/company_handbook.md s3://$DOCUMENT_BUCKET/
```

### Step 4: Get Your Access URLs
```bash
# Get all the important URLs
cd terraform
terraform output

# You'll see output like:
# api_endpoint = "https://xxxxx.execute-api.ap-southeast-2.amazonaws.com/prod/query"
# frontend_url = "https://xxxxx.cloudfront.net"
# opensearch_dashboard = "https://xxxxx.es.amazonaws.com/_dashboards/"
```

## 🎯 What You'll Get

After deployment, you'll have access to:

- **Frontend**: `https://<cloudfront-domain>` - Modern chat interface
- **API**: `https://<api-gateway-url>/prod/query` - REST API endpoint
- **OpenSearch Dashboard**: `https://<opensearch-domain>/_dashboards/` - Vector database management

## 🧪 Test Your Deployment

### 1. Test the Frontend
```bash
# Open this URL in your browser
echo "Frontend URL: $(cd terraform && terraform output -raw frontend_url)"
```

**What to expect:**
- A modern chat interface with a green theme
- File upload section at the top
- Chat area in the middle
- Input box at the bottom

### 2. Test the API
```bash
# Test the API directly
API_URL=$(cd terraform && terraform output -raw api_endpoint)
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"query": "Hello, can you help me?"}'
```

**Expected response:** JSON with AI response or error message

### 3. Test Document Processing
```bash
# Upload a document to test processing
DOC_BUCKET=$(cd terraform && terraform output -raw document_bucket)
aws s3 cp docs/sample_knowledge_base/company_handbook.md s3://$DOC_BUCKET/
```

## 🔧 Troubleshooting Common Issues

### Issue 1: "AWS CLI not configured"
```bash
aws configure
# Follow the prompts to enter your AWS credentials
```

### Issue 2: "Terraform not found"
```bash
# Install Terraform (see prerequisites section above)
terraform --version  # Verify installation
```

### Issue 3: "Permission denied" on scripts
```bash
chmod +x scripts/*.sh
```

### Issue 4: "AWS credentials not found"
```bash
# Check if AWS credentials are configured
aws sts get-caller-identity

# If this fails, run:
aws configure
```

### Issue 5: "Frontend not loading"
```bash
# Wait 5-10 minutes for CloudFront to propagate
# Check if files are uploaded:
FRONTEND_BUCKET=$(cd terraform && terraform output -raw frontend_bucket_name)
aws s3 ls s3://$FRONTEND_BUCKET/
```

### Issue 6: "API returning 500 errors"
```bash
# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/rag"

# Check specific function logs
aws logs tail /aws/lambda/rag-query-processor --follow
```

### Issue 7: "Terraform plan shows errors"
```bash
# Make sure you're in the right region
aws configure get region

# Should be ap-southeast-2 or your preferred region
# If not, run: aws configure
```

## 🧹 Cleanup

When you're done testing, clean up all resources:

```bash
# Navigate to terraform directory
cd terraform

# Destroy all resources
terraform destroy

# When prompted, type 'yes' to confirm
```

**⚠️ Warning**: This will permanently delete all data and resources.

## 📊 Cost Estimation

Estimated monthly costs (varies by usage):
- **Light usage**: $50-100/month
- **Medium usage**: $100-300/month
- **Heavy usage**: $300+/month

Main cost drivers:
- OpenSearch domain (largest cost)
- Lambda function invocations
- S3 storage and requests
- CloudFront data transfer

## 🆘 Getting Help

If you encounter issues:

1. **Check the logs**: Look at CloudWatch logs for error messages
2. **Verify prerequisites**: Make sure all tools are installed and configured
3. **Check AWS permissions**: Ensure your AWS user has the required permissions
4. **Read the full README**: Check [README.md](README.md) for detailed documentation
5. **Create an issue**: Report problems in the repository

## 🎉 You're Ready!

Your RAG system is now live and ready to process documents and answer questions intelligently!

**Next steps:**
1. Upload your own documents to the S3 bucket
2. Customize the frontend interface
3. Integrate with your existing systems
4. Monitor usage and costs in AWS Console 