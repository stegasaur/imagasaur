# Quick Start Guide

## Prerequisites

Before you begin, ensure you have the following installed:

- **Python 3.8+**
- **Node.js 16+**
- **npm** (comes with Node.js)
- **AWS CLI** (for deployment)
- **Terraform** (for infrastructure)
- **Docker** (optional, for containerized development)

## Option 1: Local Development (Recommended for first-time setup)

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd imagasaur

# Run the development setup script
./scripts/dev-setup.sh
```

### 2. Configure AWS Credentials

```bash
# Configure your AWS credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1
```

### 3. Start the Backend

```bash
cd backend
source venv/bin/activate  # On Windows: venv\Scripts\activate
python app.py
```

The backend will be available at `http://localhost:5000`

### 4. Start the Frontend

In a new terminal:

```bash
cd frontend
npm start
```

The frontend will be available at `http://localhost:3000`

### 5. Test the Application

1. Open your browser to `http://localhost:3000`
2. Upload an image using the drag & drop interface
3. Watch the upload progress and processing status
4. View the generated thumbnail in the gallery

## Option 2: Docker Development

### 1. Start with Docker Compose

```bash
# Build and start all services
docker-compose up --build

# Or run in background
docker-compose up -d --build
```

### 2. Access the Application

- Frontend: `http://localhost:3000`
- Backend: `http://localhost:5000`

## Option 3: Full AWS Deployment

### 1. Deploy Infrastructure

```bash
# Deploy all AWS resources
./scripts/deploy.sh
```

### 2. Configure Environment Variables

Update the frontend environment variables with your API URL:

```bash
# In frontend/.env
REACT_APP_API_URL=https://your-api-gateway-url.amazonaws.com/prod
```

### 3. Deploy Frontend

```bash
cd frontend
npm run build
aws s3 sync build/ s3://your-frontend-bucket-name
```

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Not Found
```bash
# Ensure AWS credentials are configured
aws sts get-caller-identity
```

#### 2. Python Dependencies Issues
```bash
# Recreate virtual environment
cd backend
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

#### 3. Node.js Dependencies Issues
```bash
# Clear npm cache and reinstall
cd frontend
rm -rf node_modules package-lock.json
npm install
```

#### 4. Docker Issues
```bash
# Rebuild Docker images
docker-compose down
docker-compose build --no-cache
docker-compose up
```

### Development Tips

1. **Backend Development**:
   - Use Flask debug mode for auto-reload
   - Check logs for detailed error messages
   - Use Postman or curl to test API endpoints

2. **Frontend Development**:
   - React dev tools for debugging
   - Browser dev tools for network requests
   - Hot reload for instant feedback

3. **AWS Development**:
   - Use AWS CloudWatch for Lambda logs
   - S3 console for bucket inspection
   - CloudFront for CDN management

## API Endpoints

### Backend API (Flask)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/upload` | Upload an image file |
| GET | `/images` | List all processed images |
| GET | `/image/<key>` | Get specific image details |
| GET | `/health` | Health check endpoint |

### Example API Usage

```bash
# Upload an image
curl -X POST -F "file=@image.jpg" http://localhost:5000/upload

# List images
curl http://localhost:5000/images

# Get specific image
curl http://localhost:5000/image/processed/example_thumbnail.jpg
```

## Environment Variables

### Backend (.env)
```bash
FLASK_ENV=development
FLASK_DEBUG=1
UPLOAD_BUCKET=your-uploads-bucket
PROCESSED_BUCKET=your-processed-bucket
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
```

### Frontend (.env)
```bash
REACT_APP_API_URL=http://localhost:5000
```

## Next Steps

1. **Customize the Application**:
   - Modify the thumbnail size in `lambda/lambda_function.py`
   - Update the UI styling in `frontend/src/App.css`
   - Add new API endpoints in `backend/app.py`

2. **Add Features**:
   - Implement user authentication
   - Add image metadata extraction
   - Create batch processing capabilities

3. **Production Deployment**:
   - Set up CI/CD pipeline
   - Configure monitoring and alerting
   - Implement backup and disaster recovery

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the architecture documentation
3. Check AWS CloudWatch logs for errors
4. Open an issue in the repository
