# Image Processor CodePipeline module

locals {
  name_prefix            = "${var.project_name}-${var.environment}-image-processor"
  shared_artifacts_arn = "arn:aws:s3:::${var.shared_artifacts_bucket_id}"
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

  # stage {
  #   name = "Deploy"

  #   action {
  #     name            = "DeployToLambda"
  #     category        = "Deploy"
  #     owner           = "AWS"
  #     provider        = "Lambda"
  #     input_artifacts  = ["source_output"]
  #     version         = "1"

  #     configuration = {
  #       LambdaFunctionName = var.lambda_function_name
  #     }
  #   }
  # }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Get current AWS region
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
