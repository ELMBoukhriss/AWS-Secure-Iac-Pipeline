resource "aws_s3_bucket" "app_data" {
  bucket = "${var.project}-app-data-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project}-app-data" }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket                  = aws_s3_bucket.app_data.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}