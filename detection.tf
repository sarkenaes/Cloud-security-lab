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

resource "aws_cloudwatch_metric_alarm" "iam-alarm" {
  alarm_name                = "iam-create-user-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "NewIAMCreation"
  namespace                 = "SecurityMetrics"
  period                    = 300
  statistic                 = "Sum"
  threshold                 = 1
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  alarm_description         = "This metric monitors new IAM creation"
  }
resource "aws_cloudwatch_log_metric_filter" "publics3" {
  name           = "PublicS3bucket"
  pattern        = "{$.eventName =\"PutBucketPolicy\"}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name      = "PublicS3Bucket"
    namespace = "SecurityMetrics"
    value     = "1"
  }
}
resource "aws_cloudwatch_metric_alarm" "s3_alarm" {
  alarm_name                = "public-s3"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "PublicS3bucket"
  namespace                 = "SecurityMetrics"
  period                    = 300
  statistic                 = "Sum"
  threshold                 = 1
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  alarm_description         = "This metric monitors public s3 buckets"
  }

  ####Firewall
  resource "aws_cloudwatch_log_metric_filter" "firewall-filter" {
  name           = "firewallfilter"
  pattern        = "{$.eventName =\"AuthorizeSecurityGroupIngress\"}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name      = "firewallfilter"
    namespace = "SecurityMetrics"
    value     = "1"
  }
}
resource "aws_cloudwatch_metric_alarm" "firewall-alarm" {
  alarm_name                = "firewallfilter"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "firewallfilter"
  namespace                 = "SecurityMetrics"
  period                    = 300
  statistic                 = "Sum"
  threshold                 = 1
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  alarm_description         = "This metric monitors any change in the friewall rules"
  }
##Attachingnewpolicytoarole
resource "aws_cloudwatch_log_metric_filter" "newpolicy-filter" {
  name           = "newpolicy"
  pattern        = "{$.eventName =\"AttachRolePolicy\"}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name      = "newpolicy"
    namespace = "SecurityMetrics"
    value     = "1"
  }
}
resource "aws_cloudwatch_metric_alarm" "newpolicy-alarm" {
  alarm_name                = "newpolicy"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "newpolicy"
  namespace                 = "SecurityMetrics"
  period                    = 300
  statistic                 = "Sum"
  threshold                 = 1
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  alarm_description         = "This metric monitors the attachment of new policy to the role"
  }
##IMDS accessed from another device
resource "aws_cloudwatch_log_metric_filter" "IMDS-Metric-filter" {
  name           = "IMDS"
  pattern = "{ ($.userIdentity.type = \"AssumedRole\") && ($.userIdentity.arn = \"*cloud-security-lab-ec2-role*\") && ($.sourceIPAddress != \"${aws_instance.vulnerable.public_ip}\") }"
   log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name
  metric_transformation {
    name      = "IMDS"
    namespace = "SecurityMetrics"
    value     = "1"
  }
}
resource "aws_cloudwatch_metric_alarm" "IMDS-alarm" {
  alarm_name                = "IMDS"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "IMDS"
  namespace                 = "SecurityMetrics"
  period                    = 300
  statistic                 = "Sum"
  threshold                 = 1
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  alarm_description         = "This metric checks if the IMDS has been accessed by any pther device than the EC2"
  }
