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

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../cmd/lambda/GetP3RPersonaByName/bootstrap"
  output_path = "${path.module}/../../cmd/lambda/GetP3RPersonaByName/function.zip"
}

// Lambda Function 
resource "aws_lambda_function" "v1_get_p3r_persona_by_name" {
  function_name    = "v1_get_p3r_persona_by_name"
  role             = data.terraform_remote_state.persona_compendium.outputs.lambda_execution_role_arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  memory_size      = 128
  timeout          = 30
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = data.terraform_remote_state.persona_compendium.outputs.p3r_personas_table_name
    }
  }
  depends_on = [aws_cloudwatch_log_group.get_p3r_persona_by_name_log_group]
}

resource "aws_cloudwatch_log_group" "get_p3r_persona_by_name_log_group" {
  name              = "get_p3r_persona_by_name_log_group_${var.stage}"
  retention_in_days = 7
}

resource "aws_iam_role_policy" "get_p3r_persona_by_name_dev_lambda_policy" {
  name = "get_p3r_persona_by_name_dev_lambda_policy"
  role = data.terraform_remote_state.persona_compendium.outputs.lambda_execution_role_id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${data.terraform_remote_state.persona_compendium.outputs.p3r_personas_table_name}/index/PersonaIndex"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:${aws_cloudwatch_log_group.get_p3r_persona_by_name_log_group.name}:*"
      }
    ]
  })
}

// API Gateway Routes
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  parent_id   = data.terraform_remote_state.persona_compendium.outputs.api_gateway_root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "p3r" {
  rest_api_id = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "p3r"
}

resource "aws_api_gateway_resource" "persona" {
  rest_api_id = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  parent_id   = aws_api_gateway_resource.p3r.id
  path_part   = "persona"
}

resource "aws_api_gateway_resource" "persona_name" {
  rest_api_id = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  parent_id   = aws_api_gateway_resource.persona.id
  path_part   = "{personaName}"
}

// API Gateway Methods
resource "aws_api_gateway_method" "v1_get_p3r_persona_by_name" {
  rest_api_id   = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  resource_id   = aws_api_gateway_resource.persona_name.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.personaName" = true
  }
}

resource "aws_api_gateway_method_settings" "path_specific" {
  rest_api_id = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  stage_name  = aws_api_gateway_stage.persona_compendium.stage_name
  method_path = "${trimprefix(aws_api_gateway_resource.persona_name.path, "/")}/GET"

  settings {
    logging_level      = "INFO"
    metrics_enabled    = true
    data_trace_enabled = false
  }
}

// API Gateway Response
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  resource_id = aws_api_gateway_resource.persona_name.id
  http_method = aws_api_gateway_method.v1_get_p3r_persona_by_name.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

// API Gateway Integrations
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  resource_id             = aws_api_gateway_resource.persona_name.id
  http_method             = aws_api_gateway_method.v1_get_p3r_persona_by_name.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.v1_get_p3r_persona_by_name.invoke_arn

  request_parameters = {
    "integration.request.path.personaName" = "method.request.path.personaName"
  }
}

resource "aws_api_gateway_integration_response" "lambda_integration_response" {
  rest_api_id = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  resource_id = aws_api_gateway_resource.persona_name.id
  http_method = aws_api_gateway_method.v1_get_p3r_persona_by_name.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
  }
  response_templates = {
    "application/json" = ""
  }
  depends_on = [aws_api_gateway_integration.lambda_integration]
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.v1_get_p3r_persona_by_name.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:${data.terraform_remote_state.persona_compendium.outputs.rest_api_id}/*/${aws_api_gateway_method.v1_get_p3r_persona_by_name.http_method}${aws_api_gateway_resource.persona_name.path}"
}

resource "aws_api_gateway_stage" "persona_compendium" {
  deployment_id = aws_api_gateway_deployment.dev_deployment.id
  rest_api_id   = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  stage_name    = "dev"
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.get_p3r_persona_by_name_log_group.arn
    format          = "$context.requestId $context.identity.sourceIp $context.identity.userAgent $context.requestTime $context.httpMethod $context.resourcePath $context.status $context.error.message $context.integration.error"

  }
}

resource "aws_api_gateway_deployment" "dev_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.v1_get_p3r_persona_by_name
  ]
  rest_api_id = data.terraform_remote_state.persona_compendium.outputs.rest_api_id
  lifecycle {
    create_before_destroy = true
  }
}
