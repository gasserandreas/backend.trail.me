variable "api" {}
variable "app_region" {}
variable "app_name" {}
variable "account_id" {}

# api path
resource "aws_api_gateway_resource" "calc" {
  path_part   = "calc"
  parent_id   = var.api.root_resource_id
  rest_api_id = var.api.id
}

module "elevation" {
  source = "./elevation"

  api      = var.api
  app_region = var.app_region
  account_id = var.account_id

  parent_name = "${var.app_name}_api_${aws_api_gateway_resource.calc.path_part}_elevation"
  parent_resource_id = aws_api_gateway_resource.calc.id
}

