# NexaLink CPQ Configurator - Deployment & Testing Guide

## 📋 What's Been Fixed & Improved

### ✅ **Bug Fixes**
1. **Parameter Name Error**: Fixed `currency` → `currencyCode` in `handleAddToQuote()`
2. **Missing Validation**: Added check for empty product selection before adding to quote
3. **Success Message**: Now displayed in UI with auto-dismiss after 3 seconds
4. **Error Handling**: Improved error messages with fallbacks using optional chaining (`?.`)
5. **Loading State**: Better visual feedback during async operations

### ✨ **New Features**
1. **Drag & Drop**: Reorder bundle options by dragging them
2. **Responsive Design**: Mobile-first approach with breakpoints for tablets and desktops
3. **Visual Feedback**: Drop zones highlighted, drag cursor changes, smooth animations
4. **Better UX**: Auto-clearing success messages, required field indicators, improved spacing

### 🎨 **Design Improvements**
- Added `cpqConfigurator.css` with:
  - Responsive grid layout (`slds-size_1-of-1`, `slds-medium-size_1-of-2`, `slds-large-size_1-of-3`)
  - Drag & drop visual states (opacity change, dashed border on drop zone)
  - Better scrolling for long option lists
  - Mobile-optimized padding and spacing
  - Smooth animations for alerts

---

## 🚀 Deployment Steps (SFDX)

### **Step 1: Authorize Your Salesforce Org**
```powershell
sfdx auth:web:login -a NexaLinkOrg
# You'll be redirected to Salesforce login. Login with your org credentials.
```

### **Step 2: Deploy the Component**
```powershell
# From the NexaLinkCPQ root directory
sfdx force:source:deploy -p force-app/main/default/lwc/cpqConfigurator -u NexaLinkOrg --testlevel RunLocalTests
sfdx force:source:deploy -p force-app/main/default/classes/CPQConfiguratorController.cls -u NexaLinkOrg --testlevel RunLocalTests
```

### **Step 3: Verify Deployment**
```powershell
sfdx force:apex:log:tail -u NexaLinkOrg
```

---

## ✅ Testing Checklist

### **Pre-Testing Setup**
- [ ] Create sample Accounts in your org (minimum 2)
- [ ] Create Opportunities for those Accounts
- [ ] Ensure Products exist with ProductCode matching bundle option IDs:
  - `MOB-UNLTD`, `IP16`, `DEV-S25`, `NET-FIB500`, `TV-BASIC`, etc.
- [ ] Ensure these products are in the standard Pricebook with prices

### **Unit Tests**
- [ ] Run Apex unit tests for `CPQConfiguratorController`
```powershell
sfdx force:apex:test:run -u NexaLinkOrg -c --verbose
```

### **Manual Testing in Org**

#### **1️⃣ Test Account Search**
- [ ] Navigate to the CPQ Configurator component
- [ ] Type account name (minimum 2 characters)
- [ ] Verify accounts appear in dropdown
- [ ] Verify "No accounts found" message when search has no results
- [ ] Click account to select it

#### **2️⃣ Test Opportunity & Currency Selection**
- [ ] Verify opportunities dropdown populates after account selection
- [ ] Verify error if no opportunities exist
- [ ] Test currency selection (MAD, EUR, USD)
- [ ] Verify "Create Quote" button is enabled only when Opportunity is selected

#### **3️⃣ Test Quote Creation**
- [ ] Click "Create Quote"
- [ ] Verify success message appears and disappears after 3 seconds
- [ ] Verify quote ID appears in the success box
- [ ] Verify Bundle Selection step appears

#### **4️⃣ Test Bundle Selection**
- [ ] View all 5 bundles displayed in responsive grid
- [ ] On mobile: 1 bundle per row
- [ ] On tablet: 2 bundles per row
- [ ] On desktop: 3 bundles per row
- [ ] Click "Configure" on a bundle (try B1 — 5G+ Freedom Pack first)

#### **5️⃣ Test Option Selection & Drag & Drop**
- [ ] In bundle configuration:
  - [ ] Check/uncheck options
  - [ ] Watch monthly recurring and one-time totals update
  - [ ] Verify prices display correctly with currency
  
- [ ] **DRAG & DROP TEST**:
  - [ ] Hover over an option (should show "grab" cursor)
  - [ ] Drag option to new position
  - [ ] Drop it (should reorder in list)
  - [ ] Verify "Option moved successfully!" message
  - [ ] Verify order persists on the component

#### **6️⃣ Test Adding Products to Quote**
- [ ] Select at least 2 options in the bundle
- [ ] Click "Add to Quote"
- [ ] Verify success message
- [ ] Bundle selection should close, returning to bundle list
- [ ] Try selecting another bundle and clicking "Add to Quote" again
- [ ] Verify "Products added to quote" message (not "Quote created")

#### **7️⃣ Test Price Calculation**
- [ ] After adding products, click "Calculate & Load Prices"
- [ ] Verify datatable appears with columns:
  - [ ] Product name
  - [ ] List Price
  - [ ] Net Price (with discounts applied)
  - [ ] Charge Type
  - [ ] Discount breakdown
- [ ] Verify pricing totals:
  - [ ] Net Total
  - [ ] Tax (TVA)
  - [ ] Grand Total TTC

#### **8️⃣ Test PDF Generation**
- [ ] Click "Generate PDF"
- [ ] Verify PDF opens in new tab
- [ ] Verify quote data is in the PDF

#### **9️⃣ Test Error Handling**
- [ ] Try creating quote without selecting opportunity → should show error
- [ ] Try adding to quote without selecting any options → should show error
- [ ] Try calculating without adding any products → should show "Add at least one bundle first"
- [ ] Verify all error messages are user-friendly and actionable

#### **🔟 Test Responsive Design**
- [ ] **Mobile (375px)**:
  - [ ] Open in DevTools with iPhone SE view
  - [ ] Verify text is readable
  - [ ] Verify buttons are full-width and easily clickable
  - [ ] Verify dropdown options stack vertically
  - [ ] Verify bundle cards stack single column
  
- [ ] **Tablet (768px)**:
  - [ ] Verify bundle cards display 2 per row
  - [ ] Verify form fields are responsive
  
- [ ] **Desktop (1200px+)**:
  - [ ] Verify bundle cards display 3 per row
  - [ ] Verify all content has proper spacing

---

## 🔧 Common Issues & Solutions

### **Issue: Products not found**
**Solution**: Verify product codes in the bundle options match your Product2 ProductCode field exactly (case-sensitive).

### **Issue: Prices not calculated**
**Solution**: 
- Check that PricebookEntry records exist for the products
- Verify products are in the standard Pricebook
- Check Apex logs for SQL errors

### **Issue: Drag & Drop not working**
**Solution**: 
- Works in Chrome, Firefox, Safari, Edge
- Not supported in IE11
- Ensure JavaScript is enabled

### **Issue: Component not appearing**
**Solution**:
- Verify component is assigned to the page/tab where you're testing
- Check browser console for JavaScript errors (F12)
- Verify Salesforce user has access to Apex methods

### **Issue: Success messages not auto-clearing**
**Solution**: This is normal - auto-clear happens after 3 seconds via JavaScript timeout

---

## 📊 Testing Evidence Collection

Please collect the following for validation:

1. **Screenshot of Bundle Selection** (Step 2)
2. **Screenshot of Option Selection with Drag Demo** (Step 5)
3. **Screenshot of CPQ Results/Pricing Table** (Step 7)
4. **Mobile View Screenshot** (Step 10)
5. **Console Log** (F12 → Console tab - should be clean with no errors)

---

## 🎯 Expected Behavior Summary

| Step | Expected Outcome | Status |
|------|-----------------|--------|
| Account Search | Dropdown shows matching accounts | ⬜ |
| Create Quote | Quote created, Bundle list appears | ⬜ |
| Bundle Selection | Options displayed with prices | ⬜ |
| Drag & Drop | Options reorder, success message | ⬜ |
| Add to Quote | Products added, total calculated | ⬜ |
| Pricing | CPQ discount applied, totals correct | ⬜ |
| PDF Generation | PDF opens in new tab | ⬜ |
| Responsive Design | Layouts adapt to screen size | ⬜ |
| Error Handling | User-friendly error messages | ⬜ |

---

## 📝 File Changes Summary

```
cpqConfigurator/
├── cpqConfigurator.html     ✏️  Updated with responsive grid, drag events, success/error alerts
├── cpqConfigurator.js       ✏️  Added drag handlers, improved error handling, auto-clear messages
├── cpqConfigurator.css      ✨ NEW - Responsive design, drag/drop styles, animations
├── cpqConfigurator.js-meta.xml   (no changes)
└── __tests__/
    └── cpqConfigurator.test.js   (recommend updating with drag & drop tests)

CPQConfiguratorController.cls   ✅ No changes needed (working correctly)
```

---

## 🚨 Critical Notes

1. **API Version**: Component uses API v62.0 - ensure your org supports this
2. **Security**: All methods use `with sharing` - respects org security
3. **Caching**: `getAccounts()` is cacheable, others are not (needed for real-time updates)
4. **Bundle Data**: Currently hardcoded in JavaScript - consider moving to Custom Metadata for production

---

## ✨ Next Steps (Optional Enhancements)

- [ ] Add unit tests for drag & drop functionality
- [ ] Move bundle definitions to Custom Metadata Type
- [ ] Add discount rules engine
- [ ] Implement save as template feature
- [ ] Add Google Analytics tracking
- [ ] Implement multi-language support

---

**Need Help?** Check browser console (F12) for JavaScript errors or Salesforce Setup → Apex Classes → Recent Log Files for backend errors.
