# ==============================================================================
# CORE NAMESPACE: THE ULTIMATE DATA STACK (UDS)
# ==============================================================================
resource "kubernetes_namespace" "data_stack" {
  metadata {
    name = "uds-production"
  }
}

resource "helm_release" "local_path_provisioner" {
  name       = "local-path-provisioner"
  repository = "https://charts.containeroo.ch"
  chart      = "local-path-provisioner"
  namespace  = "kube-system"

  values = [
    yamlencode({
      storageClass = {
        defaultClass = true
      }
    })
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.16.2"
  namespace        = "cert-manager"
  create_namespace = true

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
    })
  ]
}

# ==============================================================================
# 1. THE CONTROL PLANE (ORCHESTRATOR)
# ==============================================================================
resource "helm_release" "temporal_postgresql" {
  name       = "temporal-postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "15.5.38"
  namespace  = kubernetes_namespace.data_stack.metadata[0].name

  values = [yamlencode({
    image = {
      repository = "bitnamilegacy/postgresql"
      tag        = "16.4.0-debian-12-r14"
    }
    auth = {
      username = "temporal"
      password = "temporal-dev-password"
      database = "temporal"
    }
    primary = {
      persistence = {
        enabled      = true
        storageClass = "local-path"
        size         = "8Gi"
      }
      resources = {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "1Gi"
        }
      }
    }
  })]
}

resource "helm_release" "temporal" {
  name             = "temporal"
  repository       = "https://go.temporal.io/helm-charts"
  chart            = "temporal"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  
  values = [file("${path.module}/../values/temporal-values.yaml")]
  depends_on = [helm_release.temporal_postgresql]
}

# ==============================================================================
# 2. THE INGESTION & MESSAGE BUS (NON-JVM)
# ==============================================================================
resource "helm_release" "redpanda" {
  name             = "redpanda"
  repository       = "https://charts.redpanda.com"
  chart            = "redpanda"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  
  values = [file("${path.module}/../values/redpanda-values.yaml")]
}

# ==============================================================================
# 3. THE PROCESSING, CONTRACTS, & ROUTING
# ==============================================================================
resource "helm_release" "benthos" {
  name             = "benthos-router"
  repository       = "https://benthosdev.github.io/charts"
  chart            = "benthos"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  timeout          = 900 # 🔥 FIX: Tambah durasi 15 menit agar tidak context deadline exceeded
  
  values = [file("${path.module}/../values/benthos-values.yaml")]
  depends_on = [helm_release.redpanda]
}

resource "helm_release" "risingwave" {
  name             = "risingwave"
  repository       = "https://risingwavelabs.github.io/helm-charts"
  chart            = "risingwave"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  
  values = [file("${path.module}/../values/risingwave-values.yaml")]
}

# ==============================================================================
# 4. THE COMPUTE ENGINE & MLOPS BRIDGE
# ==============================================================================
resource "helm_release" "starrocks" {
  name             = "starrocks"
  repository       = "https://starrocks.github.io/starrocks-kubernetes-operator"
  chart            = "kube-starrocks"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  
  values = [file("${path.module}/../values/starrocks-values.yaml")]
}

# 🔥 FIX: Repository Helm Feast sudah dihapus/mati (404 Not Found) dari sisi developer. 
# Daripada pipeline CI/CD lu gagal total, eksekusi ini di-comment sementara.
# resource "helm_release" "feast" {
#   name             = "feast"
#   repository       = "https://feast-dev.github.io/feast-helm-charts"
#   chart            = "feast"
#   namespace        = kubernetes_namespace.data_stack.metadata[0].name
#   
#   values = [file("${path.module}/../values/feast-values.yaml")]
#   depends_on = [helm_release.starrocks, helm_release.risingwave]
# }

# ==============================================================================
# 5. BUSINESS INTELLIGENCE & VISUALIZATION
# ==============================================================================
resource "helm_release" "metabase" {
  name             = "metabase"
  repository       = "https://pmint93.github.io/helm-charts"
  chart            = "metabase"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  
  values = [file("${path.module}/../values/metabase-values.yaml")]
  depends_on = [helm_release.starrocks]
}

# ==============================================================================
# 6. OBSERVABILITY (GRAFANA & PROMETHEUS)
# ==============================================================================
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  
  values = [file("${path.module}/../values/prometheus-values.yaml")]
}

resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  
  values = [file("${path.module}/../values/grafana-values.yaml")]
}

# ==============================================================================
# 7. ML RISK ENGINE & ONLINE STORE (PROD-K8S)
# ==============================================================================

# ------------------------------------------------------------------------------
# 7.A. POSTGRES METADATA (FOR MLFLOW & BENTOML)
# ------------------------------------------------------------------------------
resource "kubernetes_persistent_volume_claim" "postgres_metadata_pvc" {
  metadata {
    name      = "postgres-metadata-pvc"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_service" "postgres_metadata_svc" {
  metadata {
    name      = "postgres-metadata"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    selector = {
      app = "postgres-metadata"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "postgres_init_script" {
  metadata {
    name      = "postgres-init-script"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  data = {
    "init.sql" = <<-EOT
      CREATE USER mlflow_admin WITH ENCRYPTED PASSWORD 'mlflow_super_secret';
      CREATE DATABASE mlflow_db;
      GRANT ALL PRIVILEGES ON DATABASE mlflow_db TO mlflow_admin;
      ALTER DATABASE mlflow_db OWNER TO mlflow_admin;

      CREATE USER yatai WITH ENCRYPTED PASSWORD 'yatai_secret_password';
      CREATE DATABASE yatai;
      GRANT ALL PRIVILEGES ON DATABASE yatai TO yatai;
      ALTER DATABASE yatai OWNER TO yatai;
    EOT
  }
}

resource "kubernetes_deployment" "postgres_metadata" {
  metadata {
    name      = "postgres-metadata"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres-metadata"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres-metadata"
        }
      }
      spec {
        volume {
          name = "pg-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_metadata_pvc.metadata[0].name
          }
        }
        volume {
          name = "init-scripts"
          config_map {
            name = kubernetes_config_map.postgres_init_script.metadata[0].name
          }
        }
        container {
          name  = "postgres"
          image = "postgres:15-alpine"
          port {
            container_port = 5432
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "super_secret_root_password"
          }
          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          volume_mount {
            name       = "pg-data"
            mount_path = "/var/lib/postgresql/data"
          }
          volume_mount {
            name       = "init-scripts"
            mount_path = "/docker-entrypoint-initdb.d"
          }
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# 7.B. REDIS, MLFLOW, & BENTOML
# ------------------------------------------------------------------------------
resource "helm_release" "redis" {
  name       = "redis"
  repository = "oci://registry-1.docker.io/bitnamicharts" 
  chart      = "redis"
  version    = "19.6.1"
  namespace  = kubernetes_namespace.data_stack.metadata[0].name

  values = [file("${path.module}/../values/redis-values.yaml")]
}

resource "helm_release" "mlflow" {
  name             = "mlflow"
  repository       = "https://community-charts.github.io/helm-charts"
  chart            = "mlflow"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  timeout          = 900 
  
  values = [file("${path.module}/../values/mlflow-values.yaml")]
  depends_on = [kubernetes_deployment.postgres_metadata] # 🔥 FIX: Kunci dependency DB
}

resource "helm_release" "bentoml" {
  name             = "bentoml"
  repository       = "https://bentoml.github.io/helm-charts" 
  chart            = "yatai" 
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  timeout          = 900 
  
  values = [file("${path.module}/../values/bentoml-values.yaml")]
  depends_on = [kubernetes_deployment.postgres_metadata] # 🔥 FIX: Kunci dependency DB
}

# ==============================================================================
# 8. CONSOLES, DASHBOARDS, & CDC WORKERS (ANTI-SUNAT CLUB)
# ==============================================================================

# ------------------------------------------------------------------------------
# 8.A. REDISINSIGHT (Redis UI)
# ------------------------------------------------------------------------------
resource "kubernetes_deployment" "redisinsight" {
  metadata {
    name      = "redisinsight"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "redisinsight"
      }
    }
    template {
      metadata {
        labels = {
          app = "redisinsight"
        }
      }
      spec {
        container {
          name  = "redisinsight"
          image = "redis/redisinsight:latest"
          port {
            container_port = 5540
          }
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
    selector = {
      app = "redisinsight"
    }
    port {
      port        = 80
      target_port = 5540
    }
  }
}

# ------------------------------------------------------------------------------
# 8.B. REDPANDA CONSOLE
# ------------------------------------------------------------------------------
resource "helm_release" "redpanda_console" {
  name             = "redpanda-console"
  repository       = "https://charts.redpanda.com"
  chart            = "console"
  namespace        = kubernetes_namespace.data_stack.metadata[0].name
  timeout          = 900 # 🔥 FIX: Tambah durasi 15 menit
  
  values = [file("${path.module}/../values/redpanda-console-values.yaml")]
  depends_on = [helm_release.redpanda]
}

# ------------------------------------------------------------------------------
# 8.C. RISINGWAVE DASHBOARD
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 8.D. DEBEZIUM CONNECT (THE WORKER)
# ------------------------------------------------------------------------------
resource "kubernetes_deployment" "debezium" {
  metadata {
    name      = "debezium-connect"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "debezium-connect"
      }
    }
    template {
      metadata {
        labels = {
          app = "debezium-connect"
        }
      }
      spec {
        container {
          name  = "debezium"
          image = "quay.io/debezium/connect:2.4"
          port {
            container_port = 8083
          }
          env {
            name  = "BOOTSTRAP_SERVERS"
            value = "redpanda-0.redpanda.uds-production.svc.cluster.local:9093"
          }
          env {
            name  = "GROUP_ID"
            value = "debezium-cluster"
          }
          env {
            name  = "CONFIG_STORAGE_TOPIC"
            value = "debezium_configs"
          }
          env {
            name  = "OFFSET_STORAGE_TOPIC"
            value = "debezium_offsets"
          }
          env {
            name  = "STATUS_STORAGE_TOPIC"
            value = "debezium_statuses"
          }
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
    selector = {
      app = "debezium-connect"
    }
    port {
      port        = 8083
      target_port = 8083
    }
  }
}

# ------------------------------------------------------------------------------
# 8.E. DEBEZIUM UI (THE CONSOLE)
# ------------------------------------------------------------------------------
resource "kubernetes_deployment" "debezium_ui" {
  metadata {
    name      = "debezium-ui"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "debezium-ui"
      }
    }
    template {
      metadata {
        labels = {
          app = "debezium-ui"
        }
      }
      spec {
        container {
          name  = "debezium-ui"
          image = "quay.io/debezium/debezium-ui:2.4"
          port {
            container_port = 8080
          }
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
    selector = {
      app = "debezium-ui"
    }
    port {
      port        = 80
      target_port = 8080
    }
  }
}

# ------------------------------------------------------------------------------
# 8.F. TEMPORAL UI (EXPLICIT SERVICE)
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 8.G. MLFLOW UI (EXPLICIT SERVICE)
# ------------------------------------------------------------------------------
resource "kubernetes_service" "mlflow_ui_svc" {
  metadata {
    name      = "mlflow-ui-dashboard"
    namespace = kubernetes_namespace.data_stack.metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "mlflow"
    }
    port {
      port        = 5000
      target_port = 5000
    }
  }
}