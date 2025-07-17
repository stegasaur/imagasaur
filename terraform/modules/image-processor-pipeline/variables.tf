variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch to track"
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "ARN of the shared CodeStar Connections connection"
  type        = string
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository that stores the Lambda container image"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the target Lambda function to update"
  type        = string
}