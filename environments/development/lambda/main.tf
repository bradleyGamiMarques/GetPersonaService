data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../../cmd/lambda/GetP3RPersonaByName/bootstrap"
  output_path = "${path.module}/../../../cmd/lambda/GetP3RPersonaByName/function.zip"
}

// Lambda Function 
resource "aws_lambda_function" "v1_get_p3r_persona_by_name" {
  function_name    = "v1_get_p3r_persona_by_name"
  role             = var.lambda_execution_role_arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  memory_size      = 128
  timeout          = 30
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }
  # depends_on = [aws_cloudwatch_log_group.get_p3r_persona_by_name_log_group]
}
