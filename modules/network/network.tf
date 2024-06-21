#--------------------------------------------------------------
# Estos módulos crean los recursos necesarios para la VPC
#--------------------------------------------------------------

variable "name"                  {}
variable "layer"                 {}
variable "tags"                  {}
variable "vpc_cidr"              {}
variable "azs"                   { 
  type    = list(string)
  default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}
variable "private_subnets"       { type = list(string) }
variable "public_subnets"        { type = list(string) }

/* variable "custom_routes_private" { default = [] }
variable "custom_routes_public"  { default = [] } */

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    { Name = "${var.name}-vpc" },
  )
}

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    { Name = "${var.name}-public" },
  )
}

/* resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(var.public_subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = merge(
    var.tags,
    { Name = "${var.name}-public-${element(var.azs, count.index)}" },
  )

  lifecycle { create_before_destroy = true }

  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  count = length(var.public_subnets)

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.name}-public-${element(var.azs, count.index)}" },
  )
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(var.private_subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = merge(
    var.tags,
    { Name = "${var.name}-private-${element(var.azs, count.index)}" },
  )

  lifecycle { create_before_destroy = true }
}

resource "aws_network_acl" "acl" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = concat(aws_subnet.public.*.id, aws_subnet.private.*.id)

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    var.tags,
    { Name = "${var.name}-all" },
  )
}

resource "aws_security_group" "allow_application" {
  name        = "${var.name}-application-allow"
  description = "Allow application inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "application from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    description = "application from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.name}-all" },
  )
}

resource "aws_security_group" "allow_db" {
  name        = "${var.name}-allow-db"
  description = "Allow DB inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "port mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    description = "port postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    description = "port sql server"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    description = "port oracle"
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    description = "port mongodb"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.name}-all" },
  )
}

resource "aws_security_group" "allow_public" {
  name        = "${var.name}-allow-public"
  description = "Allow public inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "public inbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description = "public inbound traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.name}-all" },
  )
} */

# VPC Outputs
output "vpc_id" {
  value = aws_vpc.vpc.id
}
output "vpc_cidr" {
  value = aws_vpc.vpc.cidr_block
}

# Subnet Outputs
/* output "public_subnet_ids" {
  value = aws_subnet.public.*.id
}
output "public_subnet_cidr_blocks" {
  value = aws_subnet.public.*.cidr_block
}
output "private_subnet_ids" {
  value = aws_subnet.private.*.id
}
output "private_subnet_cidr_blocks" {
  value = aws_subnet.private.*.cidr_block
}

# Security Group Outputs
output "sg_db" {
  value = aws_security_group.allow_db.id
}
output "sg_application" {
  value = aws_security_group.allow_application.id
}
output "sg_public" {
  value = aws_security_group.allow_public.id
} */
