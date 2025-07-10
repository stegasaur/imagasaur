# Imagasaur

A serverless image processing application that allows users to upload images and automatically generate thumbnails.

## Features

- Upload images through a web interface
- Automatic 100x100 thumbnail generation
- Serverless architecture using AWS Lambda, S3, and API Gateway
- Responsive frontend served via CloudFront

## Architecture

![Architecture Diagram](docs/architecture.png)

1. **Frontend**: React application served from S3 through CloudFront
2. **API Gateway**: Handles HTTP requests from the frontend
3. **Upload Lambda**: Processes file uploads and saves them to S3
4. **Processing Lambda**: Triggered by S3 upload events to generate thumbnails
5. **S3 Buckets**:
   - `uploads`: Stores original uploaded images
   - `processed`: Stores generated thumbnails
   - `frontend`: Hosts the static website

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Terraform (>= 1.0.0)
- Python 3.8+
- Node.js 16+ (for frontend development)

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/imagasaur.git
   cd imagasaur
   ```

2. Install dependencies:
   ```bash
   # Backend dependencies
   cd backend/upload_service
   pip install -r requirements.txt
   
   cd ../processing_service
   pip install -r requirements.txt
   
   # Frontend dependencies
   cd ../../frontend
   npm install
   ```

## Deployment

1. Make the deployment script executable:
   ```bash
   chmod +x deploy.sh
   ```

2. Run the deployment script:
   ```bash
   ./deploy.sh --environment dev --region us-west-2
   ```

   This will:
   - Package the Lambda functions
   - Deploy the infrastructure using Terraform
   - Output the CloudFront URL for the frontend

## Local Development

### Prerequisites

- Node.js 16+ and npm
- Python 3.8+
- AWS CLI configured with appropriate credentials

### Starting the Development Environment

We've provided a script to start both the frontend and backend services with a single command:

```bash
# Make the script executable
chmod +x scripts/start-dev.sh

# Start the development environment
./scripts/start-dev.sh
```

This will:
1. Set up a Python virtual environment
2. Install backend dependencies
3. Start the local backend server on port 3000
4. Install frontend dependencies
5. Start the React development server

The frontend will be available at http://localhost:3001

### Manual Setup (Alternative)

#### Backend

1. Set up the Python virtual environment:
   ```bash
   cd backend/upload_service
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt uvicorn
   ```

2. Set up environment variables:
   ```bash
   export UPLOADS_BUCKET=local-uploads
   export PROCESSED_BUCKET=local-processed
   export ENVIRONMENT=development
   ```

3. Start the local server:
   ```bash
   uvicorn app:app --reload --host 0.0.0.0 --port 3000
   ```

#### Frontend

1. Install dependencies:
   ```bash
   cd frontend
   npm install
   ```

2. Start the development server:
   ```bash
   REACT_APP_API_URL=http://localhost:3000 npm start
   ```

### Testing File Uploads

1. Open http://localhost:3001 in your browser
2. Drag and drop an image file or click to select one
3. The file will be uploaded and you should see the thumbnail appear once processing is complete

### Debugging

- Check the browser's developer console for frontend errors
- The backend server logs will show API requests and any errors
- Uploaded files are stored in `.local-storage/` directory

## API Endpoints

- `POST /upload`: Upload a new image
  - Content-Type: multipart/form-data
  - Body: Form data with 'file' field containing the image

## Cleanup

To destroy all resources created by Terraform:

```bash
cd infrastructure
terraform destroy -var="environment=dev" -var="region=us-west-2" -var="project_name=imagasaur"
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.