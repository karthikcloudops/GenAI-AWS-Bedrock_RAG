provider "aws" {
  region = "ap-southeast-2"
}

# Import other Terraform configuration files
module "storage" {
  source = "./modules/storage"
}

module "compute" {
  source = "./modules/compute"
  document_bucket_id = module.storage.document_bucket_id
  document_bucket_arn = module.storage.document_bucket_arn
  opensearch_endpoint = module.storage.opensearch_endpoint
  opensearch_username = module.storage.opensearch_username
  opensearch_password = module.storage.opensearch_password
}

module "api" {
  source = "./modules/api"
  query_lambda_invoke_arn = module.compute.query_lambda_invoke_arn
  query_lambda_function_name = module.compute.query_lambda_function_name
}

module "iam" {
  source = "./modules/iam"
}

module "eks" {
  source = "./modules/eks"
}

module "frontend" {
  source = "./modules/frontend"
  api_endpoint = module.api.api_endpoint
}

# Output important information
output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api.api_endpoint
}

output "document_bucket" {
  description = "S3 bucket for document storage"
  value       = module.storage.document_bucket_id
}

output "opensearch_dashboard" {
  description = "OpenSearch dashboard URL"
  value       = "https://${module.storage.opensearch_endpoint}/_dashboards/"
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = module.frontend.frontend_url
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.frontend.cloudfront_domain_name
}