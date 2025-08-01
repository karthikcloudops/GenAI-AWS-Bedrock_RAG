# S3 bucket for storing documents
resource "aws_s3_bucket" "document_storage" {
  bucket = "customer-support-docs-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "document_storage_versioning" {
  bucket = aws_s3_bucket.document_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "document_storage_encryption" {
  bucket = aws_s3_bucket.document_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# OpenSearch for vector storage
resource "aws_opensearch_domain" "vector_store" {
  domain_name    = "rag-vector-store"
  engine_version = "OpenSearch_2.5"

  cluster_config {
    instance_type = "t3.small.search"
    instance_count = 1
    zone_awareness_enabled = false
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name = "admin"
      master_user_password = random_password.opensearch_master_password.result
    }
  }

  access_policies = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:ap-southeast-2:${data.aws_caller_identity.current.account_id}:domain/rag-vector-store/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": ["0.0.0.0/0"]
        }
      }
    }
  ]
}
CONFIG

  tags = {
    Name = "rag-vector-store"
  }
}

resource "random_password" "opensearch_master_password" {
  length  = 16
  special = true
}

# DynamoDB table for metadata storage
resource "aws_dynamodb_table" "document_metadata" {
  name           = "rag-document-metadata"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  tags = {
    Name = "rag-document-metadata"
  }
}

data "aws_caller_identity" "current" {}

# Outputs
output "document_bucket_id" {
  value = aws_s3_bucket.document_storage.id
}

output "document_bucket_arn" {
  value = aws_s3_bucket.document_storage.arn
}

output "opensearch_endpoint" {
  value = aws_opensearch_domain.vector_store.endpoint
}

output "opensearch_username" {
  value = "admin"
}

output "opensearch_password" {
  value = random_password.opensearch_master_password.result
  sensitive = true
}