variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "imagasaur"
}

# S3 bucket for uploaded images
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-${var.environment}-uploads"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-uploads"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 bucket for processed thumbnails
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-${var.environment}-processed"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-processed"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 bucket for the frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-${var.environment}-frontend"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Enable versioning on the uploads bucket
resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable CORS on the uploads bucket
resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Block public access on all buckets
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Outputs
output "uploads_bucket_name" {
  value = aws_s3_bucket.uploads.id
}

output "processed_bucket_name" {
  value = aws_s3_bucket.processed.id
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.id
}

output "uploads_bucket_arn" {
  value = aws_s3_bucket.uploads.arn
}

output "processed_bucket_arn" {
  value = aws_s3_bucket.processed.arn
}

output "frontend_bucket_arn" {
  value = aws_s3_bucket.frontend.arn
}
