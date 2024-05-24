// API Gateway Resources
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = var.rest_api_id
  parent_id   = var.root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "p3r" {
  rest_api_id = var.rest_api_id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "p3r"
}

resource "aws_api_gateway_resource" "persona" {
  rest_api_id = var.rest_api_id
  parent_id   = aws_api_gateway_resource.p3r.id
  path_part   = "persona"
}

resource "aws_api_gateway_resource" "persona_name" {
  rest_api_id = var.rest_api_id
  parent_id   = aws_api_gateway_resource.persona.id
  path_part   = "{personaName}"
}

resource "aws_api_gateway_resource" "arcana" {
  rest_api_id = var.rest_api_id
  parent_id   = aws_api_gateway_resource.p3r.id
  path_part   = "{arcana}"
}

resource "aws_api_gateway_resource" "personas" {
  rest_api_id = var.rest_api_id
  parent_id   = aws_api_gateway_resource.arcana.id
  path_part   = "personas"
}

// API Gateway Methods
resource "aws_api_gateway_method" "v1_get_p3r_persona_by_name" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.persona_name.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.personaName" = true
  }
}
resource "aws_api_gateway_method" "v1_get_p3r_personas_by_arcana" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.personas.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.arcana" = true
  }
}

// API Gateway Integrations
resource "aws_api_gateway_integration" "v1_get_p3r_persona_by_name_lambda_integration" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.persona_name.id
  http_method             = aws_api_gateway_method.v1_get_p3r_persona_by_name.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.v1_get_p3r_persona_by_name_lambda_invoke_arn

  request_parameters = {
    "integration.request.path.personaName" = "method.request.path.personaName"
  }
}
resource "aws_api_gateway_integration" "v1_get_p3r_personas_by_arcana_lambda_integration" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.personas.id
  http_method             = aws_api_gateway_method.v1_get_p3r_personas_by_arcana.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.v1_get_p3r_personas_by_arcana_lambda_invoke_arn

  request_parameters = {
    "integration.request.path.personaName" = "method.request.path.arcana"
  }
}

resource "aws_lambda_permission" "v1_get_p3r_persona_by_name_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke-get_p3r_persona_by_name"
  action        = "lambda:InvokeFunction"
  function_name = var.v1_get_p3r_persona_by_name_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:${var.rest_api_id}/*/${aws_api_gateway_method.v1_get_p3r_persona_by_name.http_method}${aws_api_gateway_resource.persona_name.path}"
}
resource "aws_lambda_permission" "v1_get_p3r_personas_by_arcana_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke-get_p3r_personas_by_arcana"
  action        = "lambda:InvokeFunction"
  function_name = var.v1_get_p3r_personas_by_arcana_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:${var.rest_api_id}/*/${aws_api_gateway_method.v1_get_p3r_personas_by_arcana.http_method}${aws_api_gateway_resource.personas.path}"
}

// API Gateway dev stage
resource "aws_api_gateway_stage" "persona_compendium" {
  deployment_id = aws_api_gateway_deployment.dev_deployment.id
  rest_api_id   = var.rest_api_id
  stage_name    = var.stage
}

// API Gateway dev deployment
resource "aws_api_gateway_deployment" "dev_deployment" {
  depends_on = [
    aws_api_gateway_integration.v1_get_p3r_persona_by_name_lambda_integration,
    aws_api_gateway_integration.v1_get_p3r_personas_by_arcana_lambda_integration,
    aws_api_gateway_method.v1_get_p3r_persona_by_name,
    aws_api_gateway_method.v1_get_p3r_personas_by_arcana
  ]
  rest_api_id = var.rest_api_id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.v1_get_p3r_persona_by_name_lambda_integration,
      aws_api_gateway_integration.v1_get_p3r_personas_by_arcana_lambda_integration,
      aws_api_gateway_method.v1_get_p3r_persona_by_name,
      aws_api_gateway_method.v1_get_p3r_personas_by_arcana,
      aws_api_gateway_resource.v1,
      aws_api_gateway_resource.p3r,
      aws_api_gateway_resource.persona,
      aws_api_gateway_resource.persona_name,
      aws_api_gateway_resource.arcana,
      aws_api_gateway_resource.personas,

    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}
