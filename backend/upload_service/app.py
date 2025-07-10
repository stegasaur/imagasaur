import os
import json
import boto3
import logging
from io import BytesIO
from datetime import datetime
from urllib.parse import parse_qs

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize S3 client
s3_client = boto3.client('s3')

# Environment variables
UPLOADS_BUCKET = os.environ.get('UPLOADS_BUCKET')
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')


def generate_presigned_url(bucket_name, object_name, expiration=3600):
    """Generate a presigned URL for an S3 object."""
    try:
        response = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': bucket_name,
                'Key': object_name
            },
            ExpiresIn=expiration
        )
        return response
    except Exception as e:
        logger.error(f"Error generating presigned URL: {str(e)}")
        return None


def lambda_handler(event, context):
    """
    Handle file uploads to S3.
    Expected event format (API Gateway HTTP API v2.0):
    {
        "routeKey": "POST /upload",
        "rawPath": "/upload",
        "body": "<base64-encoded-file>",
        "headers": {
            "content-type": "multipart/form-data; boundary=...",
            "content-length": "..."
        },
        "isBase64Encoded": true
    }
    """
    try:
        # Log the incoming event for debugging
        logger.info(f"Received event: {json.dumps(event, default=str)}")
        
        # Check if the request is base64 encoded
        is_base64_encoded = event.get('isBase64Encoded', False)
        
        # Get the request body
        body = event.get('body', '')
        if is_base64_encoded:
            import base64
            body = base64.b64decode(body).decode('utf-8')
        
        # Parse the content type to get the boundary
        content_type = event.get('headers', {}).get('content-type', '')
        if not content_type or 'multipart/form-data' not in content_type:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Content-Type must be multipart/form-data'}),
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                }
            }
        
        # Extract the boundary from the content type
        boundary = content_type.split('boundary=')[1]
        
        # Parse the multipart form data
        from email.parser import BytesParser
        from email import policy
        
        # Reconstruct the multipart form data
        content_type_header = f"Content-Type: {content_type}"
        content_length = event.get('headers', {}).get('content-length', '0')
        headers = f"{content_type_header}\r\nContent-Length: {content_length}\r\n\r\n"
        
        # Parse the multipart form data
        if is_base64_encoded:
            body_bytes = base64.b64decode(event['body'])
        else:
            body_bytes = event['body'].encode('utf-8')
        
        # Parse the multipart form data
        msg = BytesParser(policy=policy.default).parsebytes(
            b"\r\n".join([
                b"MIME-Version: 1.0",
                content_type_header.encode('utf-8'),
                b"",
                body_bytes
            ])
        )
        
        # Extract the file from the form data
        if not msg.is_multipart():
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No file part in the request'}),
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                }
            }
        
        file_part = None
        for part in msg.iter_parts():
            if part.get_content_disposition() == 'form-data' and part.get_filename():
                file_part = part
                break
        
        if not file_part:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No file part in the request'}),
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                }
            }
        
        # Get the file data
        file_data = file_part.get_content()
        file_name = file_part.get_filename()
        
        # Generate a unique key for the S3 object
        timestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S')
        file_extension = os.path.splitext(file_name)[1].lower()
        s3_key = f"uploads/{timestamp}_{file_name}"
        
        # Upload the file to S3
        s3_client.put_object(
            Bucket=UPLOADS_BUCKET,
            Key=s3_key,
            Body=file_data,
            ContentType=file_part.get_content_type(),
            Metadata={
                'original-filename': file_name,
                'upload-timestamp': timestamp
            }
        )
        
        # Generate presigned URLs for the uploaded file and the future thumbnail
        file_url = generate_presigned_url(UPLOADS_BUCKET, s3_key)
        thumbnail_key = f"processed/{os.path.splitext(s3_key)[0]}_thumbnail.jpg"
        thumbnail_url = generate_presigned_url(PROCESSED_BUCKET, thumbnail_key)
        
        # Return the response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File uploaded successfully',
                'file_key': s3_key,
                'file_url': file_url,
                'thumbnail_key': thumbnail_key,
                'thumbnail_url': thumbnail_url,
                'status': 'processing'
            }),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        }
    
    except Exception as e:
        logger.error(f"Error processing upload: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to process upload',
                'details': str(e)
            }),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        }
