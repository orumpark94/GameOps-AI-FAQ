variable "aws_region" {
  description = "AWS region where dev resources are created."
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the dev VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used by the dev VPC."
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks. Count must match availability_zones."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks. Count must match availability_zones."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "eks_cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "gameops-ai-faq-dev"
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes version. Null lets AWS select its current default."
  type        = string
  default     = null
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Restrict to your public IP /32 before apply."
  type        = list(string)
  default     = ["116.122.56.145/32"]
}

variable "eks_cluster_admin_principal_arn" {
  description = "IAM principal granted EKS cluster admin access. Null uses the current Terraform caller."
  type        = string
  default     = null
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway for lower dev cost."
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "Managed node group EC2 instance types."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Managed node group capacity type."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  description = "Desired EKS managed node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum EKS managed node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum EKS managed node count."
  type        = number
  default     = 2
}

variable "bedrock_generation_inference_profile_id" {
  description = "Bedrock system-defined inference profile ID used by RetrieveAndGenerate."
  type        = string
  default     = "apac.amazon.nova-micro-v1:0"
}

variable "knowledge_base_document_prefix" {
  description = "S3 prefix containing FAQ documents."
  type        = string
  default     = "dev/"
}
