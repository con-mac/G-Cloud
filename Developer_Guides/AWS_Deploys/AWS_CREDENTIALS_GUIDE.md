# AWS Credentials Setup - Step by Step

## 🔑 Getting Your AWS Access Key and Secret Key

### Step 1: Log in to AWS Console

1. Go to: https://console.aws.amazon.com
2. Log in with your AWS account credentials

### Step 2: Navigate to IAM

1. In the search bar at the top, type: **IAM**
2. Click on **IAM** (Identity and Access Management)

### Step 3: Go to Your User

1. In the left sidebar, click **Users**
2. Click on your username (the user you want to create credentials for)

### Step 4: Create Access Key

1. Click on the **Security credentials** tab
2. Scroll down to **Access keys** section
3. Click **Create access key** button

### Step 5: Choose Use Case

You'll be asked what you'll use this access key for:
- Select: **Application running outside AWS** (this is for Terraform/deployment)
- Click **Next**

### Step 6: Get Both Keys ⚠️ IMPORTANT

After clicking Next, you'll see a page with:

```
Access key ID: AKIAIOSFODNN7EXAMPLE
Secret access key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**⚠️ IMPORTANT:**
- **Copy BOTH keys immediately** - you won't see the Secret Access Key again!
- The Secret Access Key is shown **only once** for security
- Store them somewhere safe (password manager, secure note)

### Step 7: Confirm

1. Check the box: "I understand that I will not be able to access the secret access key again after I close this dialog"
2. Click **Done**

---

## 📋 If You've Already Closed the Dialog

If you closed the dialog before copying the Secret Access Key, you have two options:

### Option 1: Create a New Access Key (Recommended)

1. Go back to: **IAM → Users → Your Username → Security credentials**
2. Scroll to **Access keys** section
3. Click **Create access key** again
4. **Delete the old access key** (since you don't have the secret)
5. Copy both keys from the new key pair

### Option 2: Check If You Saved It

- Check your password manager
- Check your notes/documents
- Check browser history (sometimes browsers save form data)

---

## 💻 Using the Keys in AWS CLI Configure

Once you have both keys:

```bash
aws configure
```

You'll be prompted for:

1. **AWS Access Key ID**: `AKIAIOSFODNN7EXAMPLE`
   - Paste your Access Key ID here

2. **AWS Secret Access Key**: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`
   - Paste your Secret Access Key here

3. **Default region name**: `eu-west-2`
   - Type: `eu-west-2` (London) or your preferred region

4. **Default output format**: `json`
   - Just press Enter (or type `json`)

---

## ✅ Verify It Worked

After running `aws configure`, test it:

```bash
# Check which account you're using
aws sts get-caller-identity
```

You should see:
```json
{
    "UserId": "AIDAIOSFODNN7EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

Or run the check script:
```bash
./scripts/check-aws-setup.sh
```

---

## 🔒 Security Best Practices

1. **Never share your keys** - they give full access to your AWS account
2. **Don't commit keys to Git** - they're already in `.gitignore`
3. **Rotate keys regularly** - change them every 90 days
4. **Use IAM users with limited permissions** - don't use root account keys
5. **Delete unused keys** - remove old access keys you're not using

---

## 🆘 Troubleshooting

### "InvalidAccessKeyId" Error

- Check you copied the Access Key ID correctly (no spaces)
- Ensure you're using the correct region

### "SignatureDoesNotMatch" Error

- You might have the wrong Secret Access Key
- Create a new access key pair

### "Access Denied" Error

- Your IAM user might not have the right permissions
- Contact your AWS administrator or check IAM policies

---

## 📸 Visual Guide

**Where to find it in AWS Console:**

```
AWS Console
  └─ Search: "IAM"
      └─ Users (left sidebar)
          └─ Click your username
              └─ Security credentials tab
                  └─ Access keys section
                      └─ Create access key button
                          └─ Choose: "Application running outside AWS"
                              └─ Next
                                  └─ **COPY BOTH KEYS HERE**
```

---

## 💡 Quick Reference

| What | Where |
|------|-------|
| **Access Key ID** | IAM → Users → Your User → Security credentials → Access keys |
| **Secret Access Key** | Same page, shown only once when you create the key |
| **Can't find Secret Key?** | Create a new access key (old one is gone) |
| **Test credentials** | Run `aws sts get-caller-identity` |

---

**Need help?** Check `AWS_SETUP.md` for more detailed instructions.

