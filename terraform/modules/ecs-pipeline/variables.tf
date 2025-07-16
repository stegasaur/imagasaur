variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
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
  description = "GitHub repository branch"
  type        = string
  default     = "main"
}

variable "ecr_repository_name" {
  description = "ECR repository URL"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URl"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
}
