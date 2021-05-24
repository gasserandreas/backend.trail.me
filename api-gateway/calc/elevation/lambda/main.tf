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
  runtime          = "nodejs12.x"

  memory_size      = 256
  timeout          = 10

  source_code_hash = filebase64sha256("./api-gateway/calc/elevation/lambda/dist.zip")

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.assets_bucket.bucket,
      MAX_ITEM = 100
    }
  }
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

# S3 object definition to store .hgt files
resource "aws_s3_bucket" "assets_bucket" {
  // bucket name with account id prefix
  # bucket = "${var.account_id}-${var.root_domain_name}-${var.bucket_name}"
  bucket = "${var.account_id}-calc-elevation-assets-bucket"

  // We also need to create a policy that allows anyone to view the content.
  // This is basically duplicating what we did in the ACL but it's required by
  // AWS. This post: http://amzn.to/2Fa04ul explains why.
  policy = <<POLICY
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"AddPerm",
      "Effect":"Allow",
      "Principal": "*",
      "Action":[
        "s3:GetObject"
      ],
      "Resource":["arn:aws:s3:::${var.account_id}-calc-elevation-assets-bucket/*"]
    }
  ]
}
POLICY
}

output "arn" {
  value = aws_lambda_function.post_lambda.arn
}

output "s3-bucket" {
  value = aws_iam_role_policy.post_lambda-cloudwatch-log-group
}
