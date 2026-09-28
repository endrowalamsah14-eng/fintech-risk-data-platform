# Tarik identitas Akun AWS lu otomatis dari kredensial di terminal
data "aws_caller_identity" "current" {}

# ==============================================================================
# AWS INFRASTRUCTURE - THE STORAGE LAYER (ZONA 3)
# ==============================================================================

# 1. S3 BUCKET (GUDANG ABADI ICEBERG - PENGGANTI MINIO & GCS)
resource "aws_s3_bucket" "datalake" {
  bucket        = "uds-enterprise-datalake-2026"
  force_destroy = true
}

# Opsional: Auto-delete files di folder temporary buat hemat cost
resource "aws_s3_bucket_lifecycle_configuration" "datalake_lifecycle" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    id     = "auto-delete-tmp-files"
    status = "Enabled"

    filter {
      prefix = "tmp/"
    }

    expiration {
      days = 7
    }
  }
}

# 2. GLUE DATA CATALOG (SERVERLESS METASTORE)
# Ini pengganti BigQuery Dataset lu. Tempat StarRocks & dbt ngebaca metadata tabel Iceberg.
resource "aws_glue_catalog_database" "iceberg_db" {
  name        = "uds_silver_layer"
  description = "Cleaned Iceberg data ready for StarRocks and dbt queries"
  
  # 🔥 PERBAIKAN: Masukin Account ID secara dinamis biar kaga error 400 lagi
  catalog_id  = data.aws_caller_identity.current.account_id
}