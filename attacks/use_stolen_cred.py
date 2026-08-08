import boto3
stolen=boto3.client(
    "iam",
    aws_access_key_id="Accesskey",
    aws_secret_access_key="SecretAccessKey",
    aws_session_token ="Tokentaken"
)
response = stolen.list_users()
print(response)
