import json
import os
import boto3
import uuid
import requests
from requests.auth import HTTPBasicAuth
from utils import get_embeddings, chunk_text

# Environment variables
OPENSEARCH_ENDPOINT = os.environ.get('OPENSEARCH_ENDPOINT')
OPENSEARCH_USERNAME = os.environ.get('OPENSEARCH_USERNAME')
OPENSEARCH_PASSWORD = os.environ.get('OPENSEARCH_PASSWORD')
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'amazon.titan-embed-text-v1')
DOCUMENT_BUCKET = os.environ.get('DOCUMENT_BUCKET')

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
document_table = dynamodb.Table('rag-document-metadata')

def lambda_handler(event, context):
    """
    Process documents uploaded to S3:
    1. Extract document content
    2. Chunk the document
    3. Generate embeddings for each chunk
    4. Store embeddings in OpenSearch
    5. Store metadata in DynamoDB
    """
    try:
        # Process S3 event
        for record in event.get('Records', []):
            if record.get('eventSource') != 'aws:s3':
                continue
                
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            # Process the document
            process_document(bucket, key)
            
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Document processing completed successfully'})
        }
        
    except Exception as e:
        print(f"Error processing document: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Error processing document: {str(e)}'})
        }

def process_document(bucket, key):
    """Process a document from S3"""
    # Download the document from S3
    response = s3_client.get_object(Bucket=bucket, Key=key)
    content_type = response.get('ContentType', '')
    
    # Extract text based on content type
    if content_type.startswith('text/'):
        text = response['Body'].read().decode('utf-8')
    elif content_type == 'application/pdf':
        # For PDF, we would use a library like PyPDF2 or pdfplumber
        # This is a simplified example
        text = extract_text_from_pdf(response['Body'].read())
    elif content_type.startswith('application/') and ('word' in content_type or 'doc' in content_type):
        # For Word documents
        text = extract_text_from_doc(response['Body'].read())
    else:
        raise ValueError(f"Unsupported content type: {content_type}")
    
    # Generate document ID
    document_id = str(uuid.uuid4())
    
    # Store document metadata
    metadata = {
        'document_id': document_id,
        'title': os.path.basename(key),
        'source': key,
        'content_type': content_type,
        'size': response.get('ContentLength', 0),
        'last_modified': response.get('LastModified', '').isoformat() if response.get('LastModified') else None
    }
    
    document_table.put_item(Item=metadata)
    
    # Chunk the document
    chunks = chunk_text(text)
    
    # Process each chunk
    for i, chunk in enumerate(chunks):
        # Generate embedding for the chunk
        embedding = get_embeddings(chunk)
        
        # Store in OpenSearch
        store_in_opensearch(document_id, chunk, embedding, metadata, chunk_id=i)
    
    print(f"Processed document {key} with {len(chunks)} chunks")

def extract_text_from_pdf(pdf_bytes):
    """Extract text from PDF document"""
    # This is a placeholder. In a real implementation, you would use a library like PyPDF2
    return "PDF text extraction placeholder"

def extract_text_from_doc(doc_bytes):
    """Extract text from Word document"""
    # This is a placeholder. In a real implementation, you would use a library like python-docx
    return "Word document text extraction placeholder"

def store_in_opensearch(document_id, text, embedding, metadata, chunk_id=0):
    """Store document chunk and its embedding in OpenSearch"""
    url = f"https://{OPENSEARCH_ENDPOINT}/documents/_doc/{document_id}_{chunk_id}"
    
    # Prepare document
    document = {
        "document_id": document_id,
        "chunk_id": chunk_id,
        "text": text,
        "embedding": embedding,
        "metadata": metadata
    }
    
    # Store in OpenSearch
    response = requests.put(
        url,
        auth=HTTPBasicAuth(OPENSEARCH_USERNAME, OPENSEARCH_PASSWORD),
        json=document,
        headers={"Content-Type": "application/json"}
    )
    
    if response.status_code not in (200, 201):
        raise Exception(f"Failed to store document in OpenSearch: {response.text}")
    
    return response.json()