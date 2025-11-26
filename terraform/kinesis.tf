# =========================================
# KINESIS DATA STREAM
# =========================================

resource "aws_kinesis_stream" "medical_stream" {
  name              = var.kinesis_stream_name
  shard_count       = var.kinesis_shard_count
  retention_period  = var.kinesis_retention_hours

  shard_level_metrics = [
    "IncomingBytes",
    "IncomingRecords",
    "OutgoingBytes",
    "OutgoingRecords",
  ]

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Name        = "Medical Realtime Stream"
    Description = "Receives real-time medical vitals data from Kafka"
  }
}

# =========================================
# CLOUDWATCH LOG GROUP FOR FIREHOSE
# =========================================

resource "aws_cloudwatch_log_group" "firehose_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "Firehose Delivery Logs"
  }
}

resource "aws_cloudwatch_log_stream" "firehose_log_stream" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose_logs.name
}

# =========================================
# KINESIS FIREHOSE DELIVERY STREAM
# =========================================

resource "aws_kinesis_firehose_delivery_stream" "medical_to_s3" {
  name        = "${var.project_name}-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.medical_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.medical_data.arn

    buffering_size     = var.firehose_buffer_size
    buffering_interval = var.firehose_buffer_interval

    # S3 Prefix with partitioning by time
    prefix              = "medical-vitals/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    
    # Parquet handles its own compression via parquet_ser_de
    compression_format = var.enable_parquet_conversion ? "UNCOMPRESSED" : "GZIP"

    # CloudWatch Logging
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_log_stream.name
    }

    # Data Format Conversion (Parquet)
    dynamic "data_format_conversion_configuration" {
      for_each = var.enable_parquet_conversion ? [1] : []

      content {
        input_format_configuration {
          deserializer {
            open_x_json_ser_de {}
          }
        }

        output_format_configuration {
          serializer {
            parquet_ser_de {
              compression = "SNAPPY"
            }
          }
        }

        schema_configuration {
          database_name = aws_glue_catalog_database.medical_db[0].name
          table_name    = aws_glue_catalog_table.medical_vitals[0].name
          role_arn      = aws_iam_role.firehose_role.arn
        }
      }
    }
  }

  tags = {
    Name        = "Medical Data Firehose"
    Description = "Delivers data from Kinesis to S3"
  }

  depends_on = [
    aws_iam_role_policy.firehose_policy
  ]
}

# =========================================
# GLUE DATABASE (for Parquet conversion)
# =========================================

resource "aws_glue_catalog_database" "medical_db" {
  count = var.enable_parquet_conversion ? 1 : 0
  name  = "${var.project_name}_database"

  description = "Database for medical vitals data"
}

# =========================================
# GLUE TABLE SCHEMA (for Parquet)
# =========================================

resource "aws_glue_catalog_table" "medical_vitals" {
  count         = var.enable_parquet_conversion ? 1 : 0
  name          = "medical_vitals"
  database_name = aws_glue_catalog_database.medical_db[0].name

  table_type = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.medical_data.bucket}/medical-vitals/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "patient_id"
      type = "string"
    }

    columns {
      name = "patient_name"
      type = "string"
    }

    columns {
      name = "age"
      type = "int"
    }

    columns {
      name = "gender"
      type = "string"
    }

    columns {
      name = "hospital_id"
      type = "string"
    }

    columns {
      name = "hospital_name"
      type = "string"
    }

    columns {
      name = "room_number"
      type = "int"
    }

    columns {
      name = "device_id"
      type = "string"
    }

    columns {
      name = "device_type"
      type = "string"
    }

    columns {
      name = "department"
      type = "string"
    }

    columns {
      name = "heart_rate"
      type = "int"
    }

    columns {
      name = "spo2"
      type = "int"
    }

    columns {
      name = "bp_sys"
      type = "int"
    }

    columns {
      name = "bp_dia"
      type = "int"
    }

    columns {
      name = "temp"
      type = "double"
    }

    columns {
      name = "resp_rate"
      type = "int"
    }

    columns {
      name = "blood_sugar"
      type = "double"
    }

    columns {
      name = "oxygen_flow_rate"
      type = "double"
    }

    columns {
      name = "ecg_lead_ii"
      type = "double"
    }

    columns {
      name = "timestamp"
      type = "string"
    }

    columns {
      name = "event_type"
      type = "string"
    }

    columns {
      name = "alert_flag"
      type = "int"
    }

    columns {
      name = "ingestion_time"
      type = "string"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
}