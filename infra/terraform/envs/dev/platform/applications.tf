resource "kubernetes_deployment_v1" "api" {
  wait_for_rollout = false

  metadata {
    name      = "chatbot-api"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.api_labels
  }

  spec {
    replicas = tostring(var.api_replicas)

    selector {
      match_labels = local.api_labels
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = local.api_labels
      }

      spec {
        service_account_name = kubernetes_service_account_v1.api.metadata[0].name

        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "ScheduleAnyway"

          label_selector {
            match_labels = local.api_labels
          }
        }

        container {
          name              = "chatbot-api"
          image             = "${local.api_repository_url}:${var.initial_image_tag}"
          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 8080
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.app.metadata[0].name
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "http"
            }

            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "http"
            }

            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true

            capabilities {
              drop = ["ALL"]
            }
          }
        }

        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].template[0].spec[0].container[0].image
    ]
  }

  depends_on = [aws_eks_pod_identity_association.chatbot_api]
}

resource "kubernetes_service_v1" "api" {
  metadata {
    name      = "chatbot-api-svc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = local.api_labels

    port {
      name        = "http"
      port        = 8080
      target_port = "http"
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment_v1" "web" {
  wait_for_rollout = false

  metadata {
    name      = "chatbot-web"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.web_labels
  }

  spec {
    replicas = tostring(var.web_replicas)

    selector {
      match_labels = local.web_labels
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = local.web_labels
      }

      spec {
        service_account_name            = kubernetes_service_account_v1.web.metadata[0].name
        automount_service_account_token = false

        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "ScheduleAnyway"

          label_selector {
            match_labels = local.web_labels
          }
        }

        container {
          name              = "chatbot-web"
          image             = "${local.web_repository_url}:${var.initial_image_tag}"
          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 3000
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }

          env {
            name  = "PORT"
            value = "3000"
          }

          env {
            name = "CHATBOT_API_BASE_URL"

            value_from {
              config_map_key_ref {
                name = kubernetes_config_map_v1.app.metadata[0].name
                key  = "CHATBOT_API_BASE_URL"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = "http"
            }

            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = "http"
            }

            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "next-cache"
            mount_path = "/app/.next/cache"
          }
        }

        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
        }

        volume {
          name = "tmp"

          empty_dir {}
        }

        volume {
          name = "next-cache"

          empty_dir {}
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].template[0].spec[0].container[0].image
    ]
  }
}

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "chatbot-web-svc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = local.web_labels

    port {
      name        = "http"
      port        = 3000
      target_port = "http"
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "api" {
  metadata {
    name      = "chatbot-api"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    min_available = "1"

    selector {
      match_labels = local.api_labels
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "web" {
  metadata {
    name      = "chatbot-web"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    min_available = "1"

    selector {
      match_labels = local.web_labels
    }
  }
}
