# Cloud + AI Integration Labs 🚀

This repository contains step-by-step **hands-on labs** for integrating **Cloud Computing** and **AI** using **AWS, Terraform, Ansible, GitHub Actions, FastAPI, and SageMaker**.

## 📌 Project Overview
We will build a **Smart Photo Album**:
- Upload an image to **AWS S3**.
- Automatically detect objects/faces using **AWS Rekognition**.
- Store results in **DynamoDB**.
- Expose an API via **FastAPI** (deployed on ECS).
- Automate deployment using **Terraform, Ansible, and GitHub Actions**.
- (Optional) Train a custom classifier with **SageMaker**.

## 📂 Repo Structure
- `terraform/` → Infrastructure as Code for AWS resources.
- `ansible/` → Configuration management for EC2/ECS.
- `app/` → FastAPI app for serving AI results.
- `cicd/` → CI/CD workflow definitions.
- `sagemaker/` → Scripts for training & inference with SageMaker.
- `docs/` → Study materials for the webinar.

## ⚡ Hands-On Labs
1. **Terraform**: Provision AWS infra (S3, DynamoDB, ECS).  
2. **Ansible**: Configure environment (Docker, dependencies).  
3. **FastAPI**: Build an AI-powered API (Rekognition integration).  
4. **Docker & CI/CD**: Containerize app & deploy via GitHub Actions.  
5. **Testing**: Upload an image & analyze results through API.  
6. **SageMaker (optional)**: Train and deploy a custom model.

## ✅ Prerequisites
- AWS Account (with IAM permissions for S3, DynamoDB, ECS, Rekognition, SageMaker).
- Terraform installed.
- Ansible installed.
- Docker installed.
- GitHub account with Actions enabled with the following parameters:
    - AWS Credentials used by Terraform, Ansible and the app to interact with AWS (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION)
    - SSH Credentials used by Ansible (EC2_USERNAME, EC2_PRIVATE_KEY, EC2_PUBLIC_IP)
    - Github Container registry / AWS ECR (If using Docker images, ECR_REPOSITORY & AWS_ACCOUNT_ID)
    - Application Parameters (APP_PORT, API_BASE_URL)

## How to setup parameters in GitHub actions?
1. Fork the Repository `cloud-ai-integration-labs`
2. Select the Repository
3. Go to Settings --> Secrets & Variables --> Actions --> Repository Secrets --> Create New Repository Secret

## 🚀 Quick Start
1. Clone the repo:
   ```bash
   git clone https://github.com/<your-username>/cloud-ai-integration-labs.git
   cd cloud-ai-integration-labs

2. Deploy infra with Terraform:
   ```bash
   cd terraform
   terraform init
   terraform apply

3. Configure servers with Ansible:
   ```bash
   cd ansible
   ansible-playbook -i inventory.ini playbook.yml

4. Deploy FastAPI app via GitHub Actions pipeline (push to main branch).

5. Upload an image to S3 and call the API endpoint:
   ```bash
   curl -X POST http://<api-endpoint>/analyze -F "file=@sample.jpg"
