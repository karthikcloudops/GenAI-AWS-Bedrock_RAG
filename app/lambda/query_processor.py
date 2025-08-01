import json
import os
import boto3
import requests
from requests.auth import HTTPBasicAuth
from utils import get_embeddings, chunk_text

# Environment variables
OPENSEARCH_ENDPOINT = os.environ.get('OPENSEARCH_ENDPOINT')
OPENSEARCH_USERNAME = os.environ.get('OPENSEARCH_USERNAME')
OPENSEARCH_PASSWORD = os.environ.get('OPENSEARCH_PASSWORD')
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-v2')

# Initialize Bedrock client
bedrock_runtime = boto3.client(
    service_name='bedrock-runtime',
    region_name='ap-southeast-2'
)

def lambda_handler(event, context):
    """
    Process RAG queries:
    1. Extract query from request
    2. Generate embeddings for the query
    3. Search OpenSearch for similar documents
    4. Generate response using Bedrock with retrieved context
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        query = body.get('query')
        
        if not query:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Query parameter is required'})
            }
        
        # Generate embeddings for the query
        query_embedding = get_embeddings(query)
        
        # Search OpenSearch for similar documents
        relevant_docs = search_opensearch(query_embedding)
        
        # Extract context from relevant documents
        context = extract_context(relevant_docs)
        
        # Generate response using Bedrock
        response = generate_response(query, context)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'query': query,
                'response': response,
                'sources': [doc['_source']['metadata'] for doc in relevant_docs['hits']['hits']]
            })
        }
        
    except Exception as e:
        print(f"Error processing query: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Error processing query: {str(e)}'})
        }

def search_opensearch(query_embedding, top_k=5):
    """Search OpenSearch for documents similar to the query embedding"""
    url = f"https://{OPENSEARCH_ENDPOINT}/documents/_search"
    
    # Vector search query
    query = {
        "size": top_k,
        "query": {
            "knn": {
                "embedding": {
                    "vector": query_embedding,
                    "k": top_k
                }
            }
        }
    }
    
    # Execute search
    response = requests.post(
        url,
        auth=HTTPBasicAuth(OPENSEARCH_USERNAME, OPENSEARCH_PASSWORD),
        json=query,
        headers={"Content-Type": "application/json"}
    )
    
    if response.status_code != 200:
        raise Exception(f"OpenSearch query failed: {response.text}")
    
    return response.json()

def extract_context(search_results, max_context_length=4000):
    """Extract context from search results"""
    context = ""
    
    for hit in search_results['hits']['hits']:
        source = hit['_source']
        text = source.get('text', '')
        metadata = source.get('metadata', {})
        
        # Add document info and content to context
        doc_context = f"\nSource: {metadata.get('title', 'Unknown')}\n"
        doc_context += f"Path: {metadata.get('source', 'Unknown')}\n"
        doc_context += f"Content: {text}\n"
        
        # Check if adding this document would exceed max context length
        if len(context) + len(doc_context) <= max_context_length:
            context += doc_context
        else:
            break
    
    return context

def generate_response(query, context):
    """Generate a response using Bedrock with the retrieved context"""
    if BEDROCK_MODEL_ID.startswith('anthropic.claude'):
        prompt = f"""
        Human: You are a helpful assistant that answers questions based only on the provided context.
        If you don't know the answer based on the context, say "I don't have enough information to answer this question."
        Do not make up information or use your training data to answer.
        
        Context:
        {context}
        
        Question: {query}
        
        Assistant:
        """
        
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=json.dumps({
                "prompt": prompt,
                "max_tokens_to_sample": 1000,
                "temperature": 0.1,
                "top_p": 0.9,
            })
        )
        
        response_body = json.loads(response['body'].read())
        return response_body.get('completion', '')
    
    else:
        # Generic format for other models
        prompt = f"Context: {context}\n\nQuestion: {query}\n\nAnswer:"
        
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=json.dumps({
                "inputText": prompt,
                "textGenerationConfig": {
                    "maxTokenCount": 1000,
                    "temperature": 0.1,
                    "topP": 0.9
                }
            })
        )
        
        response_body = json.loads(response['body'].read())
        return response_body.get('results', [{}])[0].get('outputText', '')