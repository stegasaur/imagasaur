# Image Processor CodePipeline module

locals {
  name_prefix = "${var.project_name}-${var.environment}-image-processor"
}

############################################################
# IAM ROLE FOR CODEBUILD
############################################################
resource "aws_iam_role" "codebuild" {
  name = "${local.name_prefix}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "codebuild.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${local.name_prefix}-codebuild-policy"
  role   = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ECR permissions
      {
        Effect   = "Allow",
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = var.ecr_repository_arn
      },
      {
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      },
      # S3 artifacts bucket access
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          "${aws_s3_bucket.artifacts.arn}",
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      # CloudWatch Logs
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      # Lambda update permission
      {
        Effect   = "Allow",
        Action   = ["lambda:UpdateFunctionCode"],
        Resource = "arn:aws:lambda:*:*:function:${var.lambda_function_name}"
      }
    ]
  })
}

############################################################
# CODEBUILD PROJECT
############################################################
resource "aws_codebuild_project" "image_processor" {
  name          = "${local.name_prefix}-build"
  description   = "Builds and publishes Lambda container image, then updates the function"

  service_role  = aws_iam_role.codebuild.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true  # needed for Docker build
    environment_variable {
      name  = "ECR_REPO"
      value = var.ecr_repository_name
    }
    environment_variable {
      name  = "LAMBDA_NAME"
      value = var.lambda_function_name
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
    git_clone_depth = 1
    buildspec       = "lambda/buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.name_prefix}"
      stream_name = "build"
    }
  }
}

############################################################
# IAM ROLE FOR CODEPIPELINE
############################################################
resource "aws_iam_role" "codepipeline" {
  name = "${local.name_prefix}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "codepipeline.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${local.name_prefix}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # S3
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      # CodeBuild
      {
        Effect = "Allow",
        Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"],
        Resource = aws_codebuild_project.image_processor.arn
      },
      # CodeStar connection
      {
        Effect   = "Allow",
        Action   = ["codestar-connections:UseConnection"],
        Resource = var.codestar_connection_arn
      },
      # PassRole to CodeBuild
      {
        Effect   = "Allow",
        Action   = "iam:PassRole",
        Resource = aws_iam_role.codebuild.arn
      },
      # CloudWatch Logs permissions for pipeline
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

############################################################
# ARTIFACT BUCKET
############################################################
resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name_prefix}-artifacts-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

############################################################
# CODEPIPELINE
############################################################
resource "aws_codepipeline" "pipeline" {
  name       = "${local.name_prefix}-pipeline"
  role_arn   = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      name            = "BuildAndUpdateLambda"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.image_processor.name
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}