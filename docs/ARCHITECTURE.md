# Imagasaur Architecture

## Overview

Imagasaur is a serverless image processing application that automatically generates 100x100 pixel thumbnails from uploaded images. The application follows a microservices architecture pattern with clear separation of concerns.

## Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React App     │    │   API Gateway   │    │   Flask API     │
│   (Frontend)    │◄──►│   (AWS)         │◄──►│   (Backend)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudFront    │    │   S3 Uploads    │    │   Lambda        │
│   (CDN)         │    │   Bucket        │    │   (Processor)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   S3 Frontend   │    │   S3 Processed  │    │   S3 Processed  │
│   Bucket        │    │   Bucket        │    │   Bucket        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Frontend (React)
- **Technology**: React 18 with hooks
- **Hosting**: S3 + CloudFront
- **Features**:
  - Drag & drop file upload
  - Real-time upload progress
  - Image gallery with thumbnails
  - Error handling and user feedback
  - Responsive design

### 2. Backend API (Flask)
- **Technology**: Python Flask with CORS
- **Hosting**: AWS Lambda or ECS
- **Endpoints**:
  - `POST /upload` - Handle image uploads
  - `GET /images` - List processed images
  - `GET /image/<key>` - Get specific image
  - `GET /health` - Health check

### 3. Image Processing (Lambda)
- **Technology**: Python with Pillow
- **Trigger**: S3 uploads to `/uploads/` directory
- **Process**:
  1. Download image from S3
  2. Resize and crop to 100x100
  3. Convert to JPEG format
  4. Upload thumbnail to processed bucket

### 4. Storage (S3)
- **Uploads Bucket**: Stores original images
- **Processed Bucket**: Stores thumbnails
- **Frontend Bucket**: Hosts React app

### 5. Infrastructure (Terraform)
- **S3 Buckets**: With proper security policies
- **Lambda Function**: With IAM roles and permissions
- **API Gateway**: For backend API routing
- **CloudFront**: For frontend CDN
- **VPC**: For backend networking

## Data Flow

### Upload Process
1. User uploads image via React frontend
2. Frontend sends file to Flask API
3. API validates file (size, type) and uploads to S3
4. S3 triggers Lambda function
5. Lambda processes image and creates thumbnail
6. Thumbnail is stored in processed bucket
7. Frontend polls for completion and displays result

### Image Retrieval
1. Frontend requests list of processed images
2. API generates presigned URLs for S3 objects
3. Frontend displays thumbnails with metadata

## Security Considerations

### S3 Bucket Security
- Uploads and processed buckets are private
- Frontend bucket is public with proper CORS
- Bucket policies restrict access appropriately

### API Security
- CORS configured for frontend domain
- File type and size validation
- Secure filename handling

### Lambda Security
- IAM roles with minimal required permissions
- Environment variables for configuration
- Error handling and logging

## Scalability

### Horizontal Scaling
- Lambda functions scale automatically
- S3 handles unlimited storage
- CloudFront provides global CDN

### Performance
- Image processing is asynchronous
- Presigned URLs for direct S3 access
- CloudFront caching for static assets

## Monitoring and Logging

### CloudWatch Logs
- Lambda function execution logs
- API Gateway access logs
- Application-specific metrics

### Error Handling
- Comprehensive error responses
- User-friendly error messages
- Graceful degradation

## Development Workflow

### Local Development
1. Backend: Flask development server
2. Frontend: React development server
3. Docker: Complete containerized environment

### Deployment
1. Infrastructure: Terraform
2. Backend: Lambda or ECS
3. Frontend: S3 + CloudFront
4. CI/CD: Automated deployment pipeline

## Cost Optimization

### Lambda
- Pay only for execution time
- Automatic scaling based on demand

### S3
- Lifecycle policies for old images
- Intelligent tiering for cost savings

### CloudFront
- Global caching reduces origin requests
- Compression reduces bandwidth costs

## Future Enhancements

### Planned Features
- WebSocket notifications for real-time updates
- Image metadata extraction
- Batch processing capabilities
- User authentication and authorization
- Image optimization and compression

### Technical Improvements
- Multi-region deployment
- Advanced monitoring and alerting
- Automated testing and CI/CD
- Performance optimization
- Security hardening
