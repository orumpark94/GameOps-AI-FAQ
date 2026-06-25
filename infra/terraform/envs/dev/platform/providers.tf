terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

data "terraform_remote_state" "infrastructure" {
  backend = "local"

  config = {
    path = "${path.module}/../infrastructure/terraform.tfstate"
  }
}

locals {
  infrastructure = data.terraform_remote_state.infrastructure.outputs
}

provider "aws" {
  region = local.infrastructure.aws_region

  default_tags {
    tags = {
      Project     = "gameops-ai-faq"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

provider "kubernetes" {
  host                   = local.infrastructure.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(local.infrastructure.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--region",
      local.infrastructure.aws_region,
      "--cluster-name",
      local.infrastructure.eks_cluster_name
    ]
  }
}

provider "helm" {
  kubernetes = {
    host                   = local.infrastructure.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(local.infrastructure.eks_cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--region",
        local.infrastructure.aws_region,
        "--cluster-name",
        local.infrastructure.eks_cluster_name
      ]
    }
  }
}
