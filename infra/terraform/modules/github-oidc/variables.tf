variable "name_prefix" {
  description = "Name prefix for GitHub Actions IAM resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region containing the deployment resources."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name format."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the role."
  type        = string
  default     = "main"
}

variable "existing_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN. Null creates a provider in this Terraform state."
  type        = string
  default     = null
}

variable "ecr_repository_arns" {
  description = "ECR repositories that GitHub Actions can push images to."
  type        = list(string)
}

variable "document_bucket_arn" {
  description = "S3 bucket ARN containing Knowledge Base source documents."
  type        = string
}

variable "document_prefix" {
  description = "S3 prefix containing Knowledge Base source documents."
  type        = string
}

variable "knowledge_base_arn" {
  description = "Bedrock Knowledge Base ARN used for ingestion jobs."
  type        = string
}

variable "ssm_parameter_prefix" {
  description = "SSM parameter path that GitHub Actions can read."
  type        = string
}
