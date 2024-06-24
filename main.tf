# Create network y VPC
module "network" {
  source             = "./modules/network"
  name               = "${var.layer}-network"
  layer              = var.layer
  tags               = var.tags
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
}

resource "aws_api_gateway_rest_api" "main" {
  name = "${var.layer}-api"

  tags  = merge(
    var.tags,
    { Name = "${var.layer}" },
  )

  endpoint_configuration {
    types = ["REGIONAL"]
  }

}

resource "aws_s3_bucket" "bucket_lambda" {
  bucket = "${var.layer}-lambda"
  tags = var.tags
}

module "lambda_modeloIAVino" {
  source        = "./modules/lambda"
  name          = "${var.layer}"
  tags          = var.tags
  function_name = "modeloIAVino"
  s3_bucket     = "${var.layer}-lambda"
  s3_key        = "lambda_function.zip"
  subnets       = module.network.private_subnet_ids
  sg_ids        = [module.network.sg_application]
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 128
  custom_policy = [
      {
        name = "lambda-modeloIAVino-policy"
        policy = {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "logs:*",
            ],
              "Resource": "*"
            }
          ]
        }
      }
    ]
  depends_on = [
    aws_s3_bucket.bucket_lambda
  ]
}

module "apigateway_lambda" {
  source = "./modules/apigateway-lambda"
  region = var.region
  arn_lambda = module.lambda_modeloIAVino.arn
  name_lambda = module.lambda_modeloIAVino.function_name
  id_apigateway = aws_api_gateway_rest_api.main.id
  parent_resource_id = aws_api_gateway_rest_api.main.root_resource_id
  path            = "modeloIAVino"
  api_gateway_authorizer_id = aws_api_gateway_authorizer.CognitoUserPoolAuthorizerOauth20.id
  authorization_scopes = module.cognito.scope_identifiers[0]
  depends_on = [module.lambda_modeloIAVino]
}

#Cognito Apigateway
module "cognito" {
    source             = "./modules/cognito"
    name = "${var.layer}-api"
    tags = var.tags  
    clients = var.clients_twcam
    resources= var.resources_twcam
}

resource "aws_api_gateway_authorizer" "CognitoUserPoolAuthorizerOauth20" {
  name          = "CognitoUserPoolAuthorizerOauth20"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  provider_arns = [module.cognito.cognito_arn]
} 

# Create SNS Topic
resource "aws_sns_topic" "email_notifications" {
  name = "email-notifications"
}

# Create SNS Subscription for Email
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.email_notifications.arn
  protocol  = "email"
  endpoint  = "${var.target_email}" 
}

module "lambda_sns_check_lambda" {
  source        = "./modules/lambda"
  name          = "${var.layer}"
  tags          = var.tags
  function_name = "sns_check_lambda"
  s3_bucket     = "${var.layer}-lambda"
  s3_key        = "lambda_sns_check_function.zip"
  //subnets       = module.network.public_subnet_ids
  //sg_ids        = [module.network.sg_all]
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 128
  timeout = 15
  environment   = {
    SNS_TOPIC_ARN        = "${aws_sns_topic.email_notifications.arn}",
    COGNITO_CLIENT_ID    = "${module.cognito.client_id_without_idp[0]}",
    COGNITO_CLIENT_SECRET= "${module.cognito.client_secret_without_idp[0]}",
    COGNITO_TOKEN_URL    = "https://${var.layer}-api.auth.${var.region}.amazoncognito.com/oauth2/token",
    API_URL              = "${module.apigateway_lambda.api_url}",
    COGNITO_SCOPE        = "ServerTwcamCognito/TwcamApiScope",
    BUCKET_NAME          = "${aws_s3_bucket.bucket_test_data.bucket}",
    CSV_KEY              = "winequality-red-test-data.csv"
  }

  custom_policy = [
      {
        name = "lambda-sns_check_lambda-policy"
        policy = {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "logs:*",
            ],
              "Resource": "*"
            },
            {
              Action = [
                "sns:Publish"
              ],
              Effect   = "Allow",
              Resource = aws_sns_topic.email_notifications.arn
            },
            {
              Effect = "Allow",
              Action = [
                "s3:GetObject",
                "s3:ListBucket"
              ],
              Resource = [
                "${aws_s3_bucket.bucket_test_data.arn}",
                "${aws_s3_bucket.bucket_test_data.arn}/*"
              ]
            }
          ]
        }
      }
    ]
  depends_on = [
    aws_s3_bucket.bucket_lambda
  ]
}

# Crear el bucket S3 test data
resource "aws_s3_bucket" "bucket_test_data" {
  bucket = "${var.layer}-test-data"
  tags = var.tags
}

# Subir el archivo CSV al bucket S3
resource "aws_s3_object" "csv_object" {
  bucket = aws_s3_bucket.bucket_test_data.bucket
  key    = "winequality-red-test-data.csv"
  source = "./test_data/winequality-red-test-data.csv"

  depends_on = [
    aws_s3_bucket.bucket_test_data
  ]
}

