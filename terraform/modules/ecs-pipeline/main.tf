# Pipeline module to manage the CI/CD pipeline using AWS CodePipeline

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-${var.environment}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-codepipeline-role"
    Environment = var.environment
  }
}

# IAM Policy for CodePipeline
resource "aws_iam_policy" "codepipeline_policy" {
  name        = "${var.project_name}-${var.environment}-codepipeline-policy"
  description = "Policy for CodePipeline"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ],
        Effect = "Allow"
      },
      {
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:TagResource"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Action = [
          "iam:PassRole"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      # add permissions for codestar connections
      {
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = var.codestar_connection_arn,
        Effect   = "Allow"
      },
      # add permissions for ecr
      {
        Effect ="Allow"
        Action =[
          "ecr:DescribeRepositories",
          "ecr:GetAuthorizationToken",
          "ecr-public:DescribeRepositories",
          "ecr-public:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ],
        Resource = var.ecr_repository_arn,
        Effect   = "Allow"
      },
      {
          Effect = "Allow"
          Action = [
            "sts:GetServiceBearerToken"
          ]
          Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEventspermissions"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codepipeline/*"
        ]
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "codepipeline_policy_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

# S3 Bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.project_name}-${var.environment}-pipeline-artifacts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-pipeline-artifacts"
    Environment = var.environment
  }
}

# S3 Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "codepipeline_bucket_ownership" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 Bucket ACL
resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.codepipeline_bucket_ownership]
  bucket     = aws_s3_bucket.codepipeline_bucket.id
  acl        = "private"
}

# AWS CodePipeline
resource "aws_codepipeline" "pipeline" {
  name     = "${var.project_name}-${var.environment}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
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

      # Use CodeConnections for GitHub
      configuration = {
        ConnectionArn = var.codestar_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAndPushImage"
      category         = "Build"
      owner            = "AWS"
      provider         = "ECRBuildAndPublish"
      input_artifacts  = ["source_output"]
      output_artifacts = []
      version          = "1"

      configuration = {
        "ECRRepositoryName": var.ecr_repository_name
        "ImageTags": "latest, ${var.environment}-${var.github_branch}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts  = ["source_output"]
      version         = "1"

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-pipeline"
    Environment = var.environment
  }
}

# Outputs
output "pipeline_url" {
  description = "URL to the CodePipeline console"
  value       = "https://console.aws.amazon.com/codepipeline/home?region=${data.aws_region.current.name}#/view/${aws_codepipeline.pipeline.name}"
}

# Get current AWS region
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
