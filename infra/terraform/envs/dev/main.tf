locals {
  project     = "gameops-ai-faq"
  environment = "dev"
  name_prefix = "${local.project}-${local.environment}"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  eks_cluster_name     = var.eks_cluster_name
  single_nat_gateway   = var.single_nat_gateway
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names = [
    "${local.project}-chatbot-web",
    "${local.project}-chatbot-api"
  ]
}
