variable "region" {}

variable "arn_lambda" {}

variable "name_lambda" {}

variable "id_apigateway" {}

variable "parent_resource_id" {}

variable "path" {}

data "aws_caller_identity" "current" {}

# Crear el recurso del API
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = var.id_apigateway
  parent_id = var.parent_resource_id
  path_part = var.path
}

# Crear el método del API (POST)
resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = var.id_apigateway
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "POST"
  authorization = "NONE"
}

# Crear la integración con la función Lambda
resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = var.id_apigateway
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.arn_lambda}/invocations"
}

# Crear la etapa de despliegue del API
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = var.id_apigateway
  depends_on = [aws_api_gateway_integration.integration]
  stage_name  = "prod"
}

# Permitir que API Gateway invoque la función Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${var.name_lambda}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${var.id_apigateway}/*/POST/example"
}
