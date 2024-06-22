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
  s3_key        = "hello-world.zip"
  subnets       = module.network.private_subnet_ids
  sg_ids        = [module.network.sg_application]
  handler       = "main.handler"
  runtime       = "nodejs20.x"
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

/* # Creacion de API Gateway que apunta hacia Kinesis Firehose
module "api_gateway_centralizador_log" {
  source = "./modules/api_gateway"
  name        = "centralizador-log-${var.stack_id}"
  stack_id    = var.stack_id
  layer       = var.layer
  tags        = var.tags
  vpc_id      = module.network.vpc_id
  private_ids = module.network.private_subnet_ids
  stage_name  = var.stack_id
  endpoint_configuration_type = local.is_dev ? "REGIONAL" : "PRIVATE" 
  ingress_rules_api = var.ingress_rules_api
}

resource "aws_s3_bucket" "bucket_centralizador_log" {
  bucket = "${var.layer}-${var.stack_id}-kinesis"
  tags = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "centralizador_log_lifecycle" {
  bucket = aws_s3_bucket.bucket_centralizador_log.id

  rule {
    id      = "logRule"
    status  = "Enabled"
    filter {
      prefix = "log/"
    }

    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id      = "errorLogRule"
    status  = "Enabled"
    filter {
      prefix = "error_log/"
    }

    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id      = "outputRule"
    status  = "Enabled"
    filter {
      prefix = "output/"
    }

    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }
  }
}

resource "aws_s3_bucket_object" "folder_output" {
    bucket  = aws_s3_bucket.bucket_centralizador_log.id
    acl     = "private"
    key     =  "output/"
    content_type = "application/x-directory"
}


#Role Kinesis Firehouse
data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "firehose_role" {
  name               = "firehose_test_role"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
  tags = var.tags
}

resource "aws_iam_policy" "policy_kinesis_s3" { ##Cambiar
  name = "${var.layer}-${var.stack_id}-kinesis-s3-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:ListBucket"
      ],
      "Resource": [
        "${var.destination_bucket_arn}/centralizador_logs/*",
        "${var.destination_bucket_arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "glue:GetTable",
        "glue:GetTableVersion",
        "glue:GetTableVersions"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


## Integracion ApiGateway-KinesisFirehose
data "aws_api_gateway_resource" "parent_path" {
  rest_api_id = module.api_gateway_centralizador_log.aws_api_gateway_rest_api
  path        = "/" 
}

resource "aws_api_gateway_resource" "kinesisfirehose" {
  rest_api_id = module.api_gateway_centralizador_log.aws_api_gateway_rest_api
  parent_id   = data.aws_api_gateway_resource.parent_path.id
  path_part   = "kinesisfirehose"
}


## Integracion ApiGateway-KinesisFirehose
resource "aws_api_gateway_resource" "stream_name_ms" {
  rest_api_id = module.api_gateway_centralizador_log.aws_api_gateway_rest_api
  parent_id   = aws_api_gateway_resource.kinesisfirehose.id
  path_part   = "centralizador_log_ms"
}

module "apigateway_kinesisfirehose_centralizador_log_ms" {
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
}

#Cognito Apigateway Centralizador-log
module "cognito" {
    source             = "./modules/cognito"

    name = "${var.layer}-${var.stack_id}-centralizador-log-api"
    tags = var.tags  
    clients = var.clients_technical
    resources= var.resources_technical
}

resource "aws_api_gateway_authorizer" "CognitoUserPoolAuthorizerOauth20" {
  name          = "CognitoUserPoolAuthorizerOauth20"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = module.api_gateway_centralizador_log.aws_api_gateway_rest_api
  provider_arns = [module.cognito.cognito_arn]
} */

