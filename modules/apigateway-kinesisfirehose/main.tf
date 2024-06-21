variable "environment" {}

variable "name_integracion" {}

variable "region" {}

variable "delivery_stream_name" {}

variable "id_apigateway" {}

variable "parent_resource" {}

variable "path" {}

variable "api_gateway_authorizer_id" {}

variable "authorization_scopes" {}

#Permisos para que el Apigateway pueda leer y escribir en kinesis firehose
resource "aws_iam_role" "api_role" {
  name = "${var.name_integracion}-apigateway-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "api_policy" {
  name = "${var.name_integracion}-api-cloudwatch-policy-${var.environment}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:PutLogEvents",
            "logs:GetLogEvents",
            "logs:FilterLogEvents"
          ],
          "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "firehose:*",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "api_exec_role" {
  role       =  aws_iam_role.api_role.name
  policy_arn =  aws_iam_policy.api_policy.arn
}

#Recursos adicionales apigateway
data "aws_api_gateway_resource" "my_resource" {
  rest_api_id = var.id_apigateway
  path        = var.parent_resource
}

resource "aws_api_gateway_resource" "form_score" {
    rest_api_id = var.id_apigateway
    parent_id   = data.aws_api_gateway_resource.my_resource.id
    path_part   = var.path
}

resource "aws_api_gateway_method" "method_form_score" {
    rest_api_id   = var.id_apigateway
    resource_id   = aws_api_gateway_resource.form_score.id
    http_method   = "PUT"
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = var.api_gateway_authorizer_id
    authorization_scopes = var.authorization_scopes
}

resource "aws_api_gateway_integration" "api" {
  rest_api_id             = var.id_apigateway
  resource_id             = aws_api_gateway_resource.form_score.id
  http_method             = aws_api_gateway_method.method_form_score.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  credentials             = aws_iam_role.api_role.arn
  passthrough_behavior    = "NEVER"
  uri                     = "arn:aws:apigateway:${var.region}:firehose:action/PutRecord"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }

  request_templates = {
    "application/json" = <<EOF
{
   "DeliveryStreamName": "${var.delivery_stream_name}",
   "Record": { 
      "Data": "$util.base64Encode($input.json('$'))"
   }
}
EOF
  }

  depends_on = [
    aws_iam_role_policy_attachment.api_exec_role
  ]
}

# Respuesta de retorno de kinesis firehose al Apigateway
resource "aws_api_gateway_method_response" "http200" {
 rest_api_id = var.id_apigateway
 resource_id = aws_api_gateway_resource.form_score.id
 http_method = aws_api_gateway_method.method_form_score.http_method
 status_code = 200
}

resource "aws_api_gateway_integration_response" "http200" {
 rest_api_id       = var.id_apigateway
 resource_id       = aws_api_gateway_resource.form_score.id
 http_method       = aws_api_gateway_method.method_form_score.http_method
 status_code       = aws_api_gateway_method_response.http200.status_code
 selection_pattern = "^2[0-9][0-9]" // regex pattern for any 200 message that comes back from SQS

 depends_on = [
   aws_api_gateway_integration.api
   ]
}
#API Gateway REST Deployment in order to deploy our endpoint

resource "aws_api_gateway_deployment" "api" {
 rest_api_id = var.id_apigateway
 stage_name  = var.environment

 depends_on = [
   aws_api_gateway_integration.api,
 ]

 # Redeploy when there are new updates
 triggers = {
   redeployment = sha1(join(",", list(
     jsonencode(aws_api_gateway_integration.api),
   )))
 }

 lifecycle {
   create_before_destroy = true
 }
}