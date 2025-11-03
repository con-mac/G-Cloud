# Installing Terraform

## Quick Install (Ubuntu/Debian/WSL)

Run these commands **one at a time** in your terminal (you'll need to enter your password for sudo):

```bash
# Step 1: Download the GPG key first (no sudo needed)
wget https://apt.releases.hashicorp.com/gpg -O /tmp/hashicorp-gpg.key

# Step 2: Import the GPG key (requires password)
sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp-gpg.key

# Step 3: Add HashiCorp's repository (requires password)
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Step 4: Update package list (requires password)
sudo apt update

# Step 5: Install Terraform (requires password)
sudo apt install -y terraform

# Step 6: Verify installation (no sudo needed)
terraform version

# Step 7: Clean up temporary file
rm /tmp/hashicorp-gpg.key
```

**Note:** The pipe (`|`) in the original command can cause issues. By downloading to a file first, then importing, we avoid pipe-related problems.

## Alternative: Manual Installation (No Sudo Required)

If you don't have sudo access or prefer a local installation:

```bash
# 1. Download Terraform
cd ~
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip

# 2. Unzip
unzip terraform_1.6.0_linux_amd64.zip

# 3. Move to a location in your PATH (or add to PATH)
mkdir -p ~/bin
mv terraform ~/bin/

# 4. Add to PATH (add this to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/bin:$PATH"

# 5. Reload shell or run:
source ~/.bashrc  # or source ~/.zshrc

# 6. Verify
terraform version
```

## Alternative: Using tfenv (Version Manager)

If you want to manage multiple Terraform versions:

```bash
# Install tfenv
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Install latest Terraform
tfenv install latest
tfenv use latest

# Verify
terraform version
```

## Verify Installation

After installing, verify it works:

```bash
terraform version
```

You should see:
```
Terraform v1.6.0
```

Then run the AWS setup check again:
```bash
./scripts/check-aws-setup.sh
```

All checks should pass! ✅

