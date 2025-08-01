# Retrieval-Augmented Generation (RAG) Architecture

## Overview

Retrieval-Augmented Generation (RAG) is an AI architecture that enhances Large Language Models (LLMs) by providing them with relevant information retrieved from a knowledge base. This approach combines the strengths of retrieval-based systems with the generative capabilities of LLMs, resulting in responses that are both contextually relevant and factually accurate.

This document outlines the RAG architecture implemented in this project, which uses AWS Bedrock for LLM capabilities and a suite of AWS services for the retrieval pipeline.

## Architecture Components

![RAG Architecture Diagram](architecture.png)

### 1. Document Processing Pipeline

The document processing pipeline is responsible for ingesting documents, processing them, and storing them in a searchable format:

#### Document Ingestion
- **S3**: Documents are uploaded to an S3 bucket
- **Lambda Trigger**: S3 events trigger the document processing Lambda function

#### Document Processing
- **Document Extraction**: Text is extracted from various document formats (PDF, DOCX, TXT)
- **Text Chunking**: Documents are split into smaller, semantically meaningful chunks
- **Embedding Generation**: Each chunk is converted into a vector embedding using Amazon Bedrock's embedding models
- **Metadata Extraction**: Document metadata (title, source, date, etc.) is extracted

#### Storage
- **OpenSearch**: Vector embeddings and document chunks are stored in OpenSearch for vector similarity search
- **DynamoDB**: Document metadata is stored in DynamoDB for efficient retrieval and filtering

### 2. Query Processing Pipeline

The query processing pipeline handles user queries and generates responses:

#### Query Processing
- **API Gateway**: Receives user queries via REST API
- **Lambda Function**: Processes the query and orchestrates the RAG workflow

#### Retrieval
- **Query Embedding**: The user query is converted into a vector embedding
- **Vector Search**: OpenSearch performs a k-nearest neighbors (kNN) search to find similar document chunks
- **Context Assembly**: Retrieved chunks are assembled into a context for the LLM

#### Generation
- **Prompt Construction**: A prompt is constructed with the query and retrieved context
- **LLM Invocation**: Amazon Bedrock is called to generate a response based on the prompt
- **Response Formatting**: The response is formatted with citations to source documents

### 3. Batch Processing (EKS)

For large-scale document processing:

- **EKS Cluster**: Runs containerized document processing jobs
- **Parallel Processing**: Distributes processing across multiple nodes
- **Monitoring**: Tracks processing status and handles failures

## Implementation Details

### Vector Search Configuration

OpenSearch is configured with KNN (k-nearest neighbors) capabilities:

```json
{
  "mappings": {
    "properties": {
      "embedding": {
        "type": "knn_vector",
        "dimension": 1536
      }
    }
  },
  "settings": {
    "index": {
      "knn": true,
      "knn.algo_param.ef_search": 100
    }
  }
}
```

### Chunking Strategy

Documents are chunked using a sliding window approach:

1. Target chunk size: 1000 characters
2. Overlap between chunks: 100 characters
3. Chunks are split at natural sentence boundaries when possible

### Prompt Engineering

The system uses carefully crafted prompts to guide the LLM:

```
Human: You are a helpful assistant that answers questions based only on the provided context.
If you don't know the answer based on the context, say "I don't have enough information to answer this question."
Do not make up information or use your training data to answer.

Context:
{retrieved_context}

Question: {user_query}A
ssistant:
```

## Performance Considerations

### Embedding Model Selection

The choice of embedding model significantly impacts retrieval quality:

- **Amazon Titan Embeddings**: Good balance of performance and cost
- **Other options**: Claude, Cohere, or custom fine-tuned models

### Vector Search Optimization

OpenSearch vector search is optimized with:

- **ef_search parameter**: Controls search accuracy vs. speed tradeoff
- **k value**: Number of nearest neighbors to retrieve (typically 5-10)

### Response Generation

Response generation is optimized with:

- **Temperature**: Set to 0.1 for more deterministic responses
- **Top-p**: Set to 0.9 for focused but slightly varied responses
- **Max tokens**: Limited to control response length

## Security Considerations

### Data Protection

- All data is encrypted at rest and in transit
- S3 bucket policies restrict access to authorized services
- OpenSearch domain uses fine-grained access control

### Authentication and Authorization

- API Gateway uses AWS IAM for authentication
- Lambda functions use IAM roles with least privilege
- EKS cluster uses RBAC for Kubernetes resource access

### Network Security

- OpenSearch domain is deployed in a VPC
- Security groups restrict traffic to authorized sources
- API Gateway uses AWS WAF for request filtering

## Scaling Considerations

### OpenSearch Scaling

- Instance type: t3.small.search for development, m5.large.search for production
- Instance count: 1 for development, 3+ for production with zone awareness
- Storage: EBS volumes with auto-scaling

### Lambda Scaling

- Memory allocation: 256MB for query processor, 1024MB for document processor
- Timeout: 30 seconds for query processor, 300 seconds for document processor
- Concurrency: Reserved concurrency for critical functions

### EKS Scaling

- Node groups: Auto-scaling based on CPU/memory utilization
- Pod resources: Requests and limits set for predictable performance
- Horizontal Pod Autoscaler: Scales document processing pods based on queue length

## Cost Optimization

### Serverless Components

- Lambda functions scale to zero when not in use
- API Gateway costs based on actual requests
- S3 costs based on actual storage and requests

### OpenSearch Optimization

- Instance right-sizing based on workload
- UltraWarm for less frequently accessed indices
- Index lifecycle management for data retention

### Bedrock Usage

- Caching common queries
- Optimizing prompt length
- Batch processing for document embedding

## Monitoring and Observability

### CloudWatch Metrics

- Lambda execution metrics
- API Gateway request metrics
- OpenSearch cluster metrics

### Logging

- Lambda function logs
- API Gateway access logs
- OpenSearch slow query logs

### Alerts

- Lambda error rate alerts
- API Gateway 5xx error alerts
- OpenSearch cluster health alerts

## Conclusion

This RAG architecture provides a scalable, secure, and cost-effective solution for enhancing LLM responses with retrieved information. By leveraging AWS Bedrock and a suite of AWS services, it delivers accurate, contextually relevant responses while maintaining control over the information sources used by the LLM.