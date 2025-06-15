    resource "aws_iam_role" "lambda_exec" {
    name = "lambda_exec_role_devops"
    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
            Service = "lambda.amazonaws.com"
        }
        }]
    })
    }

    resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    }

    resource "aws_iam_role_policy" "lambda_vpc_permissions" {
    name = "lambda-vpc-access"
    role = aws_iam_role.lambda_exec.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Effect = "Allow",
            Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface"
            ],
            Resource = "*"
        }
        ]
    })
    }

    resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    }

    resource "aws_subnet" "public" {
    vpc_id                  = aws_vpc.main.id
    cidr_block              = "10.0.1.0/24"
    map_public_ip_on_launch = true
    }

    resource "aws_subnet" "private" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    }

    resource "aws_security_group" "lambda_sg" {
    name        = "lambda_sg"
    description = "Security group for Lambda in private subnet"
    vpc_id      = aws_vpc.main.id

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    }

    resource "aws_lambda_function" "dummy_lambda" {
    function_name = "hello-lambda"
    role          = aws_iam_role.lambda_exec.arn
    handler       = "index.handler"
    runtime       = "nodejs18.x"
    filename      = "${path.module}/lambda/lambda.zip"
    memory_size   = 128
    timeout       = 1

    vpc_config {
        subnet_ids         = [aws_subnet.private.id]
        security_group_ids = [aws_security_group.lambda_sg.id]
    }

    depends_on = [
        aws_iam_role_policy_attachment.lambda_logs,
        aws_iam_role_policy.lambda_vpc_permissions,
        aws_subnet.private,
        aws_security_group.lambda_sg
    ]
    }

    resource "aws_apigatewayv2_api" "http_api" {
    name          = "http-api"
    protocol_type = "HTTP"
    }

    resource "aws_apigatewayv2_integration" "lambda_integration" {
    api_id                 = aws_apigatewayv2_api.http_api.id
    integration_type       = "AWS_PROXY"
    integration_uri        = aws_lambda_function.dummy_lambda.invoke_arn
    integration_method     = "POST"
    payload_format_version = "2.0"
    }

    resource "aws_apigatewayv2_route" "lambda_route" {
    api_id    = aws_apigatewayv2_api.http_api.id
    route_key = "GET /usuarios"
    target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
    }

    resource "aws_apigatewayv2_stage" "default" {
    api_id      = aws_apigatewayv2_api.http_api.id
    name        = "$default"
    auto_deploy = true
    }

    resource "aws_lambda_permission" "apigw_permission" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.dummy_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"

    depends_on = [aws_apigatewayv2_stage.default]
    }

    resource "aws_dynamodb_table" "dummy_table" {
    name         = "users"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "user_id"

    attribute {
        name = "user_id"
        type = "S"
    }
    }

    resource "aws_vpc_endpoint" "dynamodb_endpoint" {
    vpc_id            = aws_vpc.main.id
    service_name      = "com.amazonaws.us-east-1.dynamodb"
    vpc_endpoint_type = "Gateway"
    route_table_ids   = [aws_vpc.main.default_route_table_id]

    depends_on = [aws_vpc.main]
    }

    output "api_gateway_url" {
    description = "URL pública do endpoint HTTP API Gateway"
    value       = aws_apigatewayv2_api.http_api.api_endpoint
    }
