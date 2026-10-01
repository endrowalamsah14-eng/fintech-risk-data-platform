# ==============================================================================
# ZONE 4: ARCHIVE SINK & ANALYTICS WAREHOUSE (GCP)
# ==============================================================================

# 1. GCS Bronze Zone (Raw JSON CDC Archive)
resource "google_storage_bucket" "bronze_zone" {
  name          = "uds-bronze-zone-cdc-archive"
  location      = "ASIA-SOUTHEAST1"
  force_destroy = true # FinOps: Allow forceful deletion

  lifecycle_rule {
    condition {
      age = 30 # Delete raw logs after 30 days
    }
    action {
      type = "Delete"
    }
  }
}

# 2. GCS Gold Zone (Iceberg Data Lakehouse)
resource "google_storage_bucket" "gold_zone" {
  name          = "uds-gold-zone-iceberg"
  location      = "ASIA-SOUTHEAST1"
  force_destroy = true
}

# 3. Google BigQuery Dataset
resource "google_bigquery_dataset" "analytics_dwh" {
  dataset_id                  = "emarket_bigdata_dwh"
  friendly_name               = "Production Data Warehouse"
  description                 = "DWH for heavy modeling and ML validation via dbt"
  location                    = "ASIA-SOUTHEAST1"
  delete_contents_on_destroy  = true
}

# 4. BigQuery External Table (Zero Egress from Gold Zone)
resource "google_bigquery_table" "transactions_external" {
  dataset_id = google_bigquery_dataset.analytics_dwh.dataset_id
  table_id   = "ext_transactions_iceberg"

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET" # Assuming Iceberg data files are Parquet
    source_uris   = ["gs://${google_storage_bucket.gold_zone.name}/transactions/*"]
  }
}