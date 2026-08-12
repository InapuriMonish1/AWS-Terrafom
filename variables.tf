variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "api_name" {
  description = "API Gateway REST API name"
  type        = string
}

variable "api_stage_name" {
  description = "API Gateway deployment stage"
  type        = string
}