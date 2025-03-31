import boto3
import uuid
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize S3 client
s3_client = boto3.client(
    "s3",
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY'),
    aws_secret_access_key=os.getenv('AWS_SECRET_KEY'),
    region_name=os.getenv('AWS_REGION')
)

async def upload_image_to_s3(file, filename: str):
    """
    Uploads an image to AWS S3 and returns the image URL.
    """
    unique_filename = f"{uuid.uuid4()}-{filename}"  # Generate a unique filename
    s3_client.upload_fileobj(file, AWS_S3_BUCKET, unique_filename, ExtraArgs={"ACL": "private", "ContentType": file.content_type})
    
    # Generate a presigned URL for accessing the image
    image_url = f"https://{os.getenv('AWS_S3_BUCKET')}.s3.{os.getenv('AWS_REGION')}.amazonaws.com/{unique_filename}"
    
    return image_url
