# Questionnaire Testing Guide

## Seeding Test Data for Admin Analytics

To test the admin analytics dashboard, you can seed sample questionnaire responses using the provided script.

### Running the Seed Script

**Local Development:**
```bash
cd backend
python scripts/seed_questionnaire_data.py
```

**Azure Functions (via Azure Portal):**
1. Navigate to Function App → **Advanced Tools (Kudu)** → **Go**
2. Go to **Debug console** → **CMD**
3. Navigate to `site/wwwroot`
4. Run: `python scripts/seed_questionnaire_data.py`

**Azure Functions (via Azure CLI):**
```bash
az functionapp deployment source config-zip \
  --resource-group gcloud-prod-rg \
  --name gcloud-api-prod \
  --src <path-to-zip-with-script>

# Then execute via Kudu or SSH
```

### What Gets Created

The script creates **5 sample questionnaire responses**:

1. **Cloud Infrastructure Services** (LOT 3) - Completed & Locked
2. **Data Analytics Platform** (LOT 2a) - Completed & Locked
3. **Customer Relationship Management** (LOT 2b) - Draft (not locked)
4. **Security Monitoring Service** (LOT 3) - Completed (not locked)
5. **Business Intelligence Tool** (LOT 2a) - Draft (not locked)

### Sample Data Details

- **Service Name questions**: Pre-filled with actual service names
- **Text questions**: Sample answers generated
- **Radio buttons**: First option selected
- **Checkboxes**: First 2-3 options selected
- **List questions**: 3-5 sample items (systems requirements has 5 items)
- **Textarea questions**: Sample detailed responses

### Verifying Seeded Data

**Check in Admin Analytics Dashboard:**
1. Navigate to `/admin/analytics`
2. You should see:
   - 5 services with responses
   - 2 services locked
   - 3 services in draft
   - Analytics charts populated with sample data

**Check Storage:**
- **Azure**: Check Storage Account → Container `sharepoint` → `GCloud 15/PA Services/Cloud Support Services LOT {lot}/{service_name}/questionnaire_responses.json`
- **Local**: Check `mock_sharepoint/GCloud 15/PA Services/Cloud Support Services LOT {lot}/{service_name}/questionnaire_responses.json`

### Cleaning Up Test Data

To remove seeded data:

**Azure:**
```bash
az storage blob delete-batch \
  --account-name gcloudprodst \
  --source sharepoint \
  --pattern "GCloud 15/PA Services/Cloud Support Services LOT */Cloud Infrastructure Services/questionnaire_responses.json"
# Repeat for each service
```

**Local:**
```bash
rm -rf mock_sharepoint/GCloud\ 15/PA\ Services/Cloud\ Support\ Services\ LOT\ */{Cloud\ Infrastructure\ Services,Data\ Analytics\ Platform,Customer\ Relationship\ Management,Security\ Monitoring\ Service,Business\ Intelligence\ Tool}/questionnaire_responses.json
```

---

## Validation Testing

### List Question Validation

The "What systems requirements does your service have" question (and other list questions) now has validation:

**Rules:**
- Maximum **10 items** per list
- Maximum **10 words** per item
- Word count excludes numbered prefixes (e.g., "1. ")

**Testing:**
1. Navigate to questionnaire
2. Find a list question (e.g., "What systems requirements does your service have")
3. Try adding more than 10 items → Should show error
4. Try entering an item with more than 10 words → Should show error
5. Verify word count displays correctly

### Encoding Fix Testing

The parser now fixes encoding issues from Excel:
- `â€™` → `'` (apostrophe)
- `â€"` → `"` (quotes)

**To verify:**
1. Check questionnaire questions display correctly
2. No `â€™` characters should appear
3. Apostrophes and quotes should render properly

---

## Admin Analytics Testing Checklist

- [ ] Seed questionnaire data using script
- [ ] Verify services appear in Analytics dashboard
- [ ] Check completion statistics (2 completed, 3 draft)
- [ ] Verify locked services show correctly
- [ ] Test drill-down functionality on questions
- [ ] Check LOT filtering works
- [ ] Verify charts display correctly
- [ ] Test lock functionality from admin dashboard
- [ ] Verify "not started" services list works

---

## Troubleshooting

### Seed Script Fails

**Error: "Questionnaire parser not available"**
- Ensure Excel file is in `docs/` folder
- Check file path in parser initialization

**Error: "Storage connection failed"**
- Verify `AZURE_STORAGE_CONNECTION_STRING` is set (for Azure)
- Check Storage Account exists and is accessible

### Validation Not Working

**List validation not showing errors:**
- Check browser console for JavaScript errors
- Verify question type is correctly identified as 'list'
- Check that validation functions are called on input change

### Encoding Issues Persist

**Still seeing â€™ characters:**
- The parser fixes this automatically
- If issues persist, check Excel file encoding
- Try saving Excel as UTF-8 CSV and re-importing

---

**Last Updated**: 2025-01-28

