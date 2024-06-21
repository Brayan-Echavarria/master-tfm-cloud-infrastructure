variable "name"                 { default = "lambda" }
variable "tags"                 {}
variable "s3_bucket"            { default = null}
variable "s3_key"               { default = null}
variable "function_name"        {}
variable "runtime"              { default = "nodejs14.x" }
variable "handler"              { default = "main.handler" }
variable "custom_policy"        { default = [] }
variable "environment"          { default = {} }    
variable "subnets"              { default = [] }
variable "sg_ids"               { default = [] }
variable "timeout"              { default = null }
variable "memory_size"          { default = 128 }
variable "publish"              { default = false }
variable "layers" { 
  default = [] 
  type    = list(string)
}

variable "reserved_concurrent_executions" { default = -1 }

locals {
  new_custom_policy = setunion(var.custom_policy, [
    {
      name = "NetworkLambda-policy"
      policy = {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:CreateNetworkInterface",
                "ec2:AttachNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
          }
        ]
      }
    }
  ])

  custom_policy = var.subnets == [] ? var.custom_policy : local.new_custom_policy
}

# IAM role which dictates what other AWS services the Lambda function
resource "aws_iam_role" "lambda_exec" {
   name = "role-${var.name}-${var.function_name}"
   assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["apigateway.amazonaws.com","lambda.amazonaws.com","events.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "custom_policy" {
  for_each = {
    for p in local.custom_policy:
    p.name => p
  }

  name = "role-${var.name}-${var.function_name}-${each.value.name}"

  policy = jsonencode(each.value.policy)
}

resource "aws_iam_role_policy_attachment" "custom_attchment" {
  for_each = aws_iam_policy.custom_policy

  role       = aws_iam_role.lambda_exec.name
  policy_arn = each.value.arn

  depends_on = [
    aws_iam_policy.custom_policy
  ]
}

data "archive_file" "file_zip" {
  type        = "zip"
  output_path = "/tmp/${var.name}-${var.s3_key}.zip"
  source {
    content  = <<EOF
module.exports.handler = async (event, context, callback) => {
	const what = "world";
	const response = `Hello $${what}!`;
	callback(null, response);
};
EOF
    filename = "app.js"
  }
}

resource "aws_s3_bucket_object" "object_file" {
  bucket = var.s3_bucket
  key    = "${var.name}-${var.s3_key}"
  source = data.archive_file.file_zip.output_path

  lifecycle {
    ignore_changes = [
      source,
    ]
  }
}

resource "aws_lambda_function" "main" {
  s3_bucket        = var.s3_bucket
  s3_key           = "${var.name}-${var.s3_key}"
  function_name    = "${var.name}-${var.function_name}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = var.handler
  runtime          = var.runtime
  publish          = var.publish
  timeout          = var.timeout
  memory_size      = var.memory_size

  reserved_concurrent_executions = var.reserved_concurrent_executions

  layers = length(var.layers) != 0 ? var.layers : null

  dynamic "environment" {
    for_each = length(keys(var.environment)) == 0 ? [] : [var.environment]

    content {
      variables = environment.value  //lookup(environment.value, "variables", null)
    }
  }

  vpc_config {
    subnet_ids         = var.subnets
    security_group_ids = var.sg_ids
  }

  tags  = merge(
    var.tags,
    { Name = "${var.name}" },
  )

  lifecycle {
    ignore_changes = [
      environment,
      runtime,
      s3_key,
      handler
    ]
  }

  depends_on = [
    aws_s3_bucket_object.object_file,
  ]

}

// CloudWatch logs to stream all module
resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7

  tags  = merge(
    var.tags,
    { Name = "${var.name}" },
  )
}

output "arn" { value = aws_lambda_function.main.arn }
output "invoke_arn" { value = aws_lambda_function.main.invoke_arn }
output "qualified_arn" { value = aws_lambda_function.main.qualified_arn }
output "function_name" { value = "${var.name}-${var.function_name}" }
