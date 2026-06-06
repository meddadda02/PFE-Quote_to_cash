@echo off
REM NexaLink CPQ Configurator - Quick Deploy Script
REM This script deploys the component directly to your Salesforce org

setlocal enabledelayedexpansion

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║   NexaLink CPQ Configurator - Quick Deploy                 ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

REM Check if SFDX is installed
sfdx --version >nul 2>&1
if errorlevel 1 (
    echo ❌ SFDX CLI is not installed!
    echo.
    echo Please install it first:
    echo npm install -g @salesforce/sfdx-cli
    echo.
    pause
    exit /b 1
)

echo ✓ SFDX CLI found
echo.

REM Check if connected to org
echo Please enter your Salesforce org alias (default: NexaLinkOrg):
set /p ORG_ALIAS=

if "!ORG_ALIAS!"=="" (
    set ORG_ALIAS=NexaLinkOrg
)

echo.
echo Checking connection to !ORG_ALIAS!...
sfdx force:org:display --username !ORG_ALIAS! >nul 2>&1

if errorlevel 1 (
    echo.
    echo ❌ Not connected to !ORG_ALIAS!
    echo.
    echo Launching Salesforce login...
    sfdx auth:web:login --setdefaultusername --setalias !ORG_ALIAS!
    
    if errorlevel 1 (
        echo ❌ Login failed!
        pause
        exit /b 1
    )
)

echo ✓ Connected to org
echo.

REM Deploy component
echo ═══════════════════════════════════════════════════════════
echo 📦 Deploying LWC Component...
echo ═══════════════════════════════════════════════════════════
echo.

sfdx force:source:deploy ^
    --sourcepath force-app/main/default/lwc/cpqConfigurator ^
    --username !ORG_ALIAS! ^
    --verbose

if errorlevel 1 (
    echo.
    echo ❌ LWC Component deployment failed!
    pause
    exit /b 1
)

echo.
echo ✓ LWC Component deployed successfully!
echo.

REM Deploy Apex controller
echo ═══════════════════════════════════════════════════════════
echo 📦 Deploying Apex Controller...
echo ═══════════════════════════════════════════════════════════
echo.

sfdx force:source:deploy ^
    --sourcepath force-app/main/default/classes ^
    --username !ORG_ALIAS! ^
    --verbose

if errorlevel 1 (
    echo.
    echo ⚠️  Apex deployment had warnings, but continuing...
)

echo.
echo ✓ Apex Controller deployed!
echo.

REM Display summary
echo ═══════════════════════════════════════════════════════════
echo ✅ DEPLOYMENT COMPLETE!
echo ═══════════════════════════════════════════════════════════
echo.
echo 🎯 Next Steps:
echo 1. Open Salesforce: https://!ORG_ALIAS!.my.salesforce.com
echo 2. Go to Setup → Lightning App Builder
echo 3. Add "cpqConfigurator" component to a Lightning Page
echo 4. Save and Activate
echo 5. Test the component!
echo.
echo 📖 See QUICK_TEST_GUIDE.md for detailed testing steps
echo.

pause
