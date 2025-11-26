# =========================================
# S3 BUCKET FOR MEDICAL DATA STORAGE
# =========================================

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "medical_data" {
  bucket = "${var.s3_bucket_prefix}-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "Medical Data Pipeline Bucket"
    Description = "Stores medical vitals data in Parquet format"
  }
}

# =========================================
# S3 BUCKET VERSIONING
# =========================================

resource "aws_s3_bucket_versioning" "medical_data" {
  bucket = aws_s3_bucket.medical_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# =========================================
# S3 BUCKET ENCRYPTION
# =========================================

resource "aws_s3_bucket_server_side_encryption_configuration" "medical_data" {
  bucket = aws_s3_bucket.medical_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# =========================================
# S3 BUCKET PUBLIC ACCESS BLOCK
# =========================================

resource "aws_s3_bucket_public_access_block" "medical_data" {
  bucket = aws_s3_bucket.medical_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =========================================
# S3 LIFECYCLE POLICY
# =========================================

resource "aws_s3_bucket_lifecycle_configuration" "medical_data" {
  bucket = aws_s3_bucket.medical_data.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    filter {
      prefix = "medical-vitals/"
    }

    transition {
      days          = var.s3_lifecycle_days
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "delete-errors"
    status = "Enabled"


    filter {
      prefix = "errors/"
    }

    expiration {
      days = 30
    }
  }
}
# =========================================
# S3 BUCKET FOLDER STRUCTURE
# =========================================

resource "aws_s3_object" "medical_vitals_folder" {
  bucket = aws_s3_bucket.medical_data.id
  key    = "medical-vitals/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "logs_folder" {
  bucket = aws_s3_bucket.medical_data.id
  key    = "logs/"
  content_type = "application/x-directory"
}