#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios el API Gateway
#--------------------------------------------------------------

variable "name"                 { }
variable "stack_id"             { }
variable "layer"                { }
variable "tags"                 { }
variable "vpc_id"               { default = null }
variable "private_ids"          { default = [] }
variable "alb_dns_name"         { default = null }
variable "certificate_arn"      { default = null } 
variable "stage_name"           { default = "dev"}
variable "endpoint_configuration_type" { default = "REGIONAL" }
variable "ingress_rules_api"    { default = [] }
variable "binary_media_types" {default = null}

locals {
  api_private_policy      = var.endpoint_configuration_type == "PRIVATE" ? module.private_apigateway[0].api_private_policy : null
  vpc_endpoint_apigateway = var.endpoint_configuration_type == "PRIVATE" ? module.private_apigateway[0].vpc_endpoint_apigateway : null
}

module "vpc_private" {
    source = "./vpc_private"
    count = length(var.private_ids) > 0 ? 1 : 0

    name = var.name
    tags = var.tags
    vpc_id = var.vpc_id
    private_ids = var.private_ids
    alb_dns_name  = var.alb_dns_name
    certificate_arn = var.certificate_arn 
}

module "private_apigateway"{
    count  = var.endpoint_configuration_type == "PRIVATE" ? 1 : 0
    source = "./private_api" 
    vpc_id = var.vpc_id
    name   = var.name
    private_ids = var.private_ids
    tags        = var.tags
    ingress_rules = var.ingress_rules_api
}

resource "aws_iam_role" "cloudwatch" {
  name = "${var.name}-api_gateway_cloudwatch"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "${var.name}-api_gateway_logs"
  role = aws_iam_role.cloudwatch.id

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
        }
    ]
}
EOF
}

resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

resource "aws_api_gateway_rest_api" "main" {
  name = "${var.name}-api"

  policy = var.endpoint_configuration_type == "PRIVATE" ? local.api_private_policy : null

  endpoint_configuration {
    types = [var.endpoint_configuration_type]
    vpc_endpoint_ids = var.endpoint_configuration_type == "PRIVATE" ? [local.vpc_endpoint_apigateway] : null
  }

  tags  = merge(
    var.tags,
    { Name = "${var.name}" },
  )
  binary_media_types = var.binary_media_types
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id = aws_api_gateway_rest_api.main.root_resource_id
  path_part = "health"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  //resource_id = aws_api_gateway_resource.proxy[each.key].id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = "GET"
  authorization =  "NONE" //"COGNITO_USER_POOLS"
  //authorizer_id = aws_api_gateway_authorizer.cognito.id
  //request_parameters = {
  //  "method.request.path.proxy" = true
  //}
  //authorization_scopes = aws_cognito_resource_server.this.scope_identifiers
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method
  //resource_id = aws_api_gateway_resource.proxy[each.key].id
  //http_method = aws_api_gateway_method.proxy[each.key].http_method
  //integration_http_method =  "GET"
  type = "MOCK"
  //uri = "http://${module.lb[0].lb_dns_name}/health"
  //connection_type = "VPC_LINK"
  //connection_id = module.vpc_link[0].vpc_link_id  // "$${stageVariables.vpcLinkId}"
  /*request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }*/

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  //stage_name = var.stage_name
  depends_on = [aws_api_gateway_integration.integration]

  # variables = {
  #   // just to trigger redeploy on resource changes
  #   resources = join(", ", [aws_api_gateway_resource.proxy.id])

  #   // note: redeployment might be required with other gateway changes.
  #   // when necessary run `terraform taint <this resource's address>`
  # }
  
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.main.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

/*
data "aws_api_gateway_vpc_link" "env" {
  name ="${var.name}-link"
}
*/

resource "aws_api_gateway_stage" "satage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name = var.stage_name
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    // Common Log Format
    //format = "$context.identity.sourceIp $context.identity.caller $context.identity.user [$context.requestTime] \"$context.httpMethod $context.resourcePath $context.protocol\" $context.status $context.responseLength $context.requestId  $context.authorizer.error"
    format = "{ \"requestId\":\"$context.requestId\", \"ip\": \"$context.identity.sourceIp\", \"requestTime\":\"$context.requestTime\", \"httpMethod\":\"$context.httpMethod\",\"routeKey\":\"$context.routeKey\", \"status\":\"$context.status\",\"protocol\":\"$context.protocol\", \"responseLength\":\"$context.responseLength\", \"error\":\"$context.error.message\", \"errorMsg\": $context.error.messageString ,\"authorizerError\": $context.authorizer.error}"
  }
  /*variables = {
    vpcLinkId = data.aws_api_gateway_vpc_link.env.id
  }*/

  lifecycle {
    ignore_changes = [
      deployment_id,
      cache_cluster_size
    ]
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.main.id}"
  retention_in_days = 7

  tags  = merge(
    var.tags,
    { Name = "${var.name}" },
  )
}

output "apigateway_stage_arn" { value = aws_api_gateway_stage.satage.arn }
output "aws_api_gateway_stage" { value = var.stage_name }
output "aws_api_gateway_rest_api" { value =  aws_api_gateway_rest_api.main.id }
output "aws_api_gateway_root_resource_id" { value =  aws_api_gateway_rest_api.main.root_resource_id }