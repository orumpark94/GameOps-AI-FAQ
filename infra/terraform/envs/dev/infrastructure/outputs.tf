output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "vpc_id" {
  description = "Dev VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes."
  value       = module.vpc.private_subnet_ids
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by repository name."
  value       = module.ecr.repository_urls
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64-encoded EKS certificate authority data."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller Pod Identity role ARN."
  value       = module.workload_iam.load_balancer_controller_role_arn
}

output "chatbot_api_role_arn" {
  description = "chatbot-api Pod Identity role ARN."
  value       = module.workload_iam.chatbot_api_role_arn
}

output "knowledge_base_document_bucket" {
  description = "S3 bucket for FAQ source documents."
  value       = module.knowledge_base.document_bucket_name
}

output "knowledge_base_document_prefix" {
  description = "S3 prefix for FAQ source documents."
  value       = module.knowledge_base.document_prefix
}

output "bedrock_knowledge_base_id" {
  description = "Bedrock Knowledge Base ID."
  value       = module.knowledge_base.knowledge_base_id
}

output "bedrock_data_source_id" {
  description = "Bedrock Knowledge Base data source ID."
  value       = module.knowledge_base.data_source_id
}

output "bedrock_generation_model_arn" {
  description = "Bedrock Nova Micro inference profile ARN used by chatbot-api."
  value       = local.generation_inference_profile_arn
}
