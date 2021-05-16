variable "app_region" {}
variable "account_id" {}
variable "app_name" {}
variable "api_domain_name" {}
variable "api_version" {}

# create api
resource "aws_api_gateway_rest_api" "message_api" {
  name = "${var.app_name}_api"
}

# dns api entry
# module "name" {
#   source = "./dns"

#   api_domain_name = "${var.api_domain_name}"
#   route53_zone_id = "${var.route53_zone_id}"
#   certificate_arn = "${var.certificate_arn}"
# }

# add calc API endpoint
module "calc" {
  source = "./calc"

  app_region = var.app_region
  app_name = var.app_name
  account_id = var.account_id
  api      = aws_api_gateway_rest_api.message_api
}

# post message api
resource "aws_api_gateway_resource" "message" {
  path_part   = "message"
  parent_id   = aws_api_gateway_rest_api.message_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.message_api.id
}

# options / CORS configuration for post
resource "aws_api_gateway_method" "options_method_post" {
  rest_api_id   = aws_api_gateway_rest_api.message_api.id
  resource_id   = aws_api_gateway_resource.message.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options_200_post" {
  rest_api_id = aws_api_gateway_rest_api.message_api.id
  resource_id = aws_api_gateway_resource.message.id
  http_method = aws_api_gateway_method.options_method_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  depends_on = [aws_api_gateway_method.options_method_post]
  # depends_on = [aws_api_gateway_method.options_method_post]
}

resource "aws_api_gateway_integration" "options_integration_post" {
  rest_api_id = aws_api_gateway_rest_api.message_api.id
  resource_id = aws_api_gateway_resource.message.id
  http_method = aws_api_gateway_method.options_method_post.http_method
  type        = "MOCK"
  depends_on  = [aws_api_gateway_method.options_method_post]

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response_post" {
  rest_api_id = aws_api_gateway_rest_api.message_api.id
  resource_id = aws_api_gateway_resource.message.id
  http_method = aws_api_gateway_method.options_method_post.http_method
  status_code = aws_api_gateway_method_response.options_200_post.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token','X-Apollo-Tracing'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,GET,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_method_response.options_200_post]
}

# post integration
resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.message_api.id
  resource_id   = aws_api_gateway_resource.message.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "graph_response_200" {
  rest_api_id           = aws_api_gateway_rest_api.message_api.id
  resource_id           = aws_api_gateway_resource.message.id
  http_method           = aws_api_gateway_method.post.http_method
  status_code           = "200"
  response_parameters = {
      "method.response.header.Access-Control-Allow-Origin" = true
  }
  depends_on            = [aws_api_gateway_method.post, aws_api_gateway_integration.post_lambda_integration]
}

resource "aws_api_gateway_integration" "post_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.message_api.id
  resource_id             = aws_api_gateway_resource.message.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.app_region}:lambda:path/2015-03-31/functions/${module.post_lambda.arn}/invocations"
}

# post lambda
module "post_lambda" {
  source = "./post"

  app_name       = var.app_name
  app_region     = var.app_region
  account_id     = var.account_id
  lambda_role    = aws_iam_role.lambda_role.arn
  api            = aws_api_gateway_rest_api.message_api.id
  gateway_method = aws_api_gateway_method.post.http_method
  gateway_name   = aws_api_gateway_method.post.http_method
  resource_path  = aws_api_gateway_resource.message.path
}

# lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}_lambda_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

# cloudwatch log group 
data "aws_iam_policy_document" "cloudwatch-log-group-lambda" {
  statement {
    actions = [
      "logs:PutLogEvents",    # take care of action order
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }
}

# attach cloudwatch log group to lambda role
resource "aws_iam_role_policy" "post_lambda-cloudwatch-log-group" {
  name   = "cloudwatch-log-group"
  role   = aws_iam_role.lambda_role.name
  policy = data.aws_iam_policy_document.cloudwatch-log-group-lambda.json
}

# deploy api
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    # "aws_api_gateway_integration.get_lambda_integration",
    aws_api_gateway_integration.post_lambda_integration,
    # "aws_api_gateway_integration.get_with_id_lambda_integration",
  ]

  rest_api_id = aws_api_gateway_rest_api.message_api.id
  stage_name  = "prod"
}

# base mapping
# resource "aws_api_gateway_base_path_mapping" "path_mapping" {
#   api_id      = "${aws_api_gateway_rest_api.message_api.id}"
#   stage_name  = "${aws_api_gateway_deployment.deployment.stage_name}"
#   domain_name = "${var.api_domain_name}"
#   base_path   = "${var.api_version}"
# }

# output api
output "invoke_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}
