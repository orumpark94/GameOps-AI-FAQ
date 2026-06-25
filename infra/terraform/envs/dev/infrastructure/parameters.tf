locals {
  parameter_prefix = "/${local.project}/${local.environment}"

  deployment_parameters = {
    aws_region         = var.aws_region
    eks_cluster_name   = module.eks.cluster_name
    ecr_web_url        = module.ecr.repository_urls["${local.project}-chatbot-web"]
    ecr_api_url        = module.ecr.repository_urls["${local.project}-chatbot-api"]
    kb_document_bucket = module.knowledge_base.document_bucket_name
    kb_document_prefix = module.knowledge_base.document_prefix
    knowledge_base_id  = module.knowledge_base.knowledge_base_id
    data_source_id     = module.knowledge_base.data_source_id
  }

  deployment_parameter_names = {
    aws_region         = "${local.parameter_prefix}/aws-region"
    eks_cluster_name   = "${local.parameter_prefix}/eks/cluster-name"
    ecr_web_url        = "${local.parameter_prefix}/ecr/web-repository-url"
    ecr_api_url        = "${local.parameter_prefix}/ecr/api-repository-url"
    kb_document_bucket = "${local.parameter_prefix}/kb/document-bucket"
    kb_document_prefix = "${local.parameter_prefix}/kb/document-prefix"
    knowledge_base_id  = "${local.parameter_prefix}/kb/knowledge-base-id"
    data_source_id     = "${local.parameter_prefix}/kb/data-source-id"
  }
}

resource "aws_ssm_parameter" "deployment" {
  for_each = local.deployment_parameters

  name  = local.deployment_parameter_names[each.key]
  type  = "String"
  value = each.value

  tags = {
    Purpose = "github-actions-deployment-discovery"
  }
}
