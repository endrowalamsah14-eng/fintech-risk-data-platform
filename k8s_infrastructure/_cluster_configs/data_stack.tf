# ==============================================================================
# CORE NAMESPACE: THE ULTIMATE DATA STACK (UDS)
# ==============================================================================
resource "kubernetes_namespace" "data_stack" {
  metadata {
    name = "uds-production"
  }
}

# ==============================================================================
# ZONE 2: DATA INGESTION & BUFFER
# ==============================================================================

# 2.A. Redpanda Engine & Console
resource "helm_release" "redpanda" {
  name             = "redpanda"
  repository       = "https://charts.redpanda.com"
  chart            = "redpanda"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/redpanda-values.yaml")]
}

resource "helm_release" "redpanda_console" {
  name             = "redpanda-console"
  repository       = "https://charts.redpanda.com"
  chart            = "console"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/redpanda-console-values.yaml")]
  depends_on       = [helm_release.redpanda]
}

# 2.B. Benthos Router
resource "helm_release" "benthos" {
  name             = "benthos-router"
  repository       = "https://benthosdev.github.io/charts"
  chart            = "benthos"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/benthos-values.yaml")]
  depends_on       = [helm_release.redpanda]
}

# 2.C. Debezium CDC Engine (With CPU/RAM Limits)
resource "kubernetes_deployment" "debezium" {
  metadata {
    name      = "debezium-connect"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "debezium-connect" } }
    template {
      metadata { labels = { app = "debezium-connect" } }
      spec {
        container {
          name  = "debezium"
          image = "quay.io/debezium/connect:2.4"
          port { container_port = 8083 }
          env {
            name  = "BOOTSTRAP_SERVERS"
            value = "redpanda-0.redpanda.uds-production.svc.cluster.local:9093"
          }
          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
          }
        }
      }
    }
  }
}

# 2.C.1 Debezium Auto-Scaler (HPA)
resource "kubernetes_horizontal_pod_autoscaler_v2" "debezium_hpa" {
  metadata {
    name      = "debezium-hpa"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    max_replicas = 3
    min_replicas = 1
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.debezium.metadata[0].name
    }
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 75
        }
      }
    }
  }
}

resource "kubernetes_service" "debezium_svc" {
  metadata {
    name      = "debezium-api"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    selector = { app = "debezium-connect" }
    port {
      port        = 8083
      target_port = 8083
    }
  }
}

# 2.D. Debezium UI
resource "kubernetes_deployment" "debezium_ui" {
  metadata {
    name      = "debezium-ui"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "debezium-ui" } }
    template {
      metadata { labels = { app = "debezium-ui" } }
      spec {
        container {
          name  = "debezium-ui"
          image = "quay.io/debezium/debezium-ui:2.4"
          port { container_port = 8080 }
          env {
            name  = "KAFKA_CONNECT_URIS"
            value = "http://debezium-api:8083"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "debezium_ui_svc" {
  metadata {
    name      = "debezium-ui-svc"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    selector = { app = "debezium-ui" }
    port {
      port        = 80
      target_port = 8080
    }
  }
}

# ==============================================================================
# ZONE 3A: REAL-TIME PATH
# ==============================================================================

# 3A.1. RisingWave Engine & Dashboard
resource "helm_release" "risingwave" {
  name             = "risingwave"
  repository       = "https://risingwavelabs.github.io/helm-charts"
  chart            = "risingwave"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/risingwave-values.yaml")]
}

resource "kubernetes_service" "risingwave_dashboard" {
  metadata {
    name      = "risingwave-dashboard"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name"      = "risingwave"
      "app.kubernetes.io/component" = "frontend"
    }
    port {
      name        = "http-dashboard"
      port        = 80
      target_port = 5691
    }
  }
}

# 3A.2. Redis Engine & RedisInsight
resource "helm_release" "redis" {
  name       = "redis"
  repository = "oci://registry-1.docker.io/bitnamicharts" 
  chart      = "redis"
  version    = "19.6.1"
  namespace  = kubernetes_namespace.data_stack.metadata[0].name
  values     = [file("${path.module}/../values/redis-values.yaml")]
}

resource "kubernetes_deployment" "redisinsight" {
  metadata {
    name      = "redisinsight"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "redisinsight" } }
    template {
      metadata { labels = { app = "redisinsight" } }
      spec {
        container {
          name  = "redisinsight"
          image = "redis/redisinsight:latest"
          port { container_port = 5540 }
        }
      }
    }
  }
}

resource "kubernetes_service" "redisinsight_svc" {
  metadata {
    name      = "redisinsight-svc"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    selector = { app = "redisinsight" }
    port {
      port        = 80
      target_port = 5540
    }
  }
}

# 3A.3. Seldon Core (MLOps)
resource "helm_release" "seldon_core" {
  name             = "seldon-core-operator"
  repository       = "https://storage.googleapis.com/seldon-charts"
  chart            = "seldon-core-operator"
  namespace        = "seldon-system"
  create_namespace = true
  values = [yamlencode({ usageMetrics = { enabled = false }, istio = { enabled = false } })]
}

# ==============================================================================
# ZONE 3B: BATCH COMPUTE & ORCHESTRATION
# ==============================================================================

# 3B.1. Temporal Engine & UI
resource "helm_release" "temporal_postgresql" {
  name       = "temporal-postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "15.5.38"
  namespace  = kubernetes_namespace.data_stack.metadata[0].name
  values = [yamlencode({
    auth = { username = "temporal", password = "temporal-dev-password", database = "temporal" }
  })]
}

resource "helm_release" "temporal" {
  name             = "temporal"
  repository       = "https://go.temporal.io/helm-charts"
  chart            = "temporal"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/temporal-values.yaml")]
  depends_on       = [helm_release.temporal_postgresql]
}

resource "kubernetes_service" "temporal_ui_svc" {
  metadata {
    name      = "temporal-ui-dashboard"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name"      = "temporal"
      "app.kubernetes.io/component" = "web"
    }
    port {
      port        = 8080
      target_port = 8080
    }
  }
}

# 3B.2. StarRocks
resource "helm_release" "starrocks" {
  name             = "starrocks"
  repository       = "https://starrocks.github.io/starrocks-kubernetes-operator"
  chart            = "kube-starrocks"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/starrocks-values.yaml")]
}

# 3B.3. DEATHSTAR-SHIP (Polars) Temporal Worker Pool
resource "kubernetes_deployment" "polars_worker" {
  metadata {
    name      = "deathstar-ship-polars"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "polars-worker" } }
    template {
      metadata { labels = { app = "polars-worker" } }
      spec {
        container {
          name    = "polars-worker"
          image   = "python:3.11-slim"
          command = ["echo", "Polars Temporal Worker Listening..."]
          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
          }
        }
      }
    }
  }
}

# 3B.3.1 Polars Auto-Scaler (HPA)
resource "kubernetes_horizontal_pod_autoscaler_v2" "polars_hpa" {
  metadata {
    name      = "polars-hpa"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    max_replicas = 5
    min_replicas = 1
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.polars_worker.metadata[0].name
    }
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}

# 3B.4. dbt-core Data Contracts Validation (Kept as Job for Cron/Batch execution)
resource "kubernetes_job" "dbt_core_validation" {
  metadata {
    name      = "dbt-core-validation"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    template {
      metadata { labels = { app = "dbt-validation" } }
      spec {
        container {
          name    = "dbt-worker"
          image   = "ghcr.io/dbt-labs/dbt-bigquery:latest"
          command = ["dbt", "--version"]
        }
        restart_policy = "Never"
      }
    }
  }
}

# ==============================================================================
# CLUSTER HEALTH OBSERVERS & BI
# ==============================================================================

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/prometheus-values.yaml")]
}

resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/grafana-values.yaml")]
}

resource "helm_release" "metabase" {
  name             = "metabase"
  repository       = "https://pmint93.github.io/helm-charts"
  chart            = "metabase"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  values           = [file("${path.module}/../values/metabase-values.yaml")]
  depends_on       = [helm_release.starrocks]
}