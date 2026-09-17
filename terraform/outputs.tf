output "vpc_id" { value = aws_vpc.main.id }
output "s3_bucket_name" { value = aws_s3_bucket.app_data.id }