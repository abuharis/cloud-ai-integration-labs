from flask import Flask, request, jsonify
import boto3
import os
import uuid

app = Flask(__name__)

# AWS Clients
s3 = boto3.client("s3", region_name=os.getenv("AWS_REGION", "us-east-1"))
rekognition = boto3.client("rekognition", region_name=os.getenv("AWS_REGION", "us-east-1"))
dynamodb = boto3.resource("dynamodb", region_name=os.getenv("AWS_REGION", "us-east-1"))

# Environment variables
BUCKET_NAME = os.getenv("S3_BUCKET")
TABLE_NAME = os.getenv("DYNAMODB_TABLE")

@app.route("/", methods=["GET"])
def home():
    return jsonify({"message": "Smart Photo Album API is running 🚀"})

@app.route("/upload", methods=["POST"])
def upload_file():
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]
    file_key = f"{uuid.uuid4()}-{file.filename}"

    try:
        # Upload to S3
        s3.upload_fileobj(file, BUCKET_NAME, file_key)
        return jsonify({"message": "File uploaded", "file_key": file_key}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/analyze/<file_key>", methods=["GET"])
def analyze_file(file_key):
    try:
        # Call Rekognition
        response = rekognition.detect_labels(
            Image={"S3Object": {"Bucket": BUCKET_NAME, "Name": file_key}},
            MaxLabels=5
        )

        labels = [label["Name"] for label in response["Labels"]]

        # Store in DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(
            Item={
                "file_key": file_key,
                "labels": labels
            }
        )

        return jsonify({"file_key": file_key, "labels": labels}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)