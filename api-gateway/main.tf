variable "app_region" {}
variable "account_id" {}
variable "app_name" {}
variable "api_domain_name" {}
variable "api_version" {}

# create api
resource "aws_api_gateway_rest_api" "message_api" {
  name = "${var.app_name}_api"
}

# add calc API endpoint
module "calc" {
  source = "./calc"

  app_region = var.app_region
  app_name = var.app_name
  account_id = var.account_id
  api      = aws_api_gateway_rest_api.message_api
}

# deploy api
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    module.calc,
  ]

  rest_api_id = aws_api_gateway_rest_api.message_api.id
  stage_name  = "prod"
}

# output api
output "invoke_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}
