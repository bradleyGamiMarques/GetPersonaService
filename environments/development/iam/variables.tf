variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "get_p3r_persona_by_name_log_group_name" {
  default = "Name of log group for get_p3r_persona_by_name_lambda"
  type    = string
}

variable "lambda_execution_role_id" {
  description = "ID of lambda execution role"
  type        = string
}

variable "p3r_personas_table_name" {
  description = "Name of the DynamoDB table where Persona 3 Reload Persona data is stored"
  type        = string
}

variable "stage" {
  description = "Deployment environment stage"
  type        = string
}
