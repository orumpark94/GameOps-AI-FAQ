resource "kubernetes_network_policy_v1" "api_ingress" {
  metadata {
    name      = "chatbot-api-ingress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = local.api_labels
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = local.web_labels
        }
      }

      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_ingress_v1" "web" {
  metadata {
    name        = "chatbot-web"
    namespace   = kubernetes_namespace_v1.this.metadata[0].name
    annotations = local.ingress_annotations
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.host_name

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.web.metadata[0].name

              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.load_balancer_controller,
    kubernetes_deployment_v1.web
  ]

  wait_for_load_balancer = true
}
