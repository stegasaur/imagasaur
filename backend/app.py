from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
import boto3
import os
import uuid
from werkzeug.utils import secure_filename
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configure AWS
endpoint_url = os.getenv("AWS_ENDPOINT_URL", None)
s3_client = boto3.client('s3', endpoint_url=endpoint_url)
UPLOAD_BUCKET = os.environ.get('UPLOAD_BUCKET', 'imagasaur-uploads')
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET', 'imagasaur-processed')

# Allowed file extensions
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff', 'webp'}

def allowed_file(filename):
    """Check if the file extension is allowed."""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for load balancer."""
    return jsonify({'status': 'healthy'}), 200

@app.route('/upload', methods=['POST'])
def upload_image():
    """
    Handle image upload to S3.

    Expected form data:
    - file: The image file to upload

    Returns:
        JSON response with upload status and file information
    """
    try:
        # Check if file is present in request
        if 'file' not in request.files:
            return jsonify({
                'error': 'No file provided',
                'message': 'Please select a file to upload'
            }), 400

        file = request.files['file']

        # Check if file was selected
        if file.filename == '':
            return jsonify({
                'error': 'No file selected',
                'message': 'Please select a file to upload'
            }), 400

        # Check file extension
        if not allowed_file(file.filename):
            return jsonify({
                'error': 'Invalid file type',
                'message': f'Allowed file types: {", ".join(ALLOWED_EXTENSIONS)}'
            }), 400

        # Check file size (10MB limit)
        file.seek(0, 2)  # Seek to end
        file_size = file.tell()
        file.seek(0)  # Reset to beginning

        max_size = 10 * 1024 * 1024  # 10MB in bytes
        if file_size > max_size:
            return jsonify({
                'error': 'File too large',
                'message': 'File size must be less than 10MB'
            }), 400

        # Generate unique filename
        original_filename = secure_filename(file.filename)
        file_extension = original_filename.rsplit('.', 1)[1].lower()
        unique_filename = f"{uuid.uuid4()}.{file_extension}"
        s3_key = f"uploads/{unique_filename}"

        # Upload to S3
        s3_client.put_object(
            Bucket=UPLOAD_BUCKET,
            Key=s3_key,
            Body=file,
            ContentType=file.content_type,
            Metadata={
                'original-filename': original_filename,
                'file-size': str(file_size)
            }
        )

        logger.info(f"File uploaded successfully: {s3_key}")

        return jsonify({
            'success': True,
            'message': 'File uploaded successfully',
            'filename': original_filename,
            's3_key': s3_key,
            'file_size': file_size,
            'processing_status': 'pending'
        }), 200

    except Exception as e:
        logger.error(f"Error uploading file: {str(e)}")
        return jsonify({
            'error': 'Upload failed',
            'message': 'An error occurred while uploading the file'
        }), 500

@app.route('/images', methods=['GET'])
def list_images():
    """
    List all processed images from the processed bucket.

    Returns:
        JSON response with list of processed images
    """
    try:
        response = s3_client.list_objects_v2(
            Bucket=PROCESSED_BUCKET,
            Prefix='processed/'
        )

        images = []
        if 'Contents' in response:
            for obj in response['Contents']:
                if obj['Key'].endswith('_thumbnail.jpg'):
                    # Generate presigned URL for the image
                    presigned_url = s3_client.generate_presigned_url(
                        'get_object',
                        Params={'Bucket': PROCESSED_BUCKET, 'Key': obj['Key']},
                        ExpiresIn=3600  # 1 hour
                    )

                    images.append({
                        'key': obj['Key'],
                        'size': obj['Size'],
                        'last_modified': obj['LastModified'].isoformat(),
                        'url': presigned_url
                    })

        return jsonify({
            'success': True,
            'images': images,
            'count': len(images)
        }), 200

    except Exception as e:
        logger.error(f"Error listing images: {str(e)}")
        return jsonify({
            'error': 'Failed to list images',
            'message': 'An error occurred while retrieving images'
        }), 500

@app.route('/image/<path:image_key>', methods=['GET'])
def get_image(image_key):
    """
    Get a specific processed image by key.

    Args:
        image_key: The S3 key of the image

    Returns:
        JSON response with image information and presigned URL
    """
    try:
        # Generate presigned URL for the image
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': PROCESSED_BUCKET, 'Key': image_key},
            ExpiresIn=3600  # 1 hour
        )

        # Get object metadata
        response = s3_client.head_object(Bucket=PROCESSED_BUCKET, Key=image_key)

        return jsonify({
            'success': True,
            'key': image_key,
            'size': response['ContentLength'],
            'content_type': response['ContentType'],
            'last_modified': response['LastModified'].isoformat(),
            'url': presigned_url
        }), 200

    except Exception as e:
        logger.error(f"Error getting image {image_key}: {str(e)}")
        return jsonify({
            'error': 'Image not found',
            'message': 'The requested image could not be found'
        }), 404

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
