variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "imagasaur"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "cwg"
}

variable "root_domain" {
  type = string
  description = "Root domain for the application, e.g., example.com"
  default = "explodeme.com"
}
