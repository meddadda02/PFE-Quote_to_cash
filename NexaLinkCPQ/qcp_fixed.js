export function onBeforeCalculate(quote, lines, conn) {
    return Promise.resolve();
}

export function onAfterCalculate(quote, lines, conn) {

    if (!lines || lines.length === 0) return Promise.resolve();

    var accountId = quote.record['SBQQ__Account__c'];
    var currency = quote.record['CurrencyIsoCode'] || 'MAD';
    var rates = { 'MAD': 1, 'USD': 0.099, 'EUR': 0.091 };
    var rate = rates[currency] || 1;
    var sym = currency;

    function toLocal(n) { return parseFloat((n * rate).toFixed(2)); }
    function parseDate(s) { var p = s.split("/"); return p.length === 3 ? new Date(p[2], p[1] - 1, p[0]) : new Date(s); }
    function toDateOnly(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }

    // Sequential Promise chain to avoid CPQ Calculation Engine crashes
    return conn.query(
        "SELECT Is_Student__c, Is_Telecom_Employee__c, BillingCountry, " +
        "(SELECT Id FROM Orders WHERE Status = 'Activated' LIMIT 1), " +
        "(SELECT Id FROM Contracts WHERE Status = 'Activated' LIMIT 1) " +
        "FROM Account WHERE Id = '" + accountId + "'"
    ).then(function (accResult) {

        var quoteId = quote.record['Id'] || (lines.length > 0 ? lines[0].record['SBQQ__Quote__c'] : null);
        var qPromise = quoteId ? conn.query("SELECT Discount_Approved__c, SBQQ__Status__c FROM SBQQ__Quote__c WHERE Id = '" + quoteId + "'") : Promise.resolve({ records: [] });

        return qPromise.then(function (quoteResult) {
            return { accResult: accResult, quoteResult: quoteResult };
        }).catch(function (e) {
            return { accResult: accResult, quoteResult: { records: [] } };
        });

    }).then(function (results) {

        var result = results.accResult;
        var quoteResult = results.quoteResult;

        var acc = (result.records && result.records.length > 0) ? result.records[0] : {};
        var isEmployee = acc['Is_Telecom_Employee__c'] || false;
        var isStudent = acc['Is_Student__c'] || false;
        var hasContract = acc['Contracts'] && acc['Contracts'].records && acc['Contracts'].records.length > 0;
        var hasOrder = acc['Orders'] && acc['Orders'].records && acc['Orders'].records.length > 0;
        var isNew = !hasContract && !hasOrder;

        var c = (acc['BillingCountry'] || '').toLowerCase().trim();
        var isMorocco = (c === 'morocco' || c === 'maroc' || c === 'ma');
        var isFrance = (c === 'france' || c === 'fr');
        var isGermany = (c === 'germany' || c === 'allemagne' || c === 'deutschland' || c === 'de');
        var isUSA = (c === 'united states' || c === 'united states of america' || c === 'usa' || c === 'us');

        var startDateRaw = quote.record["SBQQ__StartDate__c"] || "";
        var quoteDate = startDateRaw ? parseDate(startDateRaw.split("-").reverse().join("/")) : new Date();
        var today = toDateOnly(quoteDate);
        var isRamadan = isMorocco && (
            (today >= toDateOnly(parseDate('28/02/2026')) && today <= toDateOnly(parseDate('30/03/2026'))) ||
            (today >= toDateOnly(parseDate('17/02/2027')) && today <= toDateOnly(parseDate('18/03/2027')))
        );

        // Approval Logic with strict stringification check for REST API boolean responses
        var uiVal = quote.record['Discount_Approved__c'];
        var uiStatus = quote.record['SBQQ__Status__c'];
        var isUIApproved = (uiVal === true || uiVal === 'true' || uiVal === 1 || uiVal === '1' || uiStatus === 'Approved');

        var isDBApproved = false;
        var dbValStr = "NO_DB";
        if (quoteResult.records && quoteResult.records.length > 0) {
            var dbVal = quoteResult.records[0].Discount_Approved__c;
            var dbStatus = quoteResult.records[0].SBQQ__Status__c;
            isDBApproved = (dbVal === true || dbVal === 'true' || dbVal === 1 || dbVal === '1' || dbStatus === 'Approved');
            dbValStr = String(dbVal) + "_" + String(dbStatus);
        }

        var isDiscountApproved = isDBApproved || isUIApproved;
        var approvalSource = "DB_" + dbValStr + "_UI_" + String(uiVal) + "_" + String(uiStatus);

        // Global discount
        var globalDiscount = 0, globalBreakdown = [];
        if (isEmployee) { var e = toLocal(80); globalDiscount += e; globalBreakdown.push('Employee: ' + e.toFixed(2) + ' ' + sym); }
        else if (isStudent) { var s = toLocal(30); globalDiscount += s; globalBreakdown.push('Student: ' + s.toFixed(2) + ' ' + sym); }
        if (isNew) { var nw = toLocal(40); globalDiscount += nw; globalBreakdown.push('New Customer: ' + nw.toFixed(2) + ' ' + sym); }
        if (isRamadan) { var rm = toLocal(30); globalDiscount += rm; globalBreakdown.push('Ramadan: ' + rm.toFixed(2) + ' ' + sym); }
        var globalLabel = globalBreakdown.join(' | ');

        quote.record['Ramadan_Discount_Amount__c'] = isRamadan ? toLocal(30) : 0;
        quote.record['Employee_Discount_Amount__c'] = isEmployee ? toLocal(80) : 0;
        quote.record['Student_Discount_Amount__c'] = isStudent ? toLocal(30) : 0;
        quote.record['New_Discount_Amount__c'] = isNew ? toLocal(40) : 0;

        // PASS 1
        var bundleCodes = {}, bundleCount = 0, deviceCount = 0;
        var hasMobile = false, hasHome = false, hasFiber = false;

        lines.forEach(function (line) {
            var code = line.record['SBQQ__ProductCode__c'] || '';
            var family = line.record['SBQQ__ProductFamily__c'] || '';
            if (family === 'Bundles' && !bundleCodes[code]) { bundleCodes[code] = true; bundleCount++; }
            if (family === 'Devices') deviceCount += (line.record['SBQQ__Quantity__c'] || 0);
            if (code === 'MOB-Bun' || code === 'MOB-FAMILY-SHARE-PACK') hasMobile = true;
            if (code === 'BND-TV-HOME' || code === 'BND-SMART-SEC') hasHome = true;
            if (code === 'NET-FIB500' || code === 'NET-FIB1G' || code === 'NET-BUS1.5G') hasFiber = true;
        });

        // PASS 2
        var lineData = [], totalNet = 0;
        var hasHighDiscount = false;
        var highDiscountProducts = [];
        var totalManualDiscountAmt = 0;

        lines.forEach(function (line, idx) {
            var code = line.record['SBQQ__ProductCode__c'] || '';
            var family = line.record['SBQQ__ProductFamily__c'] || '';
            var chargeType = line.record['SBQQ__ChargeType__c'] || '';
            var qty = line.record['SBQQ__Quantity__c'] || 0;
            var listPrice = line.record['SBQQ__ListPrice__c'] || 0;
            var manualAmt = line.record['Manual_Discount_Amt__c'] || 0;
            var isBundled = line.record['SBQQ__Bundled__c'] || false;
            // chargeType may be blank on direct-DML inserted lines; fall back to family detection
            var isRecurring = (chargeType === 'Recurring')
                || family === 'Plans'
                || family === 'Internet'
                || family === 'TV'
                || code === 'MOB-UNLTD' || code === 'MOB-5G-PREM' || code === 'MOB-5G-STRT'
                || code === 'NET-FIB500' || code === 'NET-FIB1G' || code === 'NET-BUS1.5G'
                || code === 'BIZ-FIB1G' || code === 'BIZ-FIB2G' || code === 'BIZ-FIB3G';

            var base = listPrice * qty, lineDisc = 0, breakdown = [];

            breakdown.push('Auth: ' + approvalSource);

            // Bundled options are FREE
            if (isBundled) {
                line.record['SBQQ__NetPrice__c'] = 0;
                line.record['SBQQ__CustomerPrice__c'] = 0;
                line.record['Discount_Breakdown__c'] = 'Included in bundle';
                lineData.push({
                    idx: idx, family: family, base: 0, net: 0,
                    lineDisc: 0, isExempt: true, breakdown: [], skip: true
                });
                return;
            }

            var isExempt = (
                (code === 'SRV-INST' && bundleCount >= 2) ||
                (code === 'HW-WIFI-BOOST' && hasFiber) ||
                (code === 'ADD-TV-PREMIUM' && isStudent)
            );

            if (family === 'Bundles') {
                lineData.push({ idx: idx, family: family, base: base, net: 0, breakdown: [], isExempt: true });
                return;
            }

            if (manualAmt > 0) {
                var totalManual = manualAmt * qty;
                totalManualDiscountAmt += totalManual;
                lineDisc += totalManual;
                breakdown.push('Manual Discount: -' + totalManual.toFixed(2) + ' ' + sym);
            }

            if (code === 'SRV-INST' && bundleCount >= 2) { lineDisc += base; breakdown.push('Free Install: -' + base.toFixed(2) + ' ' + sym); }
            if (code === 'HW-WIFI-BOOST' && hasFiber) { lineDisc += base; breakdown.push('Free WiFi Booster: -' + base.toFixed(2) + ' ' + sym); }
            if (code === 'ADD-TV-PREMIUM' && isStudent) { lineDisc += base; breakdown.push('Student Premium Free: -' + base.toFixed(2) + ' ' + sym); }

            if (bundleCount >= 2 && isRecurring && code !== 'SRV-INST' && code !== 'HW-WIFI-BOOST') {
                if (hasMobile && hasHome) {
                    var combo = base * 0.20; lineDisc += combo;
                    breakdown.push('Home+Mobile Combo 20%: -' + combo.toFixed(2) + ' ' + sym);
                } else {
                    var multi = base * 0.15; lineDisc += multi;
                    breakdown.push('Bundle 15%: -' + multi.toFixed(2) + ' ' + sym);
                }
            }

            if (family === 'Devices' && deviceCount >= 3) {
                var vol = base * 0.10; lineDisc += vol;
                breakdown.push('Device Volume 10%: -' + vol.toFixed(2) + ' ' + sym);
            }

            if (!isExempt && base > 0) {
                var maxDisc = base * 0.20; // Reverted back to 20% cap based on earlier requirements
                if (lineDisc > maxDisc) {
                    if (!isDiscountApproved) {
                        hasHighDiscount = true;
                        var productName = line.record['SBQQ__ProductName__c'] || code;
                        if (highDiscountProducts.indexOf(productName) === -1) {
                            highDiscountProducts.push(productName);
                        }
                        breakdown.push('Capped at 20%: was -' + lineDisc.toFixed(2) + ' ' + sym + ', max -' + maxDisc.toFixed(2) + ' ' + sym);
                        lineDisc = maxDisc;
                    } else {
                        breakdown.push('Approved discount: -' + lineDisc.toFixed(2) + ' ' + sym + ' (cap bypassed)');
                    }
                }
            }

            // Clear CPQ fields AFTER reading to prevent feedback loop
            line.record['SBQQ__AdditionalDiscountAmount__c'] = null;
            line.record['SBQQ__AdditionalDiscount__c'] = null;
            line.record['SBQQ__SpecialPrice__c'] = null;

            var net = Math.max(base - lineDisc, 0);
            totalNet += net;
            lineData.push({ idx: idx, family: family, base: base, net: net, lineDisc: lineDisc, isExempt: isExempt, breakdown: breakdown });
        });

        quote.record['High_Discount_Approval__c'] = hasHighDiscount && !isDiscountApproved;
        quote.record['High_Discount_Products__c'] = highDiscountProducts.join(', ');
        quote.record['Total_Manual_Discount_Amount__c'] = totalManualDiscountAmt;

        // PASS 3
        var grandTotal = 0;

        lineData.forEach(function (ld) {
            if (ld.skip) return;

            var line = lines[ld.idx], breakdown = ld.breakdown.slice();

            if (ld.family === 'Bundles') {
                line.record['Discount_Breakdown__c'] = globalLabel ? 'GLOBAL: ' + globalLabel : 'No Discount';
                return;
            }

            var lineShare = 0;
            if (globalDiscount > 0 && totalNet > 0) lineShare = (ld.net / totalNet) * globalDiscount;

            if (!ld.isExempt && ld.base > 0 && !isDiscountApproved) {
                var maxTotal = ld.base * 0.20; // Cap at 20%
                if (ld.lineDisc + lineShare > maxTotal) {
                    var allowed = Math.max(maxTotal - ld.lineDisc, 0);
                    breakdown.push('Global capped at 20%: was -' + lineShare.toFixed(2) + ' ' + sym + ', allowed -' + allowed.toFixed(2) + ' ' + sym);
                    lineShare = allowed;
                }
            }

            var finalNetTotal = Math.max(ld.net - lineShare, 0);
            grandTotal += finalNetTotal;

            var qty = lines[ld.idx].record['SBQQ__Quantity__c'] || 1;
            var perUnit = qty > 0 ? (finalNetTotal / qty) : finalNetTotal;
            line.record['SBQQ__NetPrice__c'] = perUnit;
            line.record['SBQQ__CustomerPrice__c'] = perUnit;

            if (lineShare > 0) breakdown.push('Global (' + globalLabel + '): -' + lineShare.toFixed(2) + ' ' + sym);
            line.record['Discount_Breakdown__c'] = breakdown.length > 0 ? breakdown.join(' | ') : 'No Discount';
        });

        return Promise.resolve();
    });
}
