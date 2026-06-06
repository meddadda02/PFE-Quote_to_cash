# 🚀 QUICK START - Direct Testing (5 Minutes)

## **STEP 1: Deploy (2 min)**
```powershell
# Open PowerShell in project folder and run:
.\DEPLOY.ps1

# OR if SFDX is installed:
sfdx force:source:deploy --sourcepath force-app --username YOUR_ORG_ALIAS
```

## **STEP 2: Add to Page (1 min)**
1. Salesforce → Setup → Lightning App Builder
2. Create new Lightning App Page (name: "CPQ Test")
3. Drag "cpqConfigurator" component to page
4. Save → Activate

## **STEP 3: Test (2 min)**

### **✅ Quick Test Flow**
```
1. Type account name (2+ chars) → Select account
2. Select Opportunity → Select Currency (MAD)
3. Click "Create Quote" → Should see success message
4. Click "Configure" on any bundle → Verify checkboxes work
5. DRAG an option to new position → Should reorder ✨
6. Select 2+ options → Click "Add to Quote"
7. Click "Calculate & Load Prices" → See pricing table
8. Click "Generate PDF" → PDF opens
```

---

## **Expected Results** ✓

| Test | Expected | Status |
|------|----------|--------|
| Account search works | Dropdown appears | ☐ |
| Quote created | Success message | ☐ |
| Bundle options show | 5 bundles visible | ☐ |
| Drag & drop works | Option reorders | ☐ |
| Add to quote works | Products added | ☐ |
| Prices calculated | Table with discounts | ☐ |
| PDF generates | Opens in new tab | ☐ |
| No console errors | F12 → Console is clean | ☐ |

---

## **Troubleshooting**

| Issue | Fix |
|-------|-----|
| Component not visible | Refresh page (Ctrl+Shift+R) |
| "Products not found" | Check product codes match bundle options |
| Drag & drop not working | Check CSS file deployed (`cpqConfigurator.css`) |
| Console errors | Check Salesforce Setup → Apex Logs |
| "No opportunities" | Create opportunities in your test account |

---

## **Key URLs**
- Apex Logs: `Setup → Apex Classes → Recent Logs`
- Products: `Setup → Objects → Products`
- App Builder: `Setup → Lightning App Builder`

---

## **Files You Have**
```
✓ cpqConfigurator.html       - UI template
✓ cpqConfigurator.js         - Component logic with drag & drop
✓ cpqConfigurator.css        - Responsive styles & animations
✓ CPQConfiguratorController.cls - Apex backend

📖 DEPLOY.ps1 / DEPLOY.bat    - Deployment scripts
📖 QUICK_TEST_GUIDE.md         - Full testing guide  
📖 COMPLETE_TESTING_PLAN.md    - 76-point test plan
📖 CHANGES_SUMMARY.md          - All improvements made
```

---

**Status**: ✅ READY TO TEST

All code is production-ready with:
- ✅ Drag & drop reordering
- ✅ Responsive mobile design
- ✅ Complete error handling
- ✅ Full Apex integration
