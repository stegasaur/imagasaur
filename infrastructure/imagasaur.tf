# S3 Module
module "s3" {
  source = "./modules/s3"
  
  environment = var.environment
  project_name = var.project_name
}

# Lambda Module
module "lambda" {
  source = "./modules/lambda"
  
  environment = var.environment
  project_name = var.project_name
  region = var.region
  uploads_bucket_arn = module.s3.uploads_bucket_arn
  processed_bucket_arn = module.s3.processed_bucket_arn
}

# Upload Lambda Function
resource "aws_lambda_function" "upload_function" {
  function_name = "${var.project_name}-${var.environment}-upload"
  role          = module.lambda.lambda_execution_role_arn
  handler       = "app.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  
  # The deployment package will be created and uploaded separately
  filename         = "${path.module}/../backend/upload_service/function.zip"
  source_code_hash = fileexists("${path.module}/../backend/upload_service/function.zip") ? filebase64sha256("${path.module}/../backend/upload_service/function.zip") : null
  
  environment {
    variables = {
      UPLOADS_BUCKET = module.s3.uploads_bucket_name
      PROCESSED_BUCKET = module.s3.processed_bucket_name
      ENVIRONMENT = var.environment
    }
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-upload"
    }
  )
}

# Processing Lambda Function (triggered by S3 uploads)
resource "aws_lambda_function" "processing_function" {
  function_name = "${var.project_name}-${var.environment}-processing"
  role          = module.lambda.lambda_execution_role_arn
  handler       = "app.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  
  # The deployment package will be created and uploaded separately
  filename         = "${path.module}/../backend/processing_service/function.zip"
  source_code_hash = fileexists("${path.module}/../backend/processing_service/function.zip") ? filebase64sha256("${path.module}/../backend/processing_service/function.zip") : null
  
  environment {
    variables = {
      UPLOADS_BUCKET = module.s3.uploads_bucket_name
      PROCESSED_BUCKET = module.s3.processed_bucket_name
      ENVIRONMENT = var.environment
    }
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-processing"
    }
  )
}

# S3 Event Notification for Processing Lambda
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processing_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3.uploads_bucket_arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.s3.uploads_bucket_name
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.processing_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }
  
  depends_on = [aws_lambda_permission.allow_bucket]
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api_gateway"
  
  environment = var.environment
  project_name = var.project_name
  lambda_invoke_arn = aws_lambda_function.upload_function.invoke_arn
  lambda_function_name = aws_lambda_function.upload_function.function_name
}

# CloudFront Distribution for the frontend
module "cloudfront" {
  source = "./modules/cloudfront"
  
  environment = var.environment
  project_name = var.project_name
  frontend_bucket_name = module.s3.frontend_bucket_name
  
  # This would be the domain name for your API Gateway
  api_gateway_domain = replace(module.api_gateway.api_gateway_url, "https://", "")
}
