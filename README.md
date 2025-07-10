# Imagasaur - Image Processing Application

A serverless image processing application that allows users to upload images and automatically generates 100x100 pixel thumbnails.

## Architecture

- **Frontend**: React app served from S3 via CloudFront
- **Backend**: Python Flask API for handling image uploads
- **Processing**: Python Lambda function for image resizing
- **Storage**: S3 buckets for uploads and processed images
- **Infrastructure**: Terraform for AWS resource management

## Features

- Drag & drop image upload interface
- Support for common image formats (JPEG, PNG, GIF, etc.)
- 10MB file size limit
- Automatic 100x100 thumbnail generation
- Real-time error handling and user feedback
- Serverless architecture with AWS Lambda

## Project Structure

```
imagasaur/
├── frontend/           # React application
├── backend/           # Python Flask API
├── lambda/            # Image processing Lambda function
├── terraform/         # Infrastructure as Code
├── scripts/           # Deployment and utility scripts
└── docs/             # Documentation
```

## Quick Start

1. **Prerequisites**
   - AWS CLI configured
   - Terraform installed
   - Node.js and npm
   - Python 3.8+

2. **Deploy Infrastructure**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy Backend**
   ```bash
   cd backend
   pip install -r requirements.txt
   # Deploy to AWS Lambda/API Gateway
   ```

4. **Deploy Frontend**
   ```bash
   cd frontend
   npm install
   npm run build
   # Upload to S3 bucket
   ```

## Development

- Frontend development server: `npm start`
- Backend local development: `python app.py`
- Lambda testing: Use AWS SAM or direct invocation

## License

MIT License - see LICENSE file for details.
