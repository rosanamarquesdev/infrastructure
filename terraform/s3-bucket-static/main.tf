provider "aws" {
  region = "us-east-1"
}

variable "bucket_name" {
  type = string
}

resource "aws_s3_bucket" "static_site_bucket" {
  bucket = "static-site-${var.bucket_name}"

  object_lock_enabled = false
  tags = {
    Name        = "Static Site Bucket"
    Environment = "Production"
  }

  # lifecycle {
  #   ignore_changes = [
  #     server_side_encryption_configuration,
  #     replication_configuration
  #   ]
  # }
}

resource "aws_s3_bucket_cors_configuration" "static_site_cors" {
  bucket = aws_s3_bucket.static_site_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_website_configuration" "static_site_config" {
  bucket = aws_s3_bucket.static_site_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "static_site_bucket" {
  bucket = aws_s3_bucket.static_site_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "static_site_bucket" {
  bucket = aws_s3_bucket.static_site_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "static_site_bucket" {
  depends_on = [
    aws_s3_bucket_public_access_block.static_site_bucket,
    aws_s3_bucket_ownership_controls.static_site_bucket,
  ]

  bucket = aws_s3_bucket.static_site_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "public_policy" {
  depends_on = [
    aws_s3_bucket_public_access_block.static_site_bucket,
    aws_s3_bucket_ownership_controls.static_site_bucket
  ]

  bucket = aws_s3_bucket.static_site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.static_site_bucket.arn}/*"
      }
    ]
  })
}
