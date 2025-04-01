from urllib.parse import urlparse
import boto3
import uuid
import os
import asyncio
import functools
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

async def upload_image_to_s3(upload_obj, filename: str):
    """
    Uploads an image to AWS S3 and returns the image URL.
    
    'upload_obj' can be either an UploadFile instance or a file object.
    """
    unique_filename = f"{uuid.uuid4()}-{filename}"  # Generate a unique filename
    bucket_name = os.getenv('AWS_S3_BUCKET')
    region = os.getenv('AWS_REGION')
    loop = asyncio.get_running_loop()

    # Check if upload_obj has a "file" attribute; if not, assume it's already a file-like object.
    file_obj = upload_obj.file if hasattr(upload_obj, "file") else upload_obj

    try:
        await loop.run_in_executor(
            None,
            functools.partial(
                s3_client.upload_fileobj,
                file_obj,
                bucket_name,
                unique_filename,
                ExtraArgs={"ACL": "private", "ContentType": getattr(upload_obj, "content_type", "application/octet-stream")}
            )
        )
        print(f"Uploaded file successfully: {unique_filename} to bucket {bucket_name}")
    except Exception as e:
        print(f"Error uploading file: {e}")
        raise e

    try:
        # Generate the image URL (for private images, consider using a presigned URL)
        image_url = f"https://{bucket_name}.s3.{region}.amazonaws.com/{unique_filename}"
        print(f"Generated image URL: {image_url}")
    except Exception as e:
        print(f"Error generating image URL: {e}")
        raise e

    return image_url

def generate_presigned_url(object_name: str, expiration=3600):
    """
    Generate a pre-signed URL for accessing an S3 object.
    
    :param object_name: The name of the file in S3.
    :param expiration: Expiration time in seconds (default 1 hour).
    :return: A pre-signed URL string.
    """
    try:
        bucket_name = os.getenv('AWS_S3_BUCKET')
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': object_name},
            ExpiresIn=expiration
        )
        return url
    except Exception as e:
        print(f"Error generating pre-signed URL: {e}")
        return None
    
def extract_s3_key(url: str):
    """Extracts the object key from a full S3 URL."""
    parsed_url = urlparse(url)
    return parsed_url.path.lstrip('/')  # Remove leading '/'