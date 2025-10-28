# 📝 G-Cloud Template-Based Proposal Creation Guide

## 🎉 New Feature: Create Proposals from Templates!

Your system now includes a comprehensive template-based proposal creation feature that follows **G-Cloud v15 standards** with **PA Consulting branding**.

---

## 🚀 Quick Start

### **Access the Feature:**
```
http://localhost:3000/proposals/create
```

###  **Create Your First Proposal:**
1. Click **"Create New Proposal"** button on the main Proposals page
2. Select **"G-Cloud Service Description"** template
3. Fill in the 4 required sections
4. Watch real-time validation as you type
5. Click **"Generate Documents"** when all sections are valid
6. Download your branded Word document

---

## 📋 G-Cloud v15 Service Description Template

### **4 Required Sections:**

#### **1️⃣ Service Name (Title)**
- **Editable**: YES
- **Placeholder**: "ENTER TITLE HERE"
- **Rules**: Just the service name, no extra keywords
- **Validation**: Max 10 words
- **Example**: "AI Security", "Cloud Storage Pro", "Data Analytics Platform"

#### **2️⃣ Short Service Description**
- **Editable Section Title**: NO (fixed as "Short Service Description")
- **Content**: YES (large textarea)
- **Rules**: Summary describing what your service is for
- **Validation**: 50-500 words
- **Real-time**: Word count progress bar (green when valid, red when invalid)
- **Guidance**: Explain the purpose and core functionality of your service

#### **3️⃣ Key Service Features**
- **Editable Section Title**: NO (fixed as "Key Service Features")
- **Content**: YES (dynamic list)
- **Rules**: 10 words maximum per feature, maximum 10 features
- **Add/Remove**: ✅ Add Feature button, ❌ Delete icon per item
- **Validation**: Each feature validated individually
- **Guidance**: List technical features like "system design and assurance" or "help choosing systems and vendors"

#### **4️⃣ Key Service Benefits**
- **Editable Section Title**: NO (fixed as "Key Service Benefits")
- **Content**: YES (dynamic list)
- **Rules**: 10 words maximum per benefit, maximum 10 benefits
- **Add/Remove**: ✅ Add Benefit button, ❌ Delete icon per item
- **Validation**: Each benefit validated individually
- **Guidance**: Use active phrases showing how your service helps users, e.g., "reduces deployment times" or "reduces business risk and costs"

---

## ✅ Validation System

### **Real-Time Validation:**
- ✅ **Green chip with checkmark** = Section is valid
- ❌ **Red chip with error icon** = Section has errors
- **Word counters** update as you type
- **Progress bars** show completion (green/red)
- **Inline error messages** explain what needs fixing

### **Validation Rules (G-Cloud v15 Compliant):**

| Section | Min | Max | Type | Notes |
|---------|-----|-----|------|-------|
| **Title** | 1 word | 10 words | Text | Service name only, no keywords |
| **Description** | 50 words | 500 words | Textarea | Summary of service purpose |
| **Features** | 1 feature | 10 features | List | 10 words each |
| **Benefits** | 1 benefit | 10 benefits | List | 10 words each |

---

## 🎨 UI Design (PA Consulting Style)

### **Colors:**
- Primary Blue: `#003DA5` (buttons, headers)
- Success Green: `#28A745` (valid indicators)
- Error Red: `#DC3545` (invalid indicators)
- Background: `#F5F7FA` (clean, professional)

### **Features:**
- **Clean card-based layout** for each section
- **Real-time word counters** below each input
- **Color-coded validation chips** at top of each card
- **Progress bars** for word count limits
- **Smooth animations** on validation changes
- **Professional typography** matching PA Consulting brand

---

## 📄 Document Generation

### **What Gets Generated:**

#### **Word Document (.docx):**
- ✅ **PA Consulting branding** (logo, colors, formatting)
- ✅ **11 images** from template preserved
- ✅ **2 tables** from template preserved
- ✅ **Exact formatting** matching the example template
- ✅ **Your content** inserted in correct sections:
  - Title → Heading 1
  - Description → After "Short Service Description" heading
  - Features → Bullet list under "Key Service Features"
  - Benefits → Bullet list under "Key Service Benefits"

#### **PDF Document:**
- 🔄 **Coming Soon**: PDF generation will be added in next update
- Currently shows "Coming Soon" button in success dialog

### **Download:**
After successful generation, a modal appears with:
- ✅ **Word Document** - Ready to download
- ⏳ **PDF Document** - Coming soon
- 🔄 **"Create Another"** button - Start fresh
- ✓ **"Done"** button - Return to proposals list

---

## 🔧 Technical Implementation

### **Backend API:**
```
POST   /api/v1/templates/service-description/generate
GET    /api/v1/templates/service-description/download/{filename}
GET    /api/v1/templates
```

### **Frontend Routes:**
```
/proposals/create                           → Template selection
/proposals/create/service-description       → Form with 4 sections
```

### **Document Generation:**
- Uses **python-docx** library
- Clones PA Consulting template
- Replaces content while preserving formatting
- Saves to `/app/generated_documents/`
- Auto-cleanup of old files (7 days)

---

## 💡 Tips for Best Results

### **Title Tips:**
- ✅ "AI Security Consulting"
- ✅ "Cloud Infrastructure Management"
- ❌ "AI Security Consulting for Government and Enterprise with 24/7 Support" (too long, includes keywords)

### **Description Tips:**
- Start with what the service does
- Explain who it's for
- Mention key capabilities
- Keep it between 50-500 words
- Write in clear, professional language

### **Features Tips:**
- One feature per line
- Max 10 words each
- Focus on technical capabilities
- Examples:
  - "Real-time threat detection and response"
  - "AI-powered security analysis and reporting"
  - "24/7 monitoring and incident management"

### **Benefits Tips:**
- Use active phrases
- Show how it helps users
- Max 10 words each
- Examples:
  - "Reduces security incident response time by 80%"
  - "Increases system uptime and reliability"
  - "Lowers operational costs through automation"

---

## 🎯 Example: Creating "AI Security" Proposal

### **Step 1: Enter Title**
```
AI Security
```
*Validation: ✅ Valid (2/10 words)*

### **Step 2: Write Description** (200 words)
```
Our AI Security service provides comprehensive protection for artificial 
intelligence systems and machine learning infrastructure. We help 
organisations secure their AI/ML pipelines, protect training data, and 
ensure model integrity throughout the development lifecycle.

The service includes threat detection specifically designed for AI systems,
vulnerability assessment of machine learning models, and secure deployment 
frameworks. We address unique challenges such as adversarial attacks, data 
poisoning, and model extraction attempts.

Our team of AI security specialists combines deep expertise in both 
cybersecurity and artificial intelligence. We provide 24/7 monitoring, 
incident response, and continuous improvement of your AI security posture.

The service is designed for organisations deploying AI systems in sensitive 
environments, including government agencies, financial services, healthcare, 
and critical infrastructure. We ensure compliance with relevant security 
standards and regulatory requirements.

We offer flexible engagement models including advisory services, managed 
security operations, and hands-on implementation support. Our approach 
integrates seamlessly with existing DevSecOps practices and security tools.
```
*Validation: ✅ Valid (200/500 words)*

### **Step 3: List Features** (10 features, 8-10 words each)
1. "AI threat detection and real-time security monitoring"
2. "Machine learning model vulnerability assessment and testing"
3. "Secure AI development lifecycle implementation and support"
4. "Data privacy protection for training datasets"
5. "Adversarial attack prevention and model hardening"
6. "Automated security scanning of AI infrastructure"
7. "Compliance monitoring for AI regulatory requirements"
8. "Security incident response for AI systems"
9. "Model integrity verification and validation processes"
10. "Integration with existing DevSecOps and security tools"

*Validation: ✅ Valid (10/10 features)*

### **Step 4: List Benefits** (10 benefits, 7-10 words each)
1. "Reduces AI security incidents by 85 percent"
2. "Protects intellectual property in machine learning models"
3. "Ensures regulatory compliance for AI deployments"
4. "Accelerates secure AI development and deployment timelines"
5. "Minimises risk of data breaches in training"
6. "Increases stakeholder confidence in AI system security"
7. "Lowers costs through automated security monitoring"
8. "Provides peace of mind with 24/7 expert support"
9. "Improves AI system resilience against cyber attacks"
10. "Enables faster adoption of AI technologies securely"

*Validation: ✅ Valid (10/10 benefits)*

### **Step 5: Submit & Download**
Click **"Generate Documents"** → Success modal appears → Download Word document

---

## 📊 What Happens Behind the Scenes

1. **Form Submission** → Sends data to backend API
2. **Validation** → Server validates all rules again
3. **Template Cloning** → Copies PA Consulting Word template
4. **Content Replacement**:
   - Title replaces "AI Security" in Heading 1
   - Description replaces text after "Short Service Description"
   - Features become bullet list under "Key Service Features"
   - Benefits become bullet list under "Key Service Benefits"
5. **Document Saving** → Saves to generated_documents folder
6. **Response** → Returns file paths to frontend
7. **Download** → User clicks download link

---

## 🔮 Coming Soon: Pricing Document Template

The second template is in development:
- **G-Cloud Pricing Document**
- Different validation rules
- Pricing-specific sections
- Same PA Consulting branding
- Same easy-to-use interface

---

## 🆘 Troubleshooting

### **"Generate Documents" button is disabled:**
- Check all sections have ✅ green validation chips
- Ensure title is not empty
- Verify description is 50-500 words
- Check features/benefits are within limits
- Look for red error messages

### **Word count seems wrong:**
- System counts actual words (splits on whitespace)
- Extra spaces don't count as words
- Empty lines are ignored
- Special characters count as part of words

### **Download button doesn't work:**
- Check browser popup blocker
- Verify backend is running: `docker-compose ps`
- Check backend logs: `docker-compose logs backend`

---

## 📞 Need Help?

- **API Documentation**: http://localhost:8000/docs
- **Full System Test**: `./test_full_system.sh`
- **Check Logs**: `docker-compose logs -f backend`

---

**Built with ❤️ using Sequential Thinking MCP**
**Compliant with G-Cloud v15 Standards**
**Styled to match PA Consulting Brand**

