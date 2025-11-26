output "kinesis_stream_name" {
  description = "Kinesis Stream Name"
  value       = aws_kinesis_stream.medical_stream.name
}

output "kinesis_stream_arn" {
  description = "Kinesis Stream ARN"
  value       = aws_kinesis_stream.medical_stream.arn
}

output "s3_bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.medical_data.bucket
}

output "s3_bucket_arn" {
  description = "S3 Bucket ARN"
  value       = aws_s3_bucket.medical_data.arn
}

output "firehose_delivery_stream_name" {
  description = "Firehose Delivery Stream Name"
  value       = aws_kinesis_firehose_delivery_stream.medical_to_s3.name
}

output "firehose_delivery_stream_arn" {
  description = "Firehose Delivery Stream ARN"
  value       = aws_kinesis_firehose_delivery_stream.medical_to_s3.arn
}

# output "sns_topic_arn" {
#   description = "SNS Topic ARN for Alerts"
#   value       = aws_sns_topic.medical_alerts.arn
# }

# output "cloudwatch_dashboard_url" {
#   description = "CloudWatch Dashboard URL"
#   value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.medical_pipeline.dashboard_name}"
# }

# =========================================
# SENSITIVE OUTPUTS (Kafka User Credentials)
# =========================================

output "kafka_user_access_key_id" {
  description = "Kafka User Access Key ID"
  value       = aws_iam_access_key.kafka_user_key.id
  sensitive   = false
}

output "kafka_user_secret_access_key" {
  description = "Kafka User Secret Access Key (Sensitive)"
  value       = aws_iam_access_key.kafka_user_key.secret
  sensitive   = true
}

output "kafka_user_credentials_ssm_path" {
  description = "SSM Parameter Store path for Kafka credentials"
  value       = "Access Key: /${var.project_name}/kafka/access_key_id, Secret Key: /${var.project_name}/kafka/secret_access_key"
}

# =========================================
# GLUE DATABASE (if Parquet enabled)
# =========================================

output "glue_database_name" {
  description = "Glue Database Name (for Parquet conversion)"
  value       = var.enable_parquet_conversion ? aws_glue_catalog_database.medical_db[0].name : "N/A (Parquet disabled)"
}

output "glue_table_name" {
  description = "Glue Table Name (for Parquet conversion)"
  value       = var.enable_parquet_conversion ? aws_glue_catalog_table.medical_vitals[0].name : "N/A (Parquet disabled)"
}

# =========================================
# CONNECTION DETAILS FOR KAFKA CONNECT
# =========================================

output "kafka_connect_configuration" {
  description = "Configuration details for Kafka Connect"
  value = {
    kinesis_stream        = aws_kinesis_stream.medical_stream.name
    aws_region            = var.aws_region
    access_key_id         = aws_iam_access_key.kafka_user_key.id
    s3_bucket             = aws_s3_bucket.medical_data.bucket
    firehose_stream       = aws_kinesis_firehose_delivery_stream.medical_to_s3.name
  }
}

# =========================================
# RESOURCE SUMMARY
# =========================================

output "resource_summary" {
  description = "Summary of created resources"
  value = {
    kinesis_stream  = aws_kinesis_stream.medical_stream.name
    s3_bucket       = aws_s3_bucket.medical_data.bucket
    firehose_stream = aws_kinesis_firehose_delivery_stream.medical_to_s3.name
    # sns_topic       = aws_sns_topic.medical_alerts.name
    # cloudwatch_logs = aws_cloudwatch_log_group.firehose_logs.name
    iam_user        = aws_iam_user.kafka_kinesis_user.name
  }
}