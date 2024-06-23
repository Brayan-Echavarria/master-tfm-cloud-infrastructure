variable "layer" {
  description = "Nombre del proyecto"
  type        = string
}

variable "region" {
  default = "eu-west-1"
}

variable "tags" { 
  description = "Tags"
}

variable "vpc_cidr"                 { 
  description = "CIDR de la VPC"
}  

variable "azs"                      {
  description = "Zonas de disponibilidad"
 }

variable "private_subnets"          {
  description = "Subredes Privadas"
 }

variable "public_subnets"           {
  description = "Subredes Publicas"
} 


#Cognito Apigateway Twcam
variable "clients_twcam"                    {}
variable "resources_twcam"                  {}