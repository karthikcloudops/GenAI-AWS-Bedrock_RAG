# Deployment Checklist - CloudOpsPilot GenAI Project

Use this checklist to ensure you complete all necessary steps after cloning the repository.

## ✅ Prerequisites Check

- [ ] **AWS CLI** installed and configured
  ```bash
  aws --version
  aws sts get-caller-identity
  ```
- [ ] **Terraform** installed (version >= 1.0)
  ```bash
  terraform --version
  ```
- [ ] **Python 3.8+** and pip installed
  ```bash
  python3 --version
  pip --version
  ```
- [ ] **AWS account** with appropriate permissions

## 🚀 Deployment Steps

### Step 1: Repository Setup
- [ ] Clone the repository
  ```bash
  git clone <repository-url>
  cd GenAI-AWS-Bedrock_RAG
  ```
- [ ] Verify you're in the correct directory
  ```bash
  ls -la
  # Should show: app/ docs/ frontend/ scripts/ terraform/
  ```
- [ ] Make scripts executable
  ```bash
  chmod +x scripts/*.sh
  ```

### Step 2: Choose Your Deployment Method

**Option A: Automated Deployment (Recommended)**
- [ ] Run the automated script
  ```bash
  ./scripts/deploy.sh
  ```
- [ ] Wait for completion (10-15 minutes)
- [ ] Note the output URLs

**Option B: Manual Deployment (If automated fails)**
- [ ] Prepare Lambda dependencies
  ```bash
  mkdir -p temp_lambda_package
  cp app/lambda/*.py temp_lambda_package/
  cd temp_lambda_package
  pip install -r requirements.txt -t .
  zip -r ../terraform/modules/compute/lambda_functions.zip .
  cd ..
  ```
- [ ] Deploy infrastructure
  ```bash
  cd terraform
  terraform init
  terraform plan
  terraform apply
  # Type 'yes' when prompted
  ```
- [ ] Deploy frontend
  ```bash
  FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)
  aws s3 sync ../frontend/ s3://$FRONTEND_BUCKET --region ap-southeast-2
  ```
- [ ] Upload sample documents
  ```bash
  DOCUMENT_BUCKET=$(terraform output -raw document_bucket)
  aws s3 cp ../docs/sample_knowledge_base/company_handbook.md s3://$DOCUMENT_BUCKET/
  ```

### Step 3: Get Your Access URLs
- [ ] Get all URLs
  ```bash
  cd terraform
  terraform output
  ```
- [ ] Note down these URLs:
  - Frontend URL: `https://<cloudfront-domain>`
  - API Endpoint: `https://<api-gateway-url>/prod/query`
  - OpenSearch Dashboard: `https://<opensearch-domain>/_dashboards/`

## 🧪 Testing Your Deployment

### Frontend Test
- [ ] Open frontend URL in browser
- [ ] Verify you see the chat interface
- [ ] Check that the page loads without errors

### API Test
- [ ] Test API endpoint
  ```bash
  API_URL=$(cd terraform && terraform output -raw api_endpoint)
  curl -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d '{"query": "Hello, can you help me?"}'
  ```
- [ ] Verify you get a response (even if it's an error message)

### Document Processing Test
- [ ] Verify sample document is uploaded
  ```bash
  DOC_BUCKET=$(cd terraform && terraform output -raw document_bucket)
  aws s3 ls s3://$DOC_BUCKET/
  ```

## 🔧 Troubleshooting Checklist

If something doesn't work, check these common issues:

### Frontend Issues
- [ ] Wait 5-10 minutes for CloudFront propagation
- [ ] Check if frontend files are uploaded to S3
- [ ] Verify CloudFront distribution is enabled

### API Issues
- [ ] Check Lambda function logs in CloudWatch
- [ ] Verify API Gateway integration
- [ ] Check IAM permissions

### Infrastructure Issues
- [ ] Verify AWS region is correct
- [ ] Check AWS credentials are valid
- [ ] Ensure you have sufficient AWS permissions

## 📊 Post-Deployment

### Monitor Your Deployment
- [ ] Check AWS Console for resource status
- [ ] Monitor CloudWatch logs for errors
- [ ] Test the chat interface with sample questions

### Cost Monitoring
- [ ] Set up AWS billing alerts
- [ ] Monitor OpenSearch domain costs (largest expense)
- [ ] Check Lambda function invocation costs

### Security
- [ ] Review IAM roles and policies
- [ ] Check S3 bucket permissions
- [ ] Verify CloudFront security settings

## 🧹 Cleanup (When Done)

- [ ] Navigate to terraform directory
  ```bash
  cd terraform
  ```
- [ ] Destroy all resources
  ```bash
  terraform destroy
  # Type 'yes' when prompted
  ```
- [ ] Verify all resources are deleted in AWS Console

## 📞 Getting Help

If you encounter issues:

1. **Check the logs**: Look at CloudWatch logs for error messages
2. **Read the full guide**: Check [QUICKSTART.md](QUICKSTART.md) for detailed instructions
3. **Verify prerequisites**: Make sure all tools are installed and configured
4. **Check AWS permissions**: Ensure your AWS user has the required permissions
5. **Create an issue**: Report problems in the repository

## 🎉 Success!

Once you've completed all the steps above, your RAG system should be fully operational!

**Your application is ready when:**
- ✅ Frontend loads in browser
- ✅ API responds to requests
- ✅ Sample documents are uploaded
- ✅ Chat interface is functional

**Next steps:**
- Upload your own documents
- Customize the interface
- Integrate with your systems
- Monitor usage and costs 