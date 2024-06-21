variable "name"                 { }
variable "lb_tg_http_arn"       { }
variable "alb_dns_name"         { }
variable "lb_tg_https_arn"      { default = null}

locals {
  resources_iam_policy_document =  var.lb_tg_https_arn !=null ?  [ var.lb_tg_http_arn,  var.lb_tg_https_arn ]: [var.lb_tg_http_arn]
}

resource "random_integer" "bucket_subfix" {
  min     = 10000
  max     = 99999  
}

resource "aws_s3_bucket" "internal_alb_static_ips" {
  bucket = "internal-alb-static-ips-${var.name}-${random_integer.bucket_subfix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "internal_alb_static_ips_lifecycle" {
  bucket = aws_s3_bucket.internal_alb_static_ips.id
  rule {
    id = "rule-1"
    noncurrent_version_expiration {
     noncurrent_days = 1
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "internal_alb_static_ips_versioning" {
  bucket = aws_s3_bucket.internal_alb_static_ips.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nlb_tg_to_alb_lambda" {
  name = "${var.name}-nlb-tg-to-alb-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "nlb_tg_to_alb_lambda" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.internal_alb_static_ips.arn}/*"]
  }
  statement {
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]
    resources = local.resources_iam_policy_document       
      //aws_lb_target_group.nlb_80.arn,
      // aws_lb_target_group.nlb_443.arn,
  }
  statement {
    actions = ["elasticloadbalancing:DescribeTargetHealth"]
    resources = ["*"]
  }
  statement {
    actions = ["cloudwatch:putMetricData"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "nlb_tg_to_alb_lambda" {
  role = aws_iam_role.nlb_tg_to_alb_lambda.name
  policy = data.aws_iam_policy_document.nlb_tg_to_alb_lambda.json
}

locals {
  alb_static_ips_lambda_zip_path = "${path.module}/package/nlb-tg-to-alb-lambda.zip"
}


resource "aws_lambda_function" "nlb_tg_to_alb_80" {
  filename = local.alb_static_ips_lambda_zip_path
  function_name = "${var.name}-nlb-tg-to-alb-80"
  role = aws_iam_role.nlb_tg_to_alb_lambda.arn
  handler = "populate_NLB_TG_with_ALB.lambda_handler"

  source_code_hash = filebase64sha256(local.alb_static_ips_lambda_zip_path)

  runtime = "python3.8"
  memory_size = 128
  timeout = 300

  environment {
    variables = {
      ALB_DNS_NAME = var.alb_dns_name //aws_lb.internal.dns_name
      ALB_LISTENER = "80"
      S3_BUCKET = aws_s3_bucket.internal_alb_static_ips.id
      NLB_TG_ARN =  var.lb_tg_http_arn
      MAX_LOOKUP_PER_INVOCATION = 50
      INVOCATIONS_BEFORE_DEREGISTRATION = 10
      CW_METRIC_FLAG_IP_COUNT = true
    }
  }
}


resource "aws_lambda_function" "nlb_tg_to_alb_443" {
  count = var.lb_tg_https_arn != null ? 1 : 0

  filename = local.alb_static_ips_lambda_zip_path
  function_name = "nlb-tg-to-alb-443"
  role = aws_iam_role.nlb_tg_to_alb_lambda.arn
  handler = "populate_NLB_TG_with_ALB.lambda_handler"

  source_code_hash = filebase64sha256(local.alb_static_ips_lambda_zip_path)

  runtime = "python3.8"
  memory_size = 128
  timeout = 300

  environment {
    variables = {
      ALB_DNS_NAME =  var.alb_dns_name
      ALB_LISTENER = "443"
      S3_BUCKET = aws_s3_bucket.internal_alb_static_ips.id
      NLB_TG_ARN =  var.lb_tg_https_arn
      MAX_LOOKUP_PER_INVOCATION = 50
      INVOCATIONS_BEFORE_DEREGISTRATION = 10
      CW_METRIC_FLAG_IP_COUNT = true
    }
  }
}


resource "aws_cloudwatch_event_rule" "nlb_tg_to_alb_cron" {
  name = "${var.name}-nlb-tg-to-alb-cron"
  schedule_expression = "rate(5 minutes)"
  is_enabled = true
}

resource "aws_cloudwatch_event_target" "nlb_tg_to_alb_cron_80" {
  rule = aws_cloudwatch_event_rule.nlb_tg_to_alb_cron.name
  target_id = "TriggerStaticPort80"
  arn = aws_lambda_function.nlb_tg_to_alb_80.arn
}


resource "aws_cloudwatch_event_target" "nlb_tg_to_alb_cron_443" {
  count = var.lb_tg_https_arn != null ? 1 : 0

  rule = aws_cloudwatch_event_rule.nlb_tg_to_alb_cron.name
  target_id = "TriggerStaticPort443"
  arn = aws_lambda_function.nlb_tg_to_alb_443[0].arn
}


resource "aws_lambda_permission" "allow_cloudwatch_80" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nlb_tg_to_alb_80.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.nlb_tg_to_alb_cron.arn
}


resource "aws_lambda_permission" "allow_cloudwatch_443" {
  count = var.lb_tg_https_arn != null ? 1 : 0

  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nlb_tg_to_alb_443[0].function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.nlb_tg_to_alb_cron.arn
}

