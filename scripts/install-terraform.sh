#!/bin/bash
# Install Terraform on Ubuntu/Debian/WSL
# Usage: ./scripts/install-terraform.sh

set -e

echo "🔧 Installing Terraform..."
echo ""

# Check if already installed
if command -v terraform &> /dev/null; then
    echo "✅ Terraform is already installed: $(terraform version | head -1)"
    echo ""
    read -p "Reinstall anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

echo "Step 1/5: Downloading HashiCorp GPG key..."
wget https://apt.releases.hashicorp.com/gpg -O /tmp/hashicorp-gpg.key

echo ""
echo "Step 2/5: Importing GPG key (requires sudo password)..."
sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp-gpg.key

echo ""
echo "Step 3/5: Adding HashiCorp repository (requires sudo password)..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

echo ""
echo "Step 4/5: Updating package list (requires sudo password)..."
sudo apt update

echo ""
echo "Step 5/5: Installing Terraform (requires sudo password)..."
sudo apt install -y terraform

echo ""
echo "Cleaning up temporary files..."
rm /tmp/hashicorp-gpg.key

echo ""
echo "✅ Terraform installed successfully!"
echo ""
terraform version
echo ""
echo "Run the AWS setup check:"
echo "  ./scripts/check-aws-setup.sh"

