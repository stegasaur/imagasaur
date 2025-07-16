"""
AWS Lambda function for image processing and thumbnail generation.

This module handles S3 events triggered by image uploads, processes the images
to create 100x100 thumbnails, and stores them in a processed bucket.
"""

import os
import json
import io
from urllib.parse import unquote_plus

import boto3
from PIL import Image

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function to process uploaded images and create thumbnails.

    Args:
        event: S3 event containing information about the uploaded file
        context: Lambda context

    Returns:
        dict: Response with status and message
    """
    try:
        # Get the bucket and key from the S3 event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = unquote_plus(event['Records'][0]['s3']['object']['key'])

        # Only process files in the uploads directory
        if not key.startswith('uploads/'):
            print(f"Skipping file {key} - not in uploads directory")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'File not in uploads directory'})
            }

        # Get the processed bucket name from environment variable
        processed_bucket = os.environ['PROCESSED_BUCKET']

        print(f"Processing image: {key} from bucket: {bucket}")

        # Download the image from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        image_data = response['Body'].read()

        # Open the image using PIL
        image = Image.open(io.BytesIO(image_data))

        # Convert to RGB if necessary (for PNG with transparency)
        if image.mode in ('RGBA', 'LA', 'P'):
            # Create a white background
            background = Image.new('RGB', image.size, (255, 255, 255))
            if image.mode == 'P':
                image = image.convert('RGBA')
            background.paste(image, mask=image.split()[-1] if image.mode == 'RGBA' else None)
            image = background
        elif image.mode != 'RGB':
            image = image.convert('RGB')

        # Resize and crop to 100x100
        # Calculate the center crop
        width, height = image.size
        size = min(width, height)

        # Calculate the crop box (center crop)
        left = (width - size) // 2
        top = (height - size) // 2
        right = left + size
        bottom = top + size

        # Crop to square
        image = image.crop((left, top, right, bottom))

        # Resize to 100x100
        thumbnail = image.resize((100, 100), Image.Resampling.LANCZOS)

        # Convert to bytes
        output_buffer = io.BytesIO()
        thumbnail.save(output_buffer, format='JPEG', quality=85, optimize=True)
        output_buffer.seek(0)

        # Generate the new key for the processed image
        filename = os.path.basename(key)
        name, ext = os.path.splitext(filename)
        new_key = f"processed/{name}_thumbnail.jpg"

        # Upload the thumbnail to the processed bucket
        s3_client.put_object(
            Bucket=processed_bucket,
            Key=new_key,
            Body=output_buffer.getvalue(),
            ContentType='image/jpeg',
            CacheControl='public, max-age=31536000'  # Cache for 1 year
        )

        print(f"Successfully created thumbnail: {new_key}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Thumbnail created successfully',
                'original_key': key,
                'thumbnail_key': new_key,
                'thumbnail_url': f"s3://{processed_bucket}/{new_key}"
            })
        }

    except Exception as e:
        print(f"Error processing image: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to process image',
                'message': str(e)
            })
        }
