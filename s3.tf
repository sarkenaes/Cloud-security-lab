resource "aws_s3_bucket" "vulnerable_s3_bucket" {
  bucket = "cloud-security-lab-vulnerable-saron"

  tags={
    Name ="${var.project_name}-vulnerable-s3"
    Project =var.project_name

  }
  }
 
resource "aws_s3_bucket_public_access_block" "vulnerable_policy" {
  bucket = aws_s3_bucket.vulnerable_s3_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  }
resource "aws_s3_bucket_policy" "vulnerable_policy" {
  bucket = aws_s3_bucket.vulnerable_s3_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.vulnerable_s3_bucket.arn}/*"
    }]
  })
}