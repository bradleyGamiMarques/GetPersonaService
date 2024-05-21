resource "aws_iam_role_policy" "get_p3r_persona_by_name_dev_lambda_policy" {
  name = "get_p3r_persona_by_name_dev_lambda_policy"
  role = var.lambda_execution_role_id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.p3r_personas_table_name}/index/PersonaIndex"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:${var.get_p3r_persona_by_name_log_group_name}:*"
      }
    ]
  })
}
