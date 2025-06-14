provider "aws" {
  region = "us-east-1"
}

variable "bucket_name" {
  type = string
}

module "static_site" {
  source      = "./s3-bucket-static"
  bucket_name = var.bucket_name
}

module "core_infra" {
  source = "./infra-core"
}