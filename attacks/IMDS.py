import requests

token_response= requests.put( "http://169.254.169.254/latest/api/token",
    headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"})
token=token_response.text
name = requests.get("http://169.254.169.254/latest/meta-data/iam/security-credentials/",headers= {"X-aws-ec2-metadata-token": token})
credential=requests.get(f"http://169.254.169.254/latest/meta-data/iam/security-credentials/{name.text}", headers={"X-aws-ec2-metadata-token": token})
print(credential.text)

