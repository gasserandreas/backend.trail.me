# Variables
variable "app_region" {
}

variable "account_id" {
}

variable "app_name" {
}

variable "root_domain_name" {
}

variable "www_domain_name" {
}

variable "credentials_file" {
}

variable "profile" {
}

variable "api_domain_name" {
}

variable "api_version" {
}

# variable "auth_app_secret" {
# }

# variable "auth_app_password" {
# }

# variable "api_stage" {
# }

# provider
provider "aws" {
  region                  = var.app_region
  # enabled only in local environment
  shared_credentials_file = var.credentials_file
  profile                 = var.profile
}

# prod environment
# module "prod_certificate" {
#   source           = "./acm-certificate"
#   root_domain_name = var.prod_root_domain_name
#   www_domain_name  = var.prod_www_domain_name
# }

# api implementation

module "gateway" {
  source = "./api-gateway"

  app_region      = "${var.app_region}"
  account_id      = "${var.account_id}"
  app_name        = "${var.app_name}"
  api_domain_name = "${var.api_domain_name}"
  api_version     = "${var.api_version}"
  # api_stage       = "${var.api_stage}"
  # auth_app_secret = "${var.auth_app_secret}"
  # auth_app_password = "${var.auth_app_password}"
}

