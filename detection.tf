resource "aws_s3_bucket" "cloudtrail_logs"{
bucket="saron-cloudtrail-logs"
  force_destroy = true
tags ={
    Name= "${var.project_name}-cloudtrail-logs"
    Project = var.project_name
}
}
#Allows Cloudtrail to write things into this bucket
resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}"
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/686271800818/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
resource "aws_cloudtrail" "cloud-trail" {
  depends_on = [aws_s3_bucket_policy.cloudtrail_policy]
  name= "${var.project_name}-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail =true
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn=aws_iam_role.cloudtrail_cloudwatch.arn

}

resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name ="/aws/cloudtrail/${var.project_name}"
  retention_in_days =90
}
#allows cloudtrail to assume this role
resource "aws_iam_role" "cloudtrail_cloudwatch"{
name ="${var.project_name}-cloudtrail-cw-role"
assume_role_policy =jsonencode({
  Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
})
}
#attaches policy to the role to stream logs into it 
resource "aws_iam_role_policy" "cloudtrail_cloudwatch_policy"{
  name ="${var.project_name}-cloudtrail-cw-policy"
  role=aws_iam_role.cloudtrail_cloudwatch.id
  policy =jsonencode({
      Version ="2012-10-17"
      Statement=[{
        Effect ="Allow"
        Action =[
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
      }]

  })
}
resource "aws_sns_topic" "security_alerts"{
  name="${var.project_name}-security-alerts"
}
resource "aws_sns_topic_subscription" "security_alerts_emails" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = "saronketema7@gmail.com"
}
resource "aws_cloudwatch_log_metric_filter" "iam" {
  name           = "NewIAMCreation"
  pattern        = "{$.eventName =\"CreateUser\"}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name      = "NewIAMCreation"
    namespace = "SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "foobar" {
  alarm_name                = "iam-create-user-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = NewIAMCreation"
  namespace                 = "SecurityMetrics"
  period                    = 300
  statistic                 = "Sum"
  threshold                 = 1
  alarm_description         = "This metric monitors new IAM creation"
  alarm_actions             = [aws_sns_topic.security_alerts.arn]
}
