# # =========================================
# # SNS TOPIC FOR ALERTS
# # =========================================

# resource "aws_sns_topic" "medical_alerts" {
#   name         = "${var.project_name}-alerts"
#   display_name = "Medical Vitals Alerts"

#   tags = {
#     Name        = "Medical Alert Topic"
#     Description = "Notifications for critical medical vitals"
#   }
# }

# # =========================================
# # SNS EMAIL SUBSCRIPTION
# # =========================================

# resource "aws_sns_topic_subscription" "alert_email" {
#   topic_arn = aws_sns_topic.medical_alerts.arn
#   protocol  = "email"
#   endpoint  = var.alert_email
# }

# # =========================================
# # CLOUDWATCH LOG METRIC FILTER - HIGH HEART RATE
# # =========================================

# resource "aws_cloudwatch_log_metric_filter" "high_heart_rate" {
#   name           = "${var.project_name}-high-heart-rate"
#   log_group_name = aws_cloudwatch_log_group.firehose_logs.name
#   pattern        = "[time, request_id, event_type, patient_id, heart_rate > 150, ...]"

#   metric_transformation {
#     name      = "HighHeartRateCount"
#     namespace = var.project_name
#     value     = "1"
#   }
# }

# # =========================================
# # CLOUDWATCH ALARM - HIGH HEART RATE
# # =========================================

# resource "aws_cloudwatch_metric_alarm" "high_heart_rate_alarm" {
#   alarm_name          = "${var.project_name}-high-heart-rate"
#   alarm_description   = "Alert when heart rate exceeds ${var.heart_rate_threshold}"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "HighHeartRateCount"
#   namespace           = var.project_name
#   period              = 60
#   statistic           = "Sum"
#   threshold           = 0
#   treat_missing_data  = "notBreaching"

#   alarm_actions = [aws_sns_topic.medical_alerts.arn]

#   tags = {
#     Name = "High Heart Rate Alarm"
#   }
# }

# # =========================================
# # CLOUDWATCH LOG METRIC FILTER - LOW SPO2
# # =========================================

# resource "aws_cloudwatch_log_metric_filter" "low_spo2" {
#   name           = "${var.project_name}-low-spo2"
#   log_group_name = aws_cloudwatch_log_group.firehose_logs.name
#   pattern        = "[time, request_id, event_type, patient_id, heart_rate, spo2 < 88, ...]"

#   metric_transformation {
#     name      = "LowSpO2Count"
#     namespace = var.project_name
#     value     = "1"
#   }
# }

# # =========================================
# # CLOUDWATCH ALARM - LOW SPO2
# # =========================================

# resource "aws_cloudwatch_metric_alarm" "low_spo2_alarm" {
#   alarm_name          = "${var.project_name}-low-spo2"
#   alarm_description   = "Alert when SpO2 drops below ${var.spo2_threshold}"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "LowSpO2Count"
#   namespace           = var.project_name
#   period              = 60
#   statistic           = "Sum"
#   threshold           = 0
#   treat_missing_data  = "notBreaching"

#   alarm_actions = [aws_sns_topic.medical_alerts.arn]

#   tags = {
#     Name = "Low SpO2 Alarm"
#   }
# }

# # =========================================
# # CLOUDWATCH ALARM - KINESIS ITERATOR AGE
# # =========================================

# resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age" {
#   alarm_name          = "${var.project_name}-kinesis-iterator-age"
#   alarm_description   = "Alert when Kinesis iterator age is too high (data processing lag)"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "GetRecords.IteratorAgeMilliseconds"
#   namespace           = "AWS/Kinesis"
#   period              = 300
#   statistic           = "Maximum"
#   threshold           = 60000 # 1 minute in milliseconds
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     StreamName = aws_kinesis_stream.medical_stream.name
#   }

#   alarm_actions = [aws_sns_topic.medical_alerts.arn]

#   tags = {
#     Name = "Kinesis Processing Lag Alarm"
#   }
# }

# # =========================================
# # CLOUDWATCH ALARM - FIREHOSE DELIVERY ERRORS
# # =========================================

# resource "aws_cloudwatch_metric_alarm" "firehose_delivery_errors" {
#   alarm_name          = "${var.project_name}-firehose-errors"
#   alarm_description   = "Alert on Firehose delivery failures"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "DeliveryToS3.DataFreshness"
#   namespace           = "AWS/Firehose"
#   period              = 300
#   statistic           = "Maximum"
#   threshold           = 900 # 15 minutes
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     DeliveryStreamName = aws_kinesis_firehose_delivery_stream.medical_to_s3.name
#   }

#   alarm_actions = [aws_sns_topic.medical_alerts.arn]

#   tags = {
#     Name = "Firehose Delivery Error Alarm"
#   }
# }

# # =========================================
# # CLOUDWATCH DASHBOARD
# # =========================================

# resource "aws_cloudwatch_dashboard" "medical_pipeline" {
#   dashboard_name = "${var.project_name}-dashboard"

#   dashboard_body = jsonencode({
#     widgets = [
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/Kinesis", "IncomingRecords", { stat = "Sum", label = "Incoming Records" }],
#             [".", "IncomingBytes", { stat = "Sum", label = "Incoming Bytes" }]
#           ]
#           period = 300
#           stat   = "Sum"
#           region = var.aws_region
#           title  = "Kinesis Stream Metrics"
#         }
#       },
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/Firehose", "DeliveryToS3.Records", { stat = "Sum" }],
#             [".", "DeliveryToS3.DataFreshness", { stat = "Average" }]
#           ]
#           period = 300
#           stat   = "Average"
#           region = var.aws_region
#           title  = "Firehose Delivery Metrics"
#         }
#       },
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             [var.project_name, "HighHeartRateCount", { stat = "Sum" }],
#             [".", "LowSpO2Count", { stat = "Sum" }]
#           ]
#           period = 300
#           stat   = "Sum"
#           region = var.aws_region
#           title  = "Medical Alerts"
#         }
#       }
#     ]
#   })
# }