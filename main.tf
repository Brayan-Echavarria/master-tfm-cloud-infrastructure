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
  runtime       = "python3.8"
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


/* module "apigateway_kinesisfirehose_centralizador_log_ms" {
  source = "./modules/apigateway-kinesisfirehose"
  environment = var.stack_id
  name_integracion = "${var.layer}-kinesisfirehose-ms"
  region = var.region
  delivery_stream_name = aws_kinesis_firehose_delivery_stream.kinesis_centralizador_log_ms.name
  id_apigateway = module.api_gateway_centralizador_log.aws_api_gateway_rest_api
  parent_resource = "/kinesisfirehose/centralizador_log_ms"
  path            = "record"
  api_gateway_authorizer_id = aws_api_gateway_authorizer.CognitoUserPoolAuthorizerOauth20.id
  authorization_scopes = module.cognito.scope_identifiers[0]
  depends_on = [aws_kinesis_firehose_delivery_stream.kinesis_centralizador_log_ms , aws_api_gateway_resource.stream_name_ms]
} */


