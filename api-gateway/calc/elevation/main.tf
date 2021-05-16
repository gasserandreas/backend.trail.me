variable "api" {}
variable "app_region" {}
variable "account_id" {}
variable "parent_resource_id" {}
variable "parent_name" {}

# api path
resource "aws_api_gateway_resource" "resource_def" {
  path_part   = "elevation"
  parent_id   = var.parent_resource_id
  rest_api_id = var.api.id
}

# options post configuration
resource "aws_api_gateway_method" "options_method_post" {
  rest_api_id   = var.api.id
  resource_id   = aws_api_gateway_resource.resource_def.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options_200_post" {
  rest_api_id = var.api.id
  resource_id = aws_api_gateway_resource.resource_def.id
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
}

resource "aws_api_gateway_integration" "options_integration_post" {
  rest_api_id = var.api.id
  resource_id = aws_api_gateway_resource.resource_def.id
  http_method = aws_api_gateway_method.options_method_post.http_method
  type        = "MOCK"
  depends_on  = [aws_api_gateway_method.options_method_post]

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response_post" {
  rest_api_id = var.api.id
  resource_id = aws_api_gateway_resource.resource_def.id
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
  rest_api_id   = var.api.id
  resource_id   = aws_api_gateway_resource.resource_def.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "post_response_200" {
  rest_api_id           = var.api.id
  resource_id           = aws_api_gateway_resource.resource_def.id
  http_method           = aws_api_gateway_method.post.http_method
  status_code           = "200"
  response_parameters = {
      "method.response.header.Access-Control-Allow-Origin" = true
  }
  depends_on            = [aws_api_gateway_method.post, aws_api_gateway_integration.post_lambda_integration]
}

# lambda integration
module "post_lambda" {
  source = "./lambda"

  app_region = var.app_region
  account_id = var.account_id

  api = var.api
  gateway_method = aws_api_gateway_method.post
  gateway_resource  = aws_api_gateway_resource.resource_def

  function_name = "${var.parent_name}_post_lambda"
}

resource "aws_api_gateway_integration" "post_lambda_integration" {
  rest_api_id             = var.api.id
  resource_id             = aws_api_gateway_resource.resource_def.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.app_region}:lambda:path/2015-03-31/functions/${module.post_lambda.arn}/invocations"
}
