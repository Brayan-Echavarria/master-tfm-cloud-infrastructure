#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios el implementar un VPC Endpoint
#--------------------------------------------------------------

variable "name"                 { }
variable "tags"                 { }
variable "vpc_id"               { }
variable "private_ids"          { }
variable "alb_dns_name"         { }
variable "certificate_arn"      { default = null }


module "lb" {
    source = "./elb"

    name = "${var.name}-nlb"
    tags = var.tags
    vpc_id = var.vpc_id
    private_ids = var.private_ids
    tipo = "network"
    certificate_arn = var.certificate_arn 
}

module "static_ips" {
    source = "./static_ips"

    name = var.name    
    alb_dns_name  = var.alb_dns_name
    lb_tg_http_arn = module.lb.lb_tg_http_arn
    lb_tg_https_arn = module.lb.lb_tg_https_arn
}    

module "vpc_link" {
    source = "./vpc_link"

    name = "${var.name}-link"
    tags = var.tags
    target_arns = module.lb.lb_arn
}