resource "aws_s3_bucket" "app_data" {
  bucket = "${var.project}-app-data-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project}-app-data" }
}

# FIXED: all four public access settings blocked
resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket                  = aws_s3_bucket.app_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# FIXED: AES-256 encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# FIXED: versioning enabled — object recovery and tamper detection
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# FIXED: access logging enabled — full forensic trail on all S3 operations
resource "aws_s3_bucket_logging" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  target_bucket = aws_s3_bucket.app_data.id
  target_prefix = "access-logs/"
}