# Lambda functions and EKS configuration

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_functions.zip"
  
  source {
    content  = file("${path.root}/../app/lambda/query_processor.py")
    filename = "query_processor.py"
  }
  
  source {
    content  = file("${path.root}/../app/lambda/document_processor.py")
    filename = "document_processor.py"
  }
  
  source {
    content  = file("${path.root}/../app/lambda/utils.py")
    filename = "utils.py"
  }
}

# Lambda for query processing
resource "aws_lambda_function" "query_processor" {
  function_name = "rag-query-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "query_processor.lambda_handler"
  runtime       = "python3.10"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = "https://${var.opensearch_endpoint}",
      OPENSEARCH_USERNAME = var.opensearch_username,
      OPENSEARCH_PASSWORD = var.opensearch_password,
      BEDROCK_MODEL_ID    = "anthropic.claude-v2"
    }
  }
}

# Lambda for document ingestion
resource "aws_lambda_function" "document_processor" {
  function_name = "rag-document-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "document_processor.lambda_handler"
  runtime       = "python3.10"
  timeout       = 300
  memory_size   = 1024

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = "https://${var.opensearch_endpoint}",
      OPENSEARCH_USERNAME = var.opensearch_username,
      OPENSEARCH_PASSWORD = var.opensearch_password,
      BEDROCK_MODEL_ID    = "amazon.titan-embed-text-v1",
      DOCUMENT_BUCKET     = var.document_bucket_id
    }
  }
}

# S3 event to trigger document processing
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.document_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.document_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

# Lambda permission for S3
resource "aws_lambda_permission" "s3_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.document_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.document_bucket_arn
}

# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "rag-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda S3 access policy
resource "aws_iam_policy" "lambda_s3_access" {
  name        = "rag-lambda-s3-access"
  description = "Allow Lambda to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = [
          var.document_bucket_arn,
          "${var.document_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

# Lambda Bedrock access policy
resource "aws_iam_policy" "lambda_bedrock_access" {
  name        = "rag-lambda-bedrock-access"
  description = "Allow Lambda to access Amazon Bedrock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetFoundationModel"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_bedrock" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_bedrock_access.arn
}

# Outputs
output "query_lambda_invoke_arn" {
  value = aws_lambda_function.query_processor.invoke_arn
}

output "query_lambda_function_name" {
  value = aws_lambda_function.query_processor.function_name
}