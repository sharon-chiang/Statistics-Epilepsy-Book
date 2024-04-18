import boto3


def download_from_s3(cloud_path, local_path):
    """Download a file from S3 to a local path."""
    s3 = boto3.resource("s3")
    s3.Bucket("covid-19-data").download_file(cloud_path, local_path)
