variable "app_region" {}
variable "account_id" {}

variable "api" {}
variable "gateway_method" {}
variable "gateway_resource" {}

variable "function_name" {}

resource "aws_lambda_function" "post_lambda" {
  filename         = "./api-gateway/calc/elevation/lambda/dist.zip"
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs10.x"
  source_code_hash = filebase64sha256("./api-gateway/calc/elevation/lambda/dist.zip")
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_lambda.arn
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.app_region}:${var.account_id}:${var.api.id}/*/${var.gateway_method.http_method}${var.gateway_resource.path}"
}

# lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}_lambda_role"

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

output "arn" {
  value = aws_lambda_function.post_lambda.arn
}
