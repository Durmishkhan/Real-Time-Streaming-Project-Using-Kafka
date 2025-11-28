# =========================================
# CORE CONFIGURATION
# =========================================

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name (used in resource naming)"
  type        = string
  default     = "healthcare-pipeline"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# =========================================
# KINESIS CONFIGURATION
# =========================================

variable "kinesis_stream_name" {
  description = "Kinesis Data Stream name"
  type        = string
  default     = "medical_realtime_stream"
}

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis stream"
  type        = number
  default     = 2
}

variable "kinesis_retention_hours" {
  description = "Data retention in hours (24-8760)"
  type        = number
  default     = 24
}

# =========================================
# S3 CONFIGURATION
# =========================================

variable "s3_bucket_prefix" {
  description = "S3 bucket name prefix (will append random suffix)"
  type        = string
  default     = "medical-data-pipeline"
}

variable "s3_lifecycle_days" {
  description = "Days before moving to Glacier"
  type        = number
  default     = 90
}

# =========================================
# FIREHOSE CONFIGURATION
# =========================================

variable "firehose_buffer_size" {
  description = "Buffer size in MB (1-128)"
  type        = number
  default     = 5
}

variable "firehose_buffer_interval" {
  description = "Buffer interval in seconds (60-3600)"
  type        = number
  default     = 3600  # 1 hour as per requirements
}

variable "enable_parquet_conversion" {
  description = "Enable Parquet conversion (requires Glue)"
  type        = bool
  default     = false
}

# =========================================
# REDSHIFT CONFIGURATION
# =========================================

variable "redshift_admin_username" {
  description = "Redshift admin username"
  type        = string
  default     = "admin"
}

variable "redshift_admin_password" {
  description = "Redshift admin password (min 8 chars, uppercase, lowercase, number)"
  type        = string
  sensitive   = true
}

variable "redshift_database_name" {
  description = "Redshift database name"
  type        = string
  default     = "medical_db"
}

variable "redshift_base_capacity" {
  description = "Redshift Serverless base capacity (32-512 RPU)"
  type        = number
  default     = 32
}

# =========================================
# CLOUDWATCH ALARMS (OPTIONAL - Phase 2)
# =========================================

variable "alert_email" {
  description = "Email for CloudWatch alerts (optional for Phase 1)"
  type        = string
  default     = ""  # Make it optional
}

variable "heart_rate_threshold" {
  description = "Heart rate threshold for alerts"
  type        = number
  default     = 150
}

variable "spo2_threshold" {
  description = "SpO2 threshold for alerts"
  type        = number
  default     = 88
}