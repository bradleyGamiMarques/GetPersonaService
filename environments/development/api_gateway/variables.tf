variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "get_p3r_persona_by_name_log_group_arn" {
  description = "Log group ARN for get_p3r_persona_by_name_lambda"
  type        = string
}

variable "lambda_execution_role_id" {
  description = "ID of lambda execution role"
  type        = string
}

variable "rest_api_id" {
  description = "Rest api id of api gateway"
  type        = string
}

variable "root_resource_id" {
  description = "Root resource id of api gateway"
  type        = string
}

variable "stage" {
  description = "Deployment environment stage"
  type        = string
}

variable "v1_get_p3r_persona_by_name_lambda_invoke_arn" {
  description = "Invocation ARN for v1_get_p3r_persona_by_name_lambda"
  type        = string
}

variable "v1_get_p3r_persona_by_name_lambda_function_name" {
  description = "Function name for v1_get_p3r_persona_by_name_lambda"
  type        = string
}
variable "v1_get_p3r_personas_by_arcana_lambda_invoke_arn" {
  description = "Invocation ARN for v1_get_p3r_personas_by_arcana_lambda"
  type        = string
}

variable "v1_get_p3r_personas_by_arcana_lambda_function_name" {
  description = "Function name for v1_get_p3r_personas_by_arcana_lambda"
  type        = string
}
