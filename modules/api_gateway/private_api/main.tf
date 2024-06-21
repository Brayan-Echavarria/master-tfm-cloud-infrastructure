#-------------------------------------------------------------------
# Estos modulos crea los recursos necesarios el API Gateway Privada
#-------------------------------------------------------------------

variable "vpc_id"      {}
variable "name"        {}
variable "private_ids" {}
variable "tags"        {}
variable "ingress_rules" { default = [] }

locals {
  ingress_rules = concat([
    {
      from_port   = "80"
      to_port     = "80"
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.selected.cidr_block]
    },
    {
      from_port   = "443"
      to_port     = "443"
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.selected.cidr_block]
    }
  ], var.ingress_rules )
  
  api_private_policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
          {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": [
                "*"
            ]
        }
      ]
  })
}

data "aws_vpc_endpoint_service" "vpc_endpoint_apigateway" {
  service = "execute-api"
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_security_group" "aws_security_group_apigateway" {
  name   = "${var.name}-sg-apigateway"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    security_groups   = []
    self              = false
  }

  tags  = merge(
    var.tags,
    { Name = "${var.name}" },
  )
}

resource "aws_vpc_endpoint" "vpc_endpoint_apigateway" {
  vpc_id              = var.vpc_id
  service_name        = data.aws_vpc_endpoint_service.vpc_endpoint_apigateway.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false

  subnet_ids          = var.private_ids
  security_group_ids  = [aws_security_group.aws_security_group_apigateway.id]
  tags  = merge(
    var.tags,
    { Name = "${var.name}" },
  )
}

output "vpc_endpoint_apigateway"{
  value = aws_vpc_endpoint.vpc_endpoint_apigateway.id
}
output "api_private_policy"{
  value = local.api_private_policy
}