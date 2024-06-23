layer = "tfm-twcam"
region = "eu-west-1"

tags = {
  Project     = "tfm-twcam"
  Source      = "Terraform"
}

# Networking
vpc_cidr        = "10.67.152.128/25"
azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
private_subnets = ["10.67.152.128/27", "10.67.152.160/27", "10.67.152.192/28"]
public_subnets  = ["10.67.152.208/28", "10.67.152.224/28",	"10.67.152.240/28"]



clients_twcam = [
        {
            name                = "TwcamCliente"
            supported_identity_providers = ["COGNITO"]
            allowed_oauth_flows = ["client_credentials"]
            allowed_oauth_scopes = ["ServerTwcamCognito/TwcamApiScope"]
            callback_urls = ["https://www.amazon.com"]
            logout_urls = ["https://www.amazon.com"]
            prevent_user_existence_errors= "ENABLED"
            explicit_auth_flows = ["ALLOW_CUSTOM_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
            
        }
    ]

resources_twcam = [
        {
            name       = "ServerTwcamCognito"
            identifier = "ServerTwcamCognito"
            scopes = [
                {
                    scope_name        = "TwcamApiScope"
                    scope_description = "TwcamApiScope"
                }
            ]
        }
    ]