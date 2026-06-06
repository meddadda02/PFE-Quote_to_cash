# NexaLink CPQ Configurator - Fast Deploy Script
# Run: .\DEPLOY.ps1

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   NexaLink CPQ - FAST DEPLOY (Consolidated)                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Check for 'sf' CLI
if (!(Get-Command sf -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 'sf' CLI not found. Please install Salesforce CLI." -ForegroundColor Red
    exit 1
}

$orgAlias = "NexaLink" # Hardcoded based on current context for speed

Write-Host "🚀 Deploying LWC and Apex in a single transaction..." -ForegroundColor Yellow

sf project deploy start `
    --source-dir force-app/main/default/lwc force-app/main/default/classes force-app/main/default/triggers `
    --target-org $orgAlias `
    --test-level NoTestRun `
    --concise

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
} else {
    Write-Host "❌ DEPLOYMENT FAILED!" -ForegroundColor Red
}

# Display summary
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Open Salesforce: https://`$orgAlias.my.salesforce.com" -ForegroundColor White
Write-Host "2. Go to Setup → Lightning App Builder" -ForegroundColor White
Write-Host "3. Add 'cpqConfigurator' component to a Lightning Page" -ForegroundColor White
Write-Host "4. Save and Activate" -ForegroundColor White
Write-Host "5. Test the component!" -ForegroundColor White
Write-Host ""
Write-Host "📖 See QUICK_TEST_GUIDE.md for detailed testing steps" -ForegroundColor Yellow
Write-Host ""

Read-Host "Press Enter to exit"
