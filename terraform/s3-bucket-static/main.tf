provider "aws" {
  region = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "Nome base para o bucket S3 (será prefixado com 'static-site-')"
}

resource "aws_s3_bucket" "static_site_bucket" {
  bucket = "static-site-${var.bucket_name}"
  
  tags = {
    Name        = "Static Site Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "static_site" {
  bucket = aws_s3_bucket.static_site_bucket.id
  
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "static_site" {
  depends_on = [
    aws_s3_bucket_public_access_block.static_site,
    aws_s3_bucket_ownership_controls.static_site
  ]

  bucket = aws_s3_bucket.static_site_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "static_site_policy" {
  depends_on = [aws_s3_bucket_acl.static_site]
  
  bucket = aws_s3_bucket.static_site_bucket.id
  policy = data.aws_iam_policy_document.static_site_policy.json
}

data "aws_iam_policy_document" "static_site_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_site_bucket.arn}/*"]
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.static_site.website_endpoint
}