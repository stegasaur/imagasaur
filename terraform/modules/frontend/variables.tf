variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner for frontend."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for frontend."
  type        = string
}

variable "github_branch" {
  description = "Branch to track for the pipeline"
  type        = string
  default     = "main"
}

variable "buildspec" {
  description = "Path to the buildspec file for CodeBuild."
  type        = string
  default     = "buildspec.yml"
}

variable "codestar_connection_arn" {
  description = "ARN of the shared CodeStar Connections connection"
  type        = string
}

variable "shared_artifacts_bucket_id" {
  description = "ID (name) of the shared S3 bucket for CodePipeline artifacts"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the certificate for the domain"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the frontend"
  type        = string
}

variable "api_domain_name" {
  description = "Domain name for the API"
  type        = string
}
