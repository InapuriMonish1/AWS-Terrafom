
# DynamoDB

resource "aws_dynamodb_table" "claims" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "claimId"

  attribute {
    name = "claimId"
    type = "S"
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}

# IAM Role for Lambda

resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


# =========================================================
# Lambda CloudWatch Logging Permission
# =========================================================

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role = aws_iam_role.lambda_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# =========================================================
# Lambda → DynamoDB Permission
# =========================================================

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${var.lambda_function_name}-dynamodb-policy"

  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "dynamodb:PutItem"
        ]

        Resource = aws_dynamodb_table.claims.arn
      }
    ]
  })
}


# =========================================================
# Package Lambda
# =========================================================

data "archive_file" "lambda_zip" {
  type        = "zip"

  source_file = "${path.module}/Lambda/lambda_function.py"

  output_path = "${path.module}/lambda_function.zip"
}


# =========================================================
# Lambda Function
# =========================================================

resource "aws_lambda_function" "claims" {
  function_name = var.lambda_function_name

  filename = data.archive_file.lambda_zip.output_path

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role = aws_iam_role.lambda_role.arn

  handler = "lambda_function.lambda_handler"

  runtime = "python3.13"

  timeout = 10

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.claims.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_dynamodb_policy
  ]

  tags = {
    Name = var.lambda_function_name
  }
}


# =========================================================
# API Gateway REST API
# =========================================================

resource "aws_api_gateway_rest_api" "claims" {
  name = var.api_name

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = var.api_name
  }
}


# =========================================================
# /claims Resource
# =========================================================

resource "aws_api_gateway_resource" "claims" {
  rest_api_id = aws_api_gateway_rest_api.claims.id

  parent_id = aws_api_gateway_rest_api.claims.root_resource_id

  path_part = "claims"
}


# POST /claims

resource "aws_api_gateway_method" "create_claim" {
  rest_api_id = aws_api_gateway_rest_api.claims.id

  resource_id = aws_api_gateway_resource.claims.id

  http_method = "POST"

  authorization = "NONE"
}

# API Gateway → Lambda Integration

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.claims.id

  resource_id = aws_api_gateway_resource.claims.id

  http_method = aws_api_gateway_method.create_claim.http_method

  integration_http_method = "POST"

  type = "AWS_PROXY"

  uri = aws_lambda_function.claims.invoke_arn
}

# API Gateway → Lambda Permission

resource "aws_lambda_permission" "api_gateway" {
  statement_id = "AllowAPIGatewayInvoke"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.claims.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.claims.execution_arn}/*/POST/claims"
}

#APi Gateway Development

resource "aws_api_gateway_deployment" "claims" {
  rest_api_id = aws_api_gateway_rest_api.claims.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.claims.id,
      aws_api_gateway_method.create_claim.id,
      aws_api_gateway_integration.lambda.id
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_lambda_permission.api_gateway
  ]

  lifecycle {
    create_before_destroy = true
  }
}


#API Gateway Stage

resource "aws_api_gateway_stage" "claims" {
  rest_api_id = aws_api_gateway_rest_api.claims.id

  deployment_id = aws_api_gateway_deployment.claims.id

  stage_name = var.api_stage_name
}