locals {
  web_labels = {
    app       = "chatbot-web"
    component = "frontend"
  }

  api_labels = {
    app       = "chatbot-api"
    component = "backend"
  }

  web_repository_url = local.infrastructure.ecr_repository_urls["gameops-ai-faq-chatbot-web"]
  api_repository_url = local.infrastructure.ecr_repository_urls["gameops-ai-faq-chatbot-api"]

  alb_http_annotations = {
    "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }])
  }

  alb_https_annotations = {
    "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
    "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTPS = 443 }])
    "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
  }

  ingress_annotations = merge(
    {
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/api/health"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/success-codes"        = "200"
    },
    var.acm_certificate_arn == null ? local.alb_http_annotations : local.alb_https_annotations
  )
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/part-of" = "gameops-ai-faq"
      environment                 = "dev"
    }
  }
}

resource "kubernetes_service_account_v1" "load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
}

resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name    = local.infrastructure.eks_cluster_name
  namespace       = kubernetes_service_account_v1.load_balancer_controller.metadata[0].namespace
  service_account = kubernetes_service_account_v1.load_balancer_controller.metadata[0].name
  role_arn        = local.infrastructure.load_balancer_controller_role_arn
}

resource "helm_release" "load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version
  namespace  = "kube-system"

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  set = [
    {
      name  = "clusterName"
      value = local.infrastructure.eks_cluster_name
    },
    {
      name  = "region"
      value = local.infrastructure.aws_region
    },
    {
      name  = "vpcId"
      value = local.infrastructure.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account_v1.load_balancer_controller.metadata[0].name
    }
  ]

  depends_on = [aws_eks_pod_identity_association.load_balancer_controller]
}

resource "kubernetes_service_account_v1" "web" {
  metadata {
    name      = "chatbot-web"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  automount_service_account_token = false
}

resource "kubernetes_service_account_v1" "api" {
  metadata {
    name      = "chatbot-api"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
}

resource "aws_eks_pod_identity_association" "chatbot_api" {
  cluster_name    = local.infrastructure.eks_cluster_name
  namespace       = kubernetes_service_account_v1.api.metadata[0].namespace
  service_account = kubernetes_service_account_v1.api.metadata[0].name
  role_arn        = local.infrastructure.chatbot_api_role_arn
}

resource "kubernetes_config_map_v1" "app" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    AWS_REGION                        = local.infrastructure.aws_region
    BEDROCK_KNOWLEDGE_BASE_ID         = local.infrastructure.bedrock_knowledge_base_id
    BEDROCK_MODEL_ARN                 = local.infrastructure.bedrock_generation_model_arn
    BEDROCK_RETRIEVAL_SCORE_THRESHOLD = tostring(var.bedrock_retrieval_score_threshold)
    CUSTOMER_SUPPORT_EMAIL            = var.customer_support_email
    CHATBOT_API_BASE_URL              = "http://chatbot-api-svc:8080"
  }
}
