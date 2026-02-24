#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════════
#  EC2 One-Time Setup Script
#  Tested on: Ubuntu 22.04 LTS (ami-0c55b159cbfafe1f0 / ami-0261755bbcb8c4a84)
#
#  Run as the default user (ubuntu / ec2-user) with sudo.
#  It will install:
#    - Docker Engine (latest stable)
#    - Docker Compose plugin (v2)
#    - AWS CLI v2
#    - curl, wget, unzip (utilities used by the deploy script)
#
#  The EC2 instance should have an IAM Instance Role attached with the policy:
#    AmazonEC2ContainerRegistryReadOnly
#  This lets the deploy script pull images from ECR without any stored keys.
# ════════════════════════════════════════════════════════════════════════════════

set -euo pipefail

echo "════════════════════════════════════════════"
echo " EC2 Bootstrap — MEAN Stack"
echo "════════════════════════════════════════════"

# ── 1. System update ──────────────────────────────────────────────────────────
sudo apt-get update -y
sudo apt-get upgrade -y

# ── 2. Install utilities ──────────────────────────────────────────────────────
sudo apt-get install -y \
  curl wget unzip git ca-certificates gnupg lsb-release

# ── 3. Docker Engine (official repo, not the Ubuntu snap) ─────────────────────
echo "Installing Docker Engine..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ── 4. Allow current user to run Docker without sudo ─────────────────────────
sudo usermod -aG docker "$USER"
echo "NOTE: Log out and back in (or run 'newgrp docker') for the group to take effect."

# ── 5. Enable Docker to start on boot ────────────────────────────────────────
sudo systemctl enable docker
sudo systemctl start docker

# ── 6. AWS CLI v2 ─────────────────────────────────────────────────────────────
echo "Installing AWS CLI v2..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws
aws --version

# ── 7. Create app directory ───────────────────────────────────────────────────
mkdir -p ~/app
echo "App directory: ~/app (docker-compose.prod.yml will be deployed here)"

# ── 8. Configure Docker daemon for log rotation & memory efficiency ───────────
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF
sudo systemctl restart docker

# ── 9. (Optional) Kernel parameters for MongoDB performance ──────────────────
# Transparent Huge Pages — MongoDB recommends disabling THP
echo "Configuring kernel parameters for MongoDB..."
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

# Make it persistent across reboots
sudo tee /etc/rc.local > /dev/null << 'RCEOF'
#!/bin/bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
exit 0
RCEOF
sudo chmod +x /etc/rc.local

# ── 10. Verify installs ───────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " Versions installed"
echo "════════════════════════════════════════════"
docker --version
docker compose version
aws --version

echo ""
echo "════════════════════════════════════════════"
echo " Next steps"
echo "════════════════════════════════════════════"
echo "1. Attach an IAM Instance Role to this EC2 with AmazonEC2ContainerRegistryReadOnly"
echo "2. Open Security Group inbound ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
echo "3. Add the following GitHub Secrets to your repo:"
echo "     AWS_ROLE_ARN, AWS_REGION, ECR_REGISTRY, ECR_BACKEND_REPO, ECR_FRONTEND_REPO"
echo "     EC2_HOST, EC2_USER, EC2_SSH_KEY, MONGO_URI, CORS_ORIGIN"
echo "4. Push to main/master branch to trigger the CI/CD pipeline."
echo ""
echo "Bootstrap complete!"
