terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.50.0"
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

// Parent project remote state
data "terraform_remote_state" "persona_compendium" {
  backend = "s3"
  config = {
    bucket = var.persona_compendium_terraform_state_bucket
    key    = var.key
    region = var.aws_region
  }
}
module "api_gateway_configuration" {
  source                                          = "./api_gateway"
  aws_account_id                                  = var.aws_account_id
  aws_region                                      = var.aws_region
  get_p3r_persona_by_name_log_group_arn           = aws_cloudwatch_log_group.get_p3r_persona_by_name_log_group.arn
  lambda_execution_role_id                        = data.terraform_remote_state.persona_compendium.outputs.lambda_execution_role_id
  rest_api_id                                     = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  root_resource_id                                = data.terraform_remote_state.persona_compendium.outputs.api_gateway_root_resource_id
  stage                                           = var.stage
  v1_get_p3r_persona_by_name_lambda_invoke_arn    = module.v1_get_p3r_persona_by_name_lambda.invoke_arn
  v1_get_p3r_persona_by_name_lambda_function_name = module.v1_get_p3r_persona_by_name_lambda.function_name
}
module "v1_get_p3r_persona_by_name_lambda" {
  source                    = "./lambda"
  depends_on                = [aws_cloudwatch_log_group.get_p3r_persona_by_name_log_group]
  dynamodb_table_name       = data.terraform_remote_state.persona_compendium.outputs.p3r_personas_table_name
  lambda_execution_role_arn = data.terraform_remote_state.persona_compendium.outputs.lambda_execution_role_arn
}
module "iam_configuration" {
  source                   = "./iam"
  aws_account_id           = var.aws_account_id
  lambda_execution_role_id = data.terraform_remote_state.persona_compendium.outputs.lambda_execution_role_id
  p3r_personas_table_name  = data.terraform_remote_state.persona_compendium.outputs.p3r_personas_table_name
  stage                    = var.stage
}
resource "aws_cloudwatch_log_group" "get_p3r_persona_by_name_log_group" {
  name              = "get_p3r_persona_by_name_log_group_${var.stage}"
  retention_in_days = 7
}
