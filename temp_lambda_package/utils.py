import json
import os
import boto3
import re

# Initialize Bedrock client
bedrock_runtime = boto3.client(
    service_name='bedrock-runtime',
    region_name='ap-southeast-2'
)

def get_embeddings(text, model_id='amazon.titan-embed-text-v1'):
    """
    Generate embeddings for the given text using Amazon Bedrock
    
    Args:
        text (str): The text to embed
        model_id (str): The Bedrock model ID to use for embeddings
        
    Returns:
        list: The embedding vector
    """
    # Truncate text if it's too long (model dependent)
    max_length = 8000  # Titan Embeddings limit
    if len(text) > max_length:
        text = text[:max_length]
    
    try:
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=json.dumps({
                "inputText": text
            })
        )
        
        response_body = json.loads(response['body'].read())
        
        # Extract embeddings based on model
        if model_id.startswith('amazon.titan-embed'):
            return response_body.get('embedding', [])
        else:
            # Generic fallback
            return response_body.get('embedding', [])
            
    except Exception as e:
        print(f"Error generating embeddings: {str(e)}")
        raise

def chunk_text(text, chunk_size=1000, overlap=100):
    """
    Split text into overlapping chunks of approximately equal size
    
    Args:
        text (str): The text to split
        chunk_size (int): Target size of each chunk in characters
        overlap (int): Number of characters to overlap between chunks
        
    Returns:
        list: List of text chunks
    """
    if not text:
        return []
        
    # Clean the text
    text = re.sub(r'\s+', ' ', text).strip()
    
    # If text is shorter than chunk_size, return it as a single chunk
    if len(text) <= chunk_size:
        return [text]
    
    chunks = []
    start = 0
    
    while start < len(text):
        # Find the end of the chunk
        end = start + chunk_size
        
        # If we're at the end of the text, just use the rest
        if end >= len(text):
            chunks.append(text[start:])
            break
            
        # Try to find a good breaking point (end of sentence)
        # Look for period, question mark, or exclamation mark followed by space
        last_period = text.rfind('. ', start, end)
        last_question = text.rfind('? ', start, end)
        last_exclamation = text.rfind('! ', start, end)
        
        # Find the latest sentence break
        break_point = max(last_period, last_question, last_exclamation)
        
        # If no good breaking point, just break at the chunk size
        if break_point < start:
            chunks.append(text[start:end])
            start = end - overlap
        else:
            # Add 2 to include the punctuation and space
            chunks.append(text[start:break_point + 2])
            start = break_point + 2 - overlap
    
    return chunks

def create_opensearch_index(endpoint, username, password, index_name='documents'):
    """
    Create an OpenSearch index with appropriate mappings for vector search
    
    Args:
        endpoint (str): OpenSearch endpoint
        username (str): OpenSearch username
        password (str): OpenSearch password
        index_name (str): Name of the index to create
    """
    url = f"https://{endpoint}/{index_name}"
    
    # Check if index exists
    response = requests.head(
        url,
        auth=HTTPBasicAuth(username, password)
    )
    
    # If index exists, return
    if response.status_code == 200:
        print(f"Index {index_name} already exists")
        return
    
    # Create index with mappings
    mappings = {
        "mappings": {
            "properties": {
                "document_id": {"type": "keyword"},
                "chunk_id": {"type": "integer"},
                "text": {"type": "text"},
                "embedding": {
                    "type": "knn_vector",
                    "dimension": 1536  # Titan Text Embeddings V2 dimension
                },
                "metadata": {
                    "properties": {
                        "title": {"type": "text"},
                        "source": {"type": "keyword"},
                        "content_type": {"type": "keyword"},
                        "size": {"type": "long"},
                        "last_modified": {"type": "date"}
                    }
                }
            }
        },
        "settings": {
            "index": {
                "knn": True,
                "knn.algo_param.ef_search": 100
            }
        }
    }
    
    response = requests.put(
        url,
        auth=HTTPBasicAuth(username, password),
        json=mappings,
        headers={"Content-Type": "application/json"}
    )
    
    if response.status_code not in (200, 201):
        raise Exception(f"Failed to create index: {response.text}")
    
    print(f"Created index {index_name}")
    return response.json()