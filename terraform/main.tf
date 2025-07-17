terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

locals {
  environment = terraform.workspace
}

# S3 Bucket for uploads
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-uploads-${local.environment}-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket for processed images
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-processed-${local.environment}-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.uploads.arn}/uploads/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.processed.arn}/processed/*"
      }
    ]
  })
}

# ecr repository for lambda
resource "aws_ecr_repository" "lambda" {
  name = "${var.project_name}-image-processor"
}

# Lambda function for image processing
resource "aws_lambda_function" "image_processor" {
  image_uri = "${aws_ecr_repository.lambda.repository_url}:latest"
  package_type = "Image"
  function_name = "${var.project_name}-image-processor"
  role = aws_iam_role.lambda_role.arn
  timeout         = 30
  memory_size     = 256

  logging_config {
    log_format = "JSON"
  }

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed.bucket
    }
  }
}

# S3 trigger for Lambda function
resource "aws_s3_bucket_notification" "uploads_notification" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

resource "aws_codestarconnections_connection" "github" {
  name          = "shared-github-connection"
  provider_type = "GitHub"
}

# # API Gateway for backend API
# resource "aws_api_gateway_rest_api" "main" {
#   name = "${var.project_name}-api"
# }

# resource "aws_api_gateway_resource" "upload" {
#   rest_api_id = aws_api_gateway_rest_api.main.id
#   parent_id   = aws_api_gateway_rest_api.main.root_resource_id
#   path_part   = "upload"
# }

# resource "aws_api_gateway_method" "upload_post" {
#   rest_api_id   = aws_api_gateway_rest_api.main.id
#   resource_id   = aws_api_gateway_resource.upload.id
#   http_method   = "POST"
#   authorization = "NONE"
# }

# resource "aws_api_gateway_integration" "upload_integration" {
#   rest_api_id = aws_api_gateway_rest_api.main.id
#   resource_id = aws_api_gateway_resource.upload.id
#   http_method = aws_api_gateway_method.upload_post.http_method

#   integration_http_method = "POST"
#   type                   = "HTTP_PROXY"
#   uri                    = "http://${aws_lb.backend.dns_name}/upload"
# }

# resource "aws_api_gateway_deployment" "main" {
#   rest_api_id = aws_api_gateway_rest_api.main.id

#   depends_on = [
#     aws_api_gateway_method.upload_post,
#     aws_api_gateway_integration.upload_integration,
#   ]
# }

# resource "aws_api_gateway_stage" "main" {
#   deployment_id = aws_api_gateway_deployment.main.id
#   rest_api_id   = aws_api_gateway_rest_api.main.id
#   stage_name    = "prod"
# }

# # Application Load Balancer for backend
# resource "aws_lb" "backend" {
#   name               = "${var.project_name}-backend-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.backend.id]
#   subnets            = aws_subnet.public[*].id
# }

# resource "aws_lb_target_group" "backend" {
#   name     = "${var.project_name}-backend-tg"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.main.id

#   health_check {
#     enabled             = true
#     healthy_threshold   = 2
#     interval            = 30
#     matcher             = "200"
#     path                = "/health"
#     port                = "traffic-port"
#     protocol            = "HTTP"
#     timeout             = 5
#     unhealthy_threshold = 2
#   }
# }

# resource "aws_lb_listener" "backend" {
#   load_balancer_arn = aws_lb.backend.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.backend.arn
#   }
# }

# VPC and networking
# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_name             = "${var.project_name}-${local.environment}"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = data.aws_availability_zones.available.names
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  environment          = local.environment
  region               = var.aws_region
  # Set to true to enable a VPC endpoint for S3
  create_s3_endpoint   = false
}

resource "aws_security_group" "backend" {
  name_prefix = "${var.project_name}-backend-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Random string for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Outputs
output "frontend_url" {
  value = module.frontend.frontend_cloudfront_distribution_domain_name
}

# output "api_gateway_url" {
#   value = "${aws_api_gateway_stage.main.invoke_url}/upload"
# }

output "uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "processed_bucket" {
  value = aws_s3_bucket.processed.bucket
}

output "lambda_ecr_repository_url" {
  value = aws_ecr_repository.lambda.repository_url
}

module "frontend" {
  source = "./modules/frontend"
  project_name = var.project_name
  environment = local.environment
  github_owner = "stegasaur"
  github_repo  = "imagasaur"
  github_branch = "main"
  buildspec = "frontend/buildspec.yml"
  codestar_connection_arn = aws_codestarconnections_connection.github.arn
}

module "backend" {
  source = "./modules/backend"

  project_name      = var.project_name
  environment       = local.environment
  uploads_bucket    = aws_s3_bucket.uploads.bucket
  processed_bucket  = aws_s3_bucket.processed.bucket

  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids
}

module "backend_pipeline" {
  source = "./modules/ecs-pipeline"

  project_name = var.project_name
  environment  = local.environment

  github_owner  = "stegasaur"
  github_repo   = "imagasaur"
  github_branch = "main"

  ecr_repository_name = module.backend.ecr_repository_name
  ecr_repository_arn  = module.backend.ecr_repository_arn
  ecr_repository_url  = module.backend.ecr_repository_url

  ecs_cluster_name = module.backend.ecs_cluster_name
  ecs_service_name = module.backend.ecs_service_name

  codestar_connection_arn = aws_codestarconnections_connection.github.arn
}
