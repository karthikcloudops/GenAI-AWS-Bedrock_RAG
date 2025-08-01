# IAM roles and policies

# DynamoDB access policy
resource "aws_iam_policy" "dynamodb_access" {
  name        = "rag-dynamodb-access"
  description = "Allow access to DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:dynamodb:ap-southeast-2:*:table/rag-*"
      }
    ]
  })
}

# OpenSearch access policy
resource "aws_iam_policy" "opensearch_access" {
  name        = "rag-opensearch-access"
  description = "Allow access to OpenSearch domain"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPut",
          "es:ESHttpPost",
          "es:ESHttpDelete"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:es:ap-southeast-2:*:domain/rag-*"
      }
    ]
  })
}

# Outputs
output "dynamodb_policy_arn" {
  value = aws_iam_policy.dynamodb_access.arn
}

output "opensearch_policy_arn" {
  value = aws_iam_policy.opensearch_access.arn
}