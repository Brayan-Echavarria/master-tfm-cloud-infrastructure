#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios para el alb
#--------------------------------------------------------------

variable "name"                 { default = "lb" }
variable "tags"                 { }
variable "vpc_id"               { }
variable "private_ids"          { }
variable "tipo"                 { }
variable "certificate_arn"      { default = null } 

resource "aws_lb" "lb" {
  name               = var.name
  internal           = true
  load_balancer_type = var.tipo
  subnets            = var.private_ids
  
  enable_cross_zone_load_balancing = true

  tags  = merge(
    var.tags,
    { Name = var.name },
  )
}

resource "aws_lb_target_group" "nlb_80" {
  name = "${var.name}-80"
  protocol = "TCP"
  port = 80
  target_type = "ip"
  vpc_id = var.vpc_id
  proxy_protocol_v2 = false
}

resource "aws_lb_target_group" "nlb_443" {
  count = var.certificate_arn !=null ? 1 : 0

  name = "${var.name}-443"
  protocol = "TLS"
  port = 443
  target_type = "ip"
  vpc_id = var.vpc_id
  proxy_protocol_v2 = false
}

resource "aws_lb_listener" "nlb_80" {
  load_balancer_arn = aws_lb.lb.arn
  protocol = "TCP"
  port = 80
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.nlb_80.arn
  }
}

resource "aws_lb_listener" "nlb_443" {
  count = var.certificate_arn !=null ? 1 : 0

  load_balancer_arn = aws_lb.lb.arn
  protocol = "TLS"
  port = 443
  certificate_arn = var.certificate_arn
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.nlb_443[0].arn
  }
}


output "lb_name" { value = "${aws_lb.lb.name}" }
output "lb_arn" { value = "${aws_lb.lb.arn}" }
output "lb_dns_name" { value = "${aws_lb.lb.dns_name}" }
output "lb_tg_http_arn" { value = aws_lb_target_group.nlb_80.arn }
output "lb_tg_https_arn" { value = var.certificate_arn != null? aws_lb_target_group.nlb_443[0].arn : null }
 