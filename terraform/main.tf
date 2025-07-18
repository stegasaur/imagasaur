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

# -----------------------------------------------------------------------------
# DNS Records
# -----------------------------------------------------------------------------

# Route53 Hosted Zone
data "aws_route53_zone" "main" {
  name = "imagasaur.com"
}

# DNS Record for frontend
resource "aws_route53_record" "frontend" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.imagasaur.com"
  type    = "A"

  alias {
    name                   = module.frontend.frontend_cloudfront_distribution_domain_name
    zone_id                = module.frontend.frontend_cloudfront_distribution_hosted_zone_id
    evaluate_target_health = true
  }
}

# DNS Record for backend
resource "aws_route53_record" "backend" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.imagasaur.com"
  type    = "A"

  alias {
    name                   = module.backend.load_balancer_dns_name
    zone_id                = module.backend.load_balancer_zone_id
    evaluate_target_health = true
  }
}

# -----------------------------------------------------------------------------
# Certificate
# -----------------------------------------------------------------------------

# Wildcard certificate for all subdomains
resource "aws_acm_certificate" "wildcard" {
  domain_name = "*.imagasaur.com"
  validation_method = "DNS"
  subject_alternative_names = ["imagasaur.com", "www.imagasaur.com", "api.imagasaur.com"]
}

# DNS Record for certificate validation

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
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

resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.project_name}-${local.environment}-shared-pipeline-artifacts-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration { status = "Enabled" }
}

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
  shared_artifacts_bucket_id  = aws_s3_bucket.codepipeline_artifacts.id
  certificate_arn = aws_acm_certificate.wildcard.arn
  domain_name = "www.imagasaur.com"
  api_domain_name = "api.imagasaur.com"
}

# -----------------------------------------------------------------------------
# Image Processor CI/CD Pipeline
# -----------------------------------------------------------------------------
module "image_processor_pipeline" {
  source                  = "./modules/image-processor-pipeline"
  project_name            = var.project_name
  environment             = local.environment

  github_owner            = "stegasaur"
  github_repo             = "imagasaur"
  github_branch           = "main"

  codestar_connection_arn = aws_codestarconnections_connection.github.arn

  ecr_repository_name     = aws_ecr_repository.lambda.name
  ecr_repository_arn      = aws_ecr_repository.lambda.arn

  lambda_function_name    = aws_lambda_function.image_processor.function_name
  shared_artifacts_bucket_id  = aws_s3_bucket.codepipeline_artifacts.id
}

module "backend" {
  source = "./modules/backend"

  project_name      = var.project_name
  environment       = local.environment
  uploads_bucket    = aws_s3_bucket.uploads.bucket
  processed_bucket  = aws_s3_bucket.processed.bucket

  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids

  certificate_arn = aws_acm_certificate.wildcard.arn
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
  ecs_container_name = module.backend.container_name
}
