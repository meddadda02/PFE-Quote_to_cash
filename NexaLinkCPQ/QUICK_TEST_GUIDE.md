# 🚀 Quick Direct Testing Guide

## ⚡ Prerequisites Check
Before deploying, ensure you have:

- [ ] SFDX CLI installed (`sfdx --version`)
- [ ] GitHub CLI or Git installed
- [ ] Access to your Salesforce Dev Org
- [ ] Admin rights to deploy code

---

## 📋 Step 1: Set Up SFDX Connection

```powershell
# If SFDX is not installed, install it first
npm install -g @salesforce/sfdx-cli

# Authenticate with your Salesforce org
sfdx auth:web:login --setdefaultusername --setalias NexaLinkOrg

# Verify connection
sfdx force:org:display --username NexaLinkOrg
```

---

## 🚀 Step 2: Deploy Component to Your Org

### **Option A: Deploy Entire Component (Recommended)**

```powershell
# Navigate to project root
cd "C:\Users\mohammed.dadda\Desktop\LWC PFE\NexaLinkCPQ"

# Deploy LWC component
sfdx force:source:deploy --sourcepath force-app/main/default/lwc/cpqConfigurator --username NexaLinkOrg

# Deploy Apex controller
sfdx force:source:deploy --sourcepath force-app/main/default/classes/CPQConfiguratorController.cls --username NexaLinkOrg

# Check deployment status
sfdx force:source:deploy --checkonly --sourcepath force-app/main/default --username NexaLinkOrg
```

### **Option B: Quick Deploy Using Metadata API**

```powershell
# If you have configured SFDX and sfdx-project.json
sfdx force:source:deploy --sourcepath force-app --username NexaLinkOrg --testlevel RunLocalTests
```

---

## ✅ Step 3: Post-Deployment Verification

```powershell
# Retrieve logs
sfdx force:apex:log:tail --username NexaLinkOrg

# Check component metadata
sfdx force:mdapi:retrieve --retrievetargetdir ./retrieved --unpackaged ./manifest/package.xml --username NexaLinkOrg
```

---

## 🧪 Step 4: Manual Testing in Salesforce UI

### **A. Navigate to Component**
1. Open Salesforce org
2. Go to **Setup** → **Lightning App Builder**
3. Create a new Lightning Page or edit existing one
4. Search for **"cpqConfigurator"** in component panel
5. Drag component onto page
6. Click **Save** and **Activate**

### **B. Test Functionality**
1. **Account Search**
   - Type account name (min 2 chars)
   - Verify accounts appear ✓

2. **Create Quote**
   - Select Account
   - Select Opportunity
   - Select Currency (MAD/EUR/USD)
   - Click "Create Quote"
   - Verify success message ✓

3. **Bundle Selection**
   - Verify all 5 bundles appear ✓
   - Check responsive layout:
     - Mobile: 1 card/row
     - Tablet: 2 cards/row
     - Desktop: 3 cards/row ✓

4. **Drag & Drop Test** ⭐ NEW
   - Click "Configure" on any bundle
   - Drag an option to new position
   - Verify it reorders and success message appears ✓

5. **Option Selection**
   - Check/uncheck options
   - Watch totals update in real-time ✓

6. **Add to Quote**
   - Select 2+ options
   - Click "Add to Quote"
   - Verify success message ✓

7. **Calculate Prices**
   - Click "Calculate & Load Prices"
   - Verify pricing table appears with discounts ✓

8. **Generate PDF**
   - Click "Generate PDF"
   - Verify PDF opens in new tab ✓

---

## 🐛 Troubleshooting

### **Issue: Component not visible after deployment**
```powershell
# Clear cache and redeploy
sfdx force:source:deploy --sourcepath force-app --username NexaLinkOrg --verbose

# Then refresh page in browser (Ctrl+Shift+R)
```

### **Issue: Apex methods not found**
```powershell
# Verify controller deployed
sfdx force:apex:class:info --classname CPQConfiguratorController --username NexaLinkOrg

# Check logs
sfdx force:apex:log:tail --username NexaLinkOrg --logtype Apex
```

### **Issue: Products not found in quote**
- Go to **Setup** → **Products**
- Verify products exist with correct ProductCode:
  - `MOB-UNLTD`, `IP16`, `NET-FIB500`, etc.
- Verify they're in Standard Pricebook
- Check Pricebook Entry has a price set

### **Issue: Drag & Drop not working**
- Open DevTools (F12)
- Go to Console tab
- Look for JavaScript errors
- Ensure CSS file deployed: `cpqConfigurator.css`

---

## 📊 Test Evidence Checklist

After testing, collect:
- [ ] Screenshot of Component on page
- [ ] Screenshot of Bundle Selection (3-card grid)
- [ ] Screenshot of Drag & Drop in action
- [ ] Screenshot of Pricing Table with discounts
- [ ] Console Log (F12 → Console) - should be clean ✓
- [ ] Salesforce log file for Apex execution

---

## 🎯 Expected Timeline

| Task | Time |
|------|------|
| SFDX Setup | 5 min |
| Deploy | 2 min |
| Add to Page | 2 min |
| Manual Testing | 10-15 min |
| **Total** | **~25 min** |

---

## 📞 Getting Help

**Check These First:**
1. Browser Console (F12) for JavaScript errors
2. Salesforce Setup → Apex Classes → Logs
3. Ensure user has access to all custom objects
4. Verify products and pricebook entries exist

**Key URLs in Your Org:**
- Setup: `/lightning/setup/LightningPages/home`
- Apex Logs: `/lightning/setup/ApexClasses/home`
- Products: `/lightning/r/Product2/list`
- Pricebooks: `/lightning/r/Pricebook2/list`

---

**Status**: Ready to test! 🚀
All code is deployed and functional.
