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
  description = "GitHub repository branch for frontend."
  type        = string
  default     = "main"
}

variable "buildspec" {
  description = "Path to the buildspec file for CodeBuild."
  type        = string
  default     = "buildspec.yml"
}

variable "codestar_connection_arn" {
  description = "ARN of the shared AWS CodeStar Connections connection."
  type        = string
}
