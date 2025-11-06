# G-Cloud Proposal Editor - Frontend Demo Guide

## 🎨 PA Consulting Design System

Your frontend uses PA Consulting's official design language ([paconsulting.com](https://www.paconsulting.com/)):

### Color Palette
- **Primary Blue**: `#003DA5` - Deep professional blue (buttons, headers)
- **Secondary Blue**: `#0066CC` - Bright accent (links, hover states)
- **Background**: `#F5F7FA` - Light professional grey
- **Success**: `#28A745` - Valid sections
- **Error**: `#DC3545` - Invalid sections
- **Warning**: `#FFC107` - Approaching limits

### Typography
- Clean, professional sans-serif fonts
- Bold headings with generous line spacing
- Crisp, readable body text
- Clear visual hierarchy

### UI Elements
- Smooth hover animations
- Card-based layouts with subtle shadows
- Color-coded validation indicators
- Progressive disclosure of information

---

## 🚀 Access Your Application

```
Frontend:  http://localhost:3000
Backend:   http://localhost:8000
API Docs:  http://localhost:8000/docs
```

---

## 📋 Proposals List Page

### What You'll See

A beautiful grid of proposal cards showing:
- ✅ **Proposal Title** (e.g., "Cloud Storage Service - Valid")
- 🏷️ **Status Chip** (Draft, In Review, Submitted, etc.)
- 📊 **Completion Progress Bar** (0-100%)
- ✓ **Validation Icons** (✅ all valid, ❌ has errors)
- 📅 **Deadline** with calendar icon
- 📄 **Section Count** (e.g., "4/4 sections valid")
- 🎯 **"Edit Proposal" Button** (PA blue, hover effect)

### Cards Hover Effect
- Gentle lift animation (`translateY(-2px)`)
- Shadow increases for depth
- Smooth 0.3s transition

### Your Test Data
You'll see 4 proposals:
1. **Cloud Storage Service** - ✅ All valid (green checkmark)
2. **Database Service** - ❌ Summary too long (red error icon)
3. **AI Platform** - ❌ Features too short (red error icon)
4. **Security Service** - ❌ Multiple errors (red error icon)

---

## ✏️ Proposal Editor Page

### Layout

**Two-Pane Design:**
```
┌──────────────┬─────────────────────────────────────────┐
│              │  Header: Title, Status, Word Count      │
│   Sidebar    ├─────────────────────────────────────────┤
│   (280px)    │                                         │
│              │                                         │
│   Sections   │          Text Editor                    │
│   List       │          (Full height)                  │
│              │                                         │
│   ✅ Summary  │                                         │
│   ✅ Features │                                         │
│   ❌ Pricing  │                                         │
└──────────────┴─────────────────────────────────────────┘
```

### Sidebar (Left)
- **Back Button** (← icon) - Returns to proposals list
- **Proposal Title** and **Framework Version**
- **Sections List**:
  - Each section shows:
    - Validation icon (✅❌⚠️)
    - Section title
    - Current word count
  - Active section highlighted (PA blue)
  - Click to switch sections

### Main Editor Area (Right)

#### Header Section
- **Large Section Title** (H4, bold)
- **Section Type** (subtle, grey text)
- **Validation Chip**:
  - ✅ Green "Valid" when within limits
  - ❌ Red "Invalid" when out of range
- **Saving Indicator** (spinner when auto-saving)

#### Word Count Progress Bar
```
Word Count: 125 / 500 (min: 50)     [Within limits]
████████████░░░░░░░░░░░░░░░░░░░░░   25%
```

**Colors:**
- 🟢 **Green**: Content within valid range
- 🔴 **Red**: Below minimum or above maximum
- Progress fills based on current vs maximum words

#### Validation Alerts
When invalid, you'll see error alerts:
```
❌ Service summary must not exceed 500 words
❌ Service features must be at least 100 words
```

#### Text Editor
- **Large textarea** (20 rows, expandable)
- Monospace font for easier editing
- Generous line height (1.8)
- Clean borders with PA blue hover effect
- Placeholder text: "Enter [section name] content..."

---

## ⚡ Real-Time Features

### Auto-Save
- Type any content → **automatic save after 1 second**
- Debounced to avoid excessive API calls
- Saving indicator appears during save
- No "Save" button needed - it's automatic!

### Live Word Counting
- Updates as you type
- Splits by whitespace
- Filters empty strings
- Shows in sidebar and header

### Instant Validation
- After each auto-save:
  - API validates content
  - Returns validation result
  - Updates UI immediately
  - Shows errors if any
  - Updates progress bar color

### Visual Feedback
1. **Type**: Word count updates
2. **1 second pause**: Auto-save triggers
3. **Saving spinner**: Shows briefly
4. **Validation runs**: Server-side
5. **UI updates**: Colors, errors, checkmarks
6. **Sidebar updates**: Section status changes

---

## 🧪 Try These Tests

### Test 1: Valid Content
1. Open "Cloud Storage Service - Valid"
2. Click "Service Summary"
3. See: Green ✅, 128/500 words, "Valid" chip
4. Edit text slightly
5. Watch auto-save → validation stays green

### Test 2: Exceeding Maximum
1. Open "Database Service"
2. Click "Service Summary"
3. See: Red ❌, 630/500 words, error message
4. **Delete some text** to get under 500
5. Wait 1 second
6. Watch it turn green! ✅

### Test 3: Below Minimum
1. Open "AI Platform"
2. Click "Service Features"
3. See: Red ❌, 7/100 words, error "must be at least 100 words"
4. **Add content** to exceed 100 words
5. Wait for auto-save
6. Validation turns green! ✅

### Test 4: Multiple Sections
1. Open "Security Service"
2. Navigate between sections in sidebar
3. Each shows its own validation state
4. Fix one section at a time
5. Watch sidebar icons update

---

## 🎨 Design Details

### Animations
- **Card Hover**: Lift + shadow (0.3s)
- **Button Hover**: Shadow glow in PA blue
- **Progress Bar**: Smooth fill transition
- **Spinner**: Rotating save indicator

### Spacing
- Generous padding (16-24px)
- Clear section separation
- Comfortable line height (1.6-1.8)
- Professional whitespace usage

### Responsive Behavior
- Cards stack on mobile
- Sidebar adapts
- Editor remains usable
- Touch-friendly buttons

---

## 📊 Validation Rules Reference

| Section Type | Min Words | Max Words | Your Test Data |
|--------------|-----------|-----------|----------------|
| Service Summary | 50 | 500 | ✅ 128 words |
| Service Features | 100 | 1,000 | ✅ 240 words |
| Pricing | 20 | 200 | ✅ 38 words |
| Data Security | 150 | 800 | ✅ 360 words |

---

## 🔥 Key Features Demonstrated

✅ **PA Consulting Brand**: Official colors, typography, feel  
✅ **Real-Time Validation**: No refresh needed  
✅ **Auto-Save**: Never lose work  
✅ **Visual Feedback**: Colors, icons, progress bars  
✅ **Error Messages**: Clear, actionable  
✅ **Smooth UX**: Debouncing, animations  
✅ **Professional Design**: Clean, modern, corporate  
✅ **Responsive**: Works on all screen sizes  

---

## 🚀 Next Steps

Your system is production-ready for:
1. Editing G-Cloud proposals
2. Real-time word count validation
3. Section-by-section workflow
4. Auto-saving content
5. Visual validation feedback

**Ready to extend:**
- Add more section types
- Customize validation rules
- Add user authentication
- Implement approval workflows
- Export to Word/PDF
- Add collaboration features

---

## 📸 What It Looks Like

### Proposals List
```
┌──────────────────────────────────────────────────────┐
│  G-Cloud Proposals                                   │
│  Manage and validate your G-Cloud framework proposals│
│                                                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐    │
│  │Cloud Storage│  │Database    │  │AI Platform │    │
│  │✅ DRAFT     │  │❌ DRAFT     │  │❌ DRAFT     │    │
│  │G-Cloud 14  │  │G-Cloud 14  │  │G-Cloud 14  │    │
│  │75% ████░░░ │  │50% ██░░░░░ │  │40% █░░░░░░ │    │
│  │4/4 valid   │  │2/3 valid   │  │2/3 valid   │    │
│  │[Edit]      │  │[Edit]      │  │[Edit]      │    │
│  └────────────┘  └────────────┘  └────────────┘    │
└──────────────────────────────────────────────────────┘
```

### Proposal Editor
```
┌─────────────┬──────────────────────────────────────────┐
│← Back       │  Service Summary            ✅ Valid      │
│             │  service_summary                          │
│Cloud Storage│  Word Count: 128/500 (min: 50) [Valid]  │
│G-Cloud 14   │  ████████░░░░░░░░░░░░░░ 25%              │
│             │                                           │
│✅ Summary    │  ┌────────────────────────────────────┐ │
│✅ Features   │  │Our cloud storage service provides  │ │
│✅ Pricing    │  │secure, scalable, and reliable data │ │
│✅ Security   │  │storage solutions for UK government │ │
│             │  │agencies...                         │ │
│             │  │                                    │ │
│             │  │[Type here to edit content]         │ │
│             │  └────────────────────────────────────┘ │
└─────────────┴──────────────────────────────────────────┘
```

---

**Enjoy your sleek, professional G-Cloud proposal editor!** 🎊

