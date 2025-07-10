import os
import json
import boto3
import logging
from io import BytesIO
from datetime import datetime
from urllib.parse import unquote_plus
from PIL import Image, ImageOps

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize S3 client
s3_client = boto3.client('s3')

# Environment variables
UPLOADS_BUCKET = os.environ.get('UPLOADS_BUCKET')
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')
THUMBNAIL_SIZE = (100, 100)  # Target thumbnail size (width, height)

def create_thumbnail(image_data):
    """
    Create a thumbnail from the given image data.
    
    Args:
        image_data: Binary data of the uploaded image
        
    Returns:
        BytesIO: Thumbnail image data
    """
    try:
        # Open the image
        image = Image.open(BytesIO(image_data))
        
        # Convert to RGB if necessary (for PNG with transparency)
        if image.mode in ('RGBA', 'LA') or (image.mode == 'P' and 'transparency' in image.info):
            # Create a white background
            background = Image.new('RGB', image.size, (255, 255, 255))
            # Paste the image on the background
            background.paste(image, mask=image.split()[-1])
            image = background
        
        # Create thumbnail (this modifies the image in place)
        image.thumbnail(THUMBNAIL_SIZE, Image.Resampling.LANCZOS)
        
        # Create a new image with white background
        thumbnail = Image.new('RGB', THUMBNAIL_SIZE, (255, 255, 255))
        
        # Calculate position to center the thumbnail
        x = (THUMBNAIL_SIZE[0] - image.size[0]) // 2
        y = (THUMBNAIL_SIZE[1] - image.size[1]) // 2
        
        # Paste the thumbnail onto the white background
        thumbnail.paste(image, (x, y))
        
        # Save the thumbnail to a bytes buffer
        buffer = BytesIO()
        thumbnail.save(buffer, 'JPEG', quality=85)
        buffer.seek(0)
        
        return buffer
    
    except Exception as e:
        logger.error(f"Error creating thumbnail: {str(e)}")
        raise

def lambda_handler(event, context):
    """
    Process uploaded images and generate thumbnails.
    
    This function is triggered by S3 upload events.
    """
    try:
        # Log the incoming event for debugging
        logger.info(f"Received event: {json.dumps(event, default=str)}")
        
        # Process each record in the S3 event
        for record in event.get('Records', []):
            # Skip if this is not an S3 event
            if 's3' not in record:
                logger.warning("Not an S3 event, skipping...")
                continue
            
            # Get the bucket and key from the S3 event
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])
            
            # Skip if this is not an upload to the uploads directory
            if not key.startswith('uploads/'):
                logger.info(f"Skipping non-upload file: {key}")
                continue
            
            try:
                # Get the uploaded file from S3
                response = s3_client.get_object(Bucket=bucket, Key=key)
                content_type = response.get('ContentType', '')
                
                # Check if the file is an image
                if not content_type.startswith('image/'):
                    logger.info(f"Skipping non-image file: {key} ({content_type})")
                    continue
                
                # Read the image data
                image_data = response['Body'].read()
                
                # Generate the thumbnail
                thumbnail_buffer = create_thumbnail(image_data)
                
                # Generate the output key for the thumbnail
                base_name = os.path.splitext(os.path.basename(key))[0]
                thumbnail_key = f"processed/{base_name}_thumbnail.jpg"
                
                # Upload the thumbnail to the processed bucket
                s3_client.put_object(
                    Bucket=PROCESSED_BUCKET,
                    Key=thumbnail_key,
                    Body=thumbnail_buffer,
                    ContentType='image/jpeg',
                    Metadata={
                        'original-file': key,
                        'processed-timestamp': datetime.utcnow().isoformat()
                    }
                )
                
                logger.info(f"Successfully processed {key} -> {thumbnail_key}")
                
            except Exception as e:
                logger.error(f"Error processing {key}: {str(e)}")
                # Continue processing other files even if one fails
                continue
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Processing completed'})
        }
    
    except Exception as e:
        logger.error(f"Error in processing lambda: {str(e)}")
        raise
