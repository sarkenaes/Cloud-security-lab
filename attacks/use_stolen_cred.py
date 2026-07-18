import boto3
stolen=boto3.client(
    "iam",
      aws_access_key_id="ACESS_KEY",
    aws_secret_access_key="SECRET_KEY",
    aws_session_token="TOKEN")
response = stolen.list_users()
print(response)
