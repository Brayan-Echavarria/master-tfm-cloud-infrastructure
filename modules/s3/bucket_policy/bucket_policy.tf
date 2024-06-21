// Módulo terraform para crear Bucket Policy

variable "origins"                    { default = [] }
variable "buckets"                    { default = [] }
variable "oai_arn"                    { default = null }
// Politica para Cloudfront OAI
data "aws_iam_policy_document" "cloudfront_origin" {

  statement {
    sid = "S3GetObjectForCloudFront"

    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::$${bucket_name}$${origin_path}*"]

    principals {
      type        = "AWS"
      identifiers = ["$${cloudfront_origin_access_identity_iam_arn}"]
    }
  }

  statement {
    sid = "S3ListBucketForCloudFront"

    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::$${bucket_name}"]

    principals {
      type        = "AWS"
      identifiers = ["$${cloudfront_origin_access_identity_iam_arn}"]
    }
  }
}

// Politica para Se como Web Site

resource "random_password" "referer" {
  length  = 32
  special = false
}

data "aws_iam_policy_document" "cloudfront_origin_website" {

  statement {
    sid = "S3GetObjectForCloudFront"

    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::$${bucket_name}$${origin_path}*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "cloudfront_origin_website_pass" {

  statement {
    sid = "S3GetObjectForCloudFront"

    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::$${bucket_name}$${origin_path}*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:referer"
      values   = [random_password.referer.result]
    }

  }
}

data "template_file" "policy_s3" {
  for_each = {
    for o in var.origins:
    o.origin_id => o
    if o.tipo != "custom"
  }
  template = each.value.tipo == "s3" ? data.aws_iam_policy_document.cloudfront_origin.json : (each.value.tipo == "web" ? data.aws_iam_policy_document.cloudfront_origin_website.json : data.aws_iam_policy_document.cloudfront_origin_website_pass.json)

  vars = {
    origin_path                               = coalesce(try(each.value.origin_path, ""), "/")
    bucket_name                               = each.value.origin_bucket
    cloudfront_origin_access_identity_iam_arn = each.value.tipo == "web"? "" : tostring(var.oai_arn)
  }
}

resource "aws_s3_bucket_policy" "policy_s3" {
  for_each = data.template_file.policy_s3

  bucket = lookup(each.value.vars, "bucket_name")
  policy = each.value.rendered
  depends_on = [ data.template_file.policy_s3 ]
}

resource "aws_s3_bucket_public_access_block" "origin" {
  for_each = {
    for o in var.origins:
    o.tipo => o
    if o.tipo == "s3"
  }
  bucket                  = each.value.origin_bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "bucket_policy_s3" {
  count = length(var.buckets)

  bucket = lookup(element(var.buckets, count.index), "bucket")
  policy = jsonencode(lookup(element(var.buckets, count.index), "policy"))
}