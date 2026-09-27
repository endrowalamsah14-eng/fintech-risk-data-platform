# ==============================================================================
# AWS INFRASTRUCTURE - THE STORAGE LAYER (ZONA 3)
# ==============================================================================

# 1. S3 BUCKET (GUDANG ABADI ICEBERG - PENGGANTI MINIO & GCS)
resource "aws_s3_bucket" "datalake" {
  bucket        = "uds-enterprise-datalake-2026" # Nama bucket S3 harus unik sedunia
  force_destroy = true                           # Biar gampang dihapus pas terraform destroy
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
}