# =========================================
# SNS TOPIC + EMAIL (მეილი მიიღებ)
# =========================================
resource "aws_sns_topic" "critical_vitals_alert" {
  name = "${var.project_name}-critical-vitals"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.critical_vitals_alert.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# =========================================
# CLOUDWATCH LOG METRIC FILTER
# =========================================
resource "aws_cloudwatch_log_metric_filter" "critical_vitals" {
  name           = "${var.project_name}-critical-vitals-filter"
  log_group_name = aws_cloudwatch_log_group.firehose_logs.name
  pattern        = "{ ($.heart_rate > ${var.heart_rate_threshold}) || ($.spo2 < ${var.spo2_threshold}) }"

  metric_transformation {
    name          = "CriticalVitalsCount"
    namespace     = var.project_name
    value         = "1"
    default_value = "0"
  }
}

# ========================================
# CLOUDWATCH ALARM 
# =========================================
resource "aws_cloudwatch_metric_alarm" "critical_vitals_alarm" {
  alarm_name          = "${var.project_name}-critical-vitals-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CriticalVitalsCount"
  namespace           = var.project_name
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert: Patient has heart_rate > ${var.heart_rate_threshold} or spo2 < ${var.spo2_threshold}"
  alarm_actions       = [aws_sns_topic.critical_vitals_alert.arn]
  treat_missing_data  = "notBreaching"

  tags = {
    Purpose = "Real-time Critical Vitals Monitoring"
  }
}