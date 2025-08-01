variable "document_bucket_id" {
  description = "ID of the S3 bucket for document storage"
  type        = string
}

variable "document_bucket_arn" {
  description = "ARN of the S3 bucket for document storage"
  type        = string
}

variable "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch domain"
  type        = string
}

variable "opensearch_username" {
  description = "Username for OpenSearch authentication"
  type        = string
}

variable "opensearch_password" {
  description = "Password for OpenSearch authentication"
  type        = string
  sensitive   = true
}