output "dynamodb_table_name" {
  description = "DynamoDB claims table name"
  value       = aws_dynamodb_table.claims.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.claims.function_name
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.claims.id
}

output "api_gateway_base_url" {
  description = "API Gateway base URL"
  value       = "https://${aws_api_gateway_rest_api.claims.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.claims.stage_name}"
}

output "claims_endpoint" {
  description = "POST claims endpoint"
  value       = "https://${aws_api_gateway_rest_api.claims.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.claims.stage_name}/claims"
}