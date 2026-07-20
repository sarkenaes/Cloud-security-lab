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
}