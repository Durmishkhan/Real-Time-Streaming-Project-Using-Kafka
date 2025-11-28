# =========================================
# IAM ROLE FOR LAMBDA
# =========================================

resource "aws_iam_role" "lambda_s3_redshift_role" {
  name = "${var.project_name}-lambda-s3-redshift-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "Lambda S3 to Redshift Role"
  }
}

# =========================================
# IAM POLICY FOR LAMBDA
# =========================================

resource "aws_iam_role_policy" "lambda_s3_redshift_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_s3_redshift_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RedshiftDataAPIAccess"
        Effect = "Allow"
        Action = [
          "redshift-data:ExecuteStatement",
          "redshift-data:DescribeStatement",
          "redshift-data:GetStatementResult"
        ]
        Resource = "*"
      },
      {
        Sid    = "RedshiftServerlessAccess"
        Effect = "Allow"
        Action = [
          "redshift-serverless:GetWorkgroup",
          "redshift-serverless:GetNamespace"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.medical_data.arn,
          "${aws_s3_bucket.medical_data.arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        "Sid"    = "VPCAccess",
        "Effect" = "Allow",
        "Action" = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups"
        ],
        "Resource" = "*"
      }
    ]
  })
}
# =========================================
# LAMBDA FUNCTION
# =========================================
resource "aws_lambda_function" "s3_to_redshift" {
  filename         = "../lambda_function.zip"
  function_name    = "${var.project_name}-s3-to-redshift"
  role             = aws_iam_role.lambda_s3_redshift_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 600

  environment {
    variables = {
      REDSHIFT_WORKGROUP = aws_redshiftserverless_workgroup.medical_workgroup.workgroup_name
      REDSHIFT_DATABASE  = var.redshift_database_name
      S3_BUCKET          = aws_s3_bucket.medical_data.bucket
      REDSHIFT_ROLE_ARN  = tolist(aws_redshiftserverless_namespace.medical_namespace.iam_roles)[0]
    }
  }
}





resource "aws_cloudwatch_event_rule" "hourly_s3_to_redshift" {
  name                = "${var.project_name}-hourly-s3-to-redshift"
  description         = "Trigger Lambda to copy S3 data to Redshift every hour"
  schedule_expression = "cron(5 * * * ? *)"  # Every hour at :05 (5 mins after Firehose writes)

  tags = {
    Name = "Hourly S3 to Redshift Trigger"
  }
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.hourly_s3_to_redshift.name
  target_id = "LambdaFunction"
  arn       = aws_lambda_function.s3_to_redshift.arn
}

# =========================================
# LAMBDA PERMISSION FOR EVENTBRIDGE
# =========================================

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_redshift.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly_s3_to_redshift.arn
}