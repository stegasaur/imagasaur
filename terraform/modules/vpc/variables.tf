variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "create_s3_endpoint" {
  description = "Whether to create a VPC endpoint for S3."
  type        = bool
  default     = false
}

variable "region" {
  description = "AWS region for the VPC and resources."
  type        = string
}
