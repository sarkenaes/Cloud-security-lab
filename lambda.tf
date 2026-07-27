resource "aws_lambda_function" "remediation"{
    function_name = "purple_lab-remediation"
    runtime ="python3.12"
    handler = "remediation.lambda_handler"
    role=aws_iam_role.lambda_exec.arn
    filename="remediation.zip"
    source_code_hash=filebase64sha256("remediation.zip")
    timeout = 30
}
resource "aws_iam_role" "lambda_exec"{
    name= "purple-lab-lambda-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement =[{
            Action ="sts:AssumeRole"
            Effect ="Allow"
            Principal ={Service ="lambda.amazonaws.com"}
        }]
})
}
resource "aws_iam_role_policy_attachment" "lambda_logs"{
    role = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_lambda_permission" "allow_sns" {
    statement_id = "AllowExecutionFromSNS"
    action ="lambda:InvokeFunction"
    function_name = aws_lambda_function.remediation.function_name
    principal = "sns.amazonaws.com"
    source_arn = aws_sns_topic.security_alerts.arn
}