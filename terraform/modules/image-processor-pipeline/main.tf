# Image Processor CodePipeline module

locals {
  name_prefix            = "${var.project_name}-${var.environment}-image-processor"
  shared_artifacts_arn = "arn:aws:s3:::${var.shared_artifacts_bucket_id}"
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

resource "aws_iam_role_policy" "codebuild_ecr" {
  name = "${local.name_prefix}-codebuild-ecr"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories"
        ],
        Resource = var.ecr_repository_arn
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          local.shared_artifacts_arn,
          "${local.shared_artifacts_arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.name_prefix}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.name_prefix}:log-stream:*"
      },
      {
        Effect = "Allow",
        Action = [
          "lambda:UpdateFunctionCode"
        ],
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.lambda_function_name}"
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
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
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
          local.shared_artifacts_arn,
          "${local.shared_artifacts_arn}/*"
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
        Action = ["logs:CreateLogGroup"],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codepipeline/${local.name_prefix}-pipeline:*"
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codepipeline/${local.name_prefix}-pipeline:log-stream:*"
      }
    ]
  })
}

############################################################
# ARTIFACT BUCKET
############################################################
# NO LONGER NEEDED, USING SHARED BUCKET FROM ROOT MODULE


############################################################
# CODEPIPELINE
############################################################
resource "aws_codepipeline" "pipeline" {
  name       = "${local.name_prefix}-pipeline"
  role_arn   = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = var.shared_artifacts_bucket_id
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
        DetectChanges    = "true"
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

# Get current AWS region
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
