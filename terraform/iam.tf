# =========================================
# IAM ROLE FOR KINESIS FIREHOSE
# =========================================

resource "aws_iam_role" "firehose_role" {
  name = "${var.project_name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "Firehose Service Role"
  }
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "${var.project_name}-firehose-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KinesisRead"
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.medical_stream.arn
      },
      {
        Sid    = "S3Write"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.medical_data.arn,
          "${aws_s3_bucket.medical_data.arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.firehose_logs.arn}:*"
      },
      {
        Sid      = "GlueRead"
        Effect   = "Allow"
        Action   = ["glue:GetTable", "glue:GetDatabase"]
        Resource = "*"
      }
    ]
  })
}

# =========================================
# IAM USER FOR KAFKA CONNECT
# =========================================

resource "aws_iam_user" "kafka_kinesis_user" {
  name = "${var.project_name}-kafka-user"

  tags = {
    Name = "Kafka Connect User"
  }
}

resource "aws_iam_user_policy" "kafka_kinesis_policy" {
  name = "${var.project_name}-kafka-policy"
  user = aws_iam_user.kafka_kinesis_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "KinesisWrite"
      Effect = "Allow"
      Action = [
        "kinesis:PutRecord",
        "kinesis:PutRecords",
        "kinesis:DescribeStream"
      ]
      Resource = aws_kinesis_stream.medical_stream.arn
    }]
  })
}

# =========================================
# ACCESS KEYS FOR KAFKA
# =========================================

resource "aws_iam_access_key" "kafka_user_key" {
  user = aws_iam_user.kafka_kinesis_user.name
}

# =========================================
# STORE IN SSM
# =========================================

resource "aws_ssm_parameter" "kafka_access_key_id" {
  name  = "/${var.project_name}/kafka/access_key_id"
  type  = "SecureString"
  value = aws_iam_access_key.kafka_user_key.id
}

resource "aws_ssm_parameter" "kafka_secret_access_key" {
  name  = "/${var.project_name}/kafka/secret_access_key"
  type  = "SecureString"
  value = aws_iam_access_key.kafka_user_key.secret
}