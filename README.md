# Imagasaur - Image Processing Application

A serverless image processing application that allows users to upload images and automatically generates 100x100 pixel thumbnails.

## Architecture

- **Frontend**: React app served from S3 via CloudFront
- **Backend**: Python Flask API for handling image uploads
- **Processing**: Python Lambda function for image resizing
- **Storage**: S3 buckets for uploads and processed images
- **Infrastructure**: Terraform for AWS resource management
- **Local AWS Emulation**: LocalStack for S3 and Lambda testing

## Features

- Drag & drop image upload interface
- Support for common image formats (JPEG, PNG, GIF, etc.)
- 10MB file size limit
- Automatic 100x100 thumbnail generation
- Real-time error handling and user feedback
- Serverless architecture with AWS Lambda
- Local Lambda/S3 testing with Docker Compose + LocalStack

## Project Structure

```
imagasaur/
├── frontend/           # React application
├── backend/           # Python Flask API
├── lambda/            # Image processing Lambda function
├── terraform/         # Infrastructure as Code
├── scripts/           # Deployment and utility scripts
├── docs/             # Documentation
└── docker-compose.dev.yml # Local development and Lambda testing
```

## Local Lambda Testing with LocalStack

You can test the Lambda function locally, triggered by S3 events, using Docker Compose and LocalStack.

### 1. Start All Services

```bash
docker-compose -f docker-compose.dev.yml up --build
```

This will start:
- The Flask backend
- The React frontend
- LocalStack (emulating AWS S3 and Lambda)
- The Lambda function container

### 2. Set Up LocalStack (Buckets, Lambda, S3 Trigger)

In a new terminal:

```bash
./scripts/localstack-setup.sh
```

This will:
- Create S3 buckets (`imagasaur-uploads`, `imagasaur-processed`)
- Deploy the Lambda function to LocalStack
- Set up the S3 event notification to trigger the Lambda

### 3. Test the Lambda

Upload an image to the S3 bucket (using the AWS CLI with LocalStack):

```bash
awslocal s3 cp test.jpg s3://imagasaur-uploads/uploads/test.jpg
```

The Lambda will be triggered, process the image, and write the thumbnail to `imagasaur-processed`.

### 4. Inspect Results

List the processed images:

```bash
awslocal s3 ls s3://imagasaur-processed/processed/
```

You should see the generated thumbnail.

---

## Quick Start (Full App)

1. **Prerequisites**
   - AWS CLI configured
   - Terraform installed
   - Node.js and npm
   - Python 3.8+
   - Docker
   - LocalStack (via Docker Compose)

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

5. **Local Development**
   ```bash
   docker-compose -f docker-compose.dev.yml up --build
   # Or run backend/frontend directly for SSO
   ```

---

## Local Lambda Testing Architecture

```
[Frontend] <-> [Backend] <-> [LocalStack S3] <-> [LocalStack Lambda]
```

- Uploads to S3 (LocalStack) trigger the Lambda (in Docker) for local, production-like testing.

---

## License

MIT License - see LICENSE file for details.
