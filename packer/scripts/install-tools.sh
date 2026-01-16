#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y build-essential ca-certificates curl git gnupg jq lsb-release software-properties-common unzip wget zip

# Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker

# AWS CLI
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install && rm -rf /tmp/awscliv2.zip /tmp/aws

# Terraform
curl -fsSL "https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip" -o /tmp/terraform.zip
sudo unzip -q /tmp/terraform.zip -d /usr/local/bin && rm /tmp/terraform.zip

# Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Python
sudo apt-get install -y python3 python3-pip python3-venv

# Go
curl -fsSL "https://go.dev/dl/go1.22.2.linux-amd64.tar.gz" -o /tmp/go.tar.gz
sudo tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh

# kubectl
curl -fsSL "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /tmp/kubectl
sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl && rm /tmp/kubectl

# Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Trivy
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install -y trivy

echo "Build tools installed"
