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
  description = "Future EKS cluster name. Used now for Kubernetes subnet discovery tags."
  type        = string
  default     = "gameops-ai-faq-dev"
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway for lower dev cost. Set false for one NAT Gateway per AZ."
  type        = bool
  default     = true
}
