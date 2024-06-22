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

resource "aws_api_gateway_rest_api" "main" {
  name = "${var.name}-api"

  tags  = merge(
    var.tags,
    { Name = "${var.name}" },
  )
}

output "apigateway_stage_arn" { value = aws_api_gateway_stage.satage.arn }
output "aws_api_gateway_stage" { value = var.stage_name }
output "aws_api_gateway_rest_api" { value =  aws_api_gateway_rest_api.main.id }
output "aws_api_gateway_root_resource_id" { value =  aws_api_gateway_rest_api.main.root_resource_id }