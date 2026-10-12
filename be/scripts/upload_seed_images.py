import boto3
import os
import sys
from dotenv import load_dotenv

# Load env vars from .env file
load_dotenv()

# AWS Configuration
BUCKET_NAME = os.getenv("AWS_S3_BUCKET", "barz-images")
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_REGION = os.getenv("AWS_REGION", "sa-east-1")

# Map local filename -> S3 key
# These must match what's in seed_marketing_data.py
IMAGES = {
    "caipirinha.jpeg": "seed/caipirinha.jpeg",
    "morrito.jpg": "seed/morrito.jpg",
    "moscowmule.jpeg": "seed/moscowmule.jpeg",
    "pinacolada.jpeg": "seed/pinacolada.jpeg",
    "pontosavassilogo.jpg": "seed/pontosavassilogo.jpg",
    "porcaobhlogo.jpg": "seed/porcaobhlogo.jpg"
}

def upload_images():
    if not AWS_ACCESS_KEY or not AWS_SECRET_KEY:
        print("❌ Error: AWS credentials not found in .env")
        return

    s3 = boto3.client(
        's3',
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY,
        region_name=AWS_REGION
    )
    
    print(f"🚀 Uploading {len(IMAGES)} images to s3://{BUCKET_NAME}...")
    
    for local_file, s3_key in IMAGES.items():
        if not os.path.exists(local_file):
            print(f"❌ File not found: {local_file}. Please ensure it is in the root directory.")
            continue
            
        try:
            print(f"   📤 Uploading {local_file} -> {s3_key}...")
            # Detect content type based on extension
            content_type = "image/jpeg" if local_file.endswith(".jpeg") or local_file.endswith(".jpg") else "application/octet-stream"
            
            s3.upload_file(
                local_file, 
                BUCKET_NAME, 
                s3_key,
                ExtraArgs={
                    "ContentType": content_type,
                    #"ACL": "public-read" # Uncomment if bucket allows ACLs
                }
            )
            print(f"      ✅ Success: https://{BUCKET_NAME}.s3.amazonaws.com/{s3_key}")
            
        except Exception as e:
            print(f"      ❌ Error uploading {local_file}: {e}")

    print("\n👋 Done! Now run the seed script.")

if __name__ == "__main__":
    upload_images()
