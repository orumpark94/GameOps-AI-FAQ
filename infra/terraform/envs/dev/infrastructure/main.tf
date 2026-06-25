data "aws_caller_identity" "current" {}

check "subnet_counts_match_availability_zones" {
  assert {
    condition = (
      length(var.public_subnet_cidrs) == length(var.availability_zones) &&
      length(var.private_subnet_cidrs) == length(var.availability_zones)
    )
    error_message = "Public and private subnet CIDR counts must match availability_zones."
  }
}

locals {
  project     = "gameops-ai-faq"
  environment = "dev"
  name_prefix = "${local.project}-${local.environment}"

  cluster_admin_principal_arn = coalesce(
    var.eks_cluster_admin_principal_arn,
    data.aws_caller_identity.current.arn
  )

  generation_inference_profile_arn = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_generation_inference_profile_id}"
  nova_micro_foundation_model_arn  = "arn:aws:bedrock:*::foundation-model/amazon.nova-micro-v1:0"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  eks_cluster_name     = var.eks_cluster_name
  single_nat_gateway   = var.single_nat_gateway
}

module "ecr" {
  source = "../../../modules/ecr"

  repository_names = [
    "${local.project}-chatbot-web",
    "${local.project}-chatbot-api"
  ]
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name                = var.eks_cluster_name
  cluster_version             = var.eks_cluster_version
  private_subnet_ids          = module.vpc.private_subnet_ids
  public_access_cidrs         = var.eks_public_access_cidrs
  cluster_admin_principal_arn = local.cluster_admin_principal_arn
  node_instance_types         = var.node_instance_types
  node_capacity_type          = var.node_capacity_type
  node_desired_size           = var.node_desired_size
  node_min_size               = var.node_min_size
  node_max_size               = var.node_max_size
}

module "knowledge_base" {
  source = "../../../modules/knowledge-base"

  name_prefix     = local.name_prefix
  aws_region      = var.aws_region
  account_id      = data.aws_caller_identity.current.account_id
  document_prefix = var.knowledge_base_document_prefix
}

module "workload_iam" {
  source = "../../../modules/workload-iam"

  name_prefix        = local.name_prefix
  knowledge_base_arn = module.knowledge_base.knowledge_base_arn
  generation_model_resource_arns = [
    local.generation_inference_profile_arn,
    local.nova_micro_foundation_model_arn
  ]
}
