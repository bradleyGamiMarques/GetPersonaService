terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.47.0"
    }
  }
}

terraform {
  backend "s3" {}
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

data "terraform_remote_state" "persona_compendium" {
  backend = "s3"
  config = {
    bucket = var.persona_compendium_terraform_state_bucket
    key    = var.key
    region = var.aws_region
  }
}

resource "aws_lambda_function" "get_p3r_persona_by_name" {
  function_name    = "GetP3RPersonaByName-${var.stage}"
  role             = data.terraform_remote_state.persona_compendium.outputs.lambda_execution_role_arn
  handler          = "main"
  runtime          = "provided.al2023"
  filename         = "${path.module}/../../cmd/lambda/GetP3RPersonaByName/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../../cmd/lambda/GetP3RPersonaByName/function.zip")
  memory_size      = 128
  timeout          = 30
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = data.terraform_remote_state.persona_compendium.outputs.p3r_personas_table_name
    }
  }
}


resource "aws_iam_role_policy" "get_p3r_persona_by_name_dev_lambda_policy" {
  name = "get_p3r_persona_by_name_dev_lambda_policy"
  role = data.terraform_remote_state.persona_compendium.outputs.lambda_execution_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.terraform_remote_state.persona_compendium.outputs.aws_account_id}:table/${data.terraform_remote_state.persona_compendium.outputs.p3r_personas_table_name}"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:${data.terraform_remote_state.persona_compendium.outputs.aws_account_id}:log-group:/aws/lambda/${aws_lambda_function.get_p3r_persona_by_name.function_name}:*"
      }
    ]
  })
}
