from flask import Flask, request, jsonify, render_template
import boto3
import os
import uuid

app = Flask(__name__)

# AWS Clients
s3 = boto3.client("s3", region_name=os.getenv("AWS_REGION", "ap-south-1"))
rekognition = boto3.client("rekognition", region_name=os.getenv("AWS_REGION", "ap-south-1"))
dynamodb = boto3.resource("dynamodb", region_name=os.getenv("AWS_REGION", "ap-south-1"))

# Environment variables
BUCKET_NAME = os.getenv("S3_BUCKET")
TABLE_NAME = os.getenv("DYNAMODB_TABLE")

@app.route("/", methods=["GET"])
def home():
    return jsonify({"message": "Smart Photo Album API is running 🚀"})

@app.route("/upload", methods=["GET", "POST"])
def upload_file():
    labels = []      # initialize variables
    faces = []
    image_url = None
    error = None

    if request.method == "POST":
        if "file" not in request.files:
            error = "No file uploaded"
        else:
            file = request.files["file"]
            file_key = f"{uuid.uuid4()}-{file.filename}"

            try:
                # Upload to S3
                s3.upload_fileobj(
                    file, 
                    BUCKET_NAME, 
                    file_key, 
                    ExtraArgs={"ACL": "public-read", "ContentType": file.content_type}
                )

                
                image_url = f"https://{BUCKET_NAME}.s3.amazonaws.com/{file_key}"

                # Rekognition
                response = rekognition.detect_labels(
                    Image={"S3Object": {"Bucket": BUCKET_NAME, "Name": file_key}},
                    MaxLabels=5,
                    MinConfidence=80
                )
                labels = [{"Name": l["Name"], "Confidence": l["Confidence"]} for l in response["Labels"]]

                # Deetct faces
                face_resp = rekognition.detect_faces(
                    Image={"S3Object": {"Bucket": BUCKET_NAME, "Name": file_key}},
                    Attributes=["ALL"]
                )
                for face in face_resp["FaceDetails"]:
                    faces.append({
                        "Gender": face["Gender"]["Value"],
                        "GenderConfidence": face["Gender"]["Confidence"],
                        "Emotions": sorted(face["Emotions"], key=lambda e: e["Confidence"], reverse=True)[:3],
                        "Smile": face["Smile"]["Value"],
                        "SmileConfidence": face["Smile"]["Confidence"]
                    })

            except Exception as e:
                error = str(e)

    return render_template("upload.html", labels=labels, faces=faces, image_url=image_url, error=error)

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