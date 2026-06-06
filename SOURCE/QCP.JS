// QCP Script - NexaLink CPQ
// This script runs after CPQ calculates prices.
// It applies custom discounts and checks if approval is needed.

export function onBeforeCalculate(quote, lines, conn) {
    // Nothing to do before calculation
    return Promise.resolve();
}

export function onAfterCalculate(quote, lines, conn) {

    // If there are no lines, stop here
    if (!lines || lines.length === 0) {
        return Promise.resolve();
    }

    // Get the account ID from the quote
    var accountId = quote.record['SBQQ__Account__c'];

    // If no account ID, stop to avoid errors in SOQL query
    if (!accountId || accountId === 'null' || accountId === 'undefined') {
        return Promise.resolve();
    }

    // Get the currency of the quote (default is MAD)
    var currency = quote.record['CurrencyIsoCode'] || 'MAD';
    var sym = currency;

    // Exchange rates for conversion
    var rates = { 'MAD': 1, 'USD': 0.099, 'EUR': 0.091 };
    var rate = rates[currency] || 1;

    // Function to convert a fixed amount to the quote currency
    function toLocal(amount) {
        return parseFloat((amount * rate).toFixed(2));
    }

    // Function to parse a date string like "01/01/2026"
    function parseDate(dateString) {
        var parts = dateString.split('/');
        if (parts.length === 3) {
            return new Date(parts[2], parts[1] - 1, parts[0]);
        }
        return new Date(dateString);
    }

    // Function to get a date without the time part
    function toDateOnly(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }

    // Get the quote ID (used to check approval status)
    var quoteId = '';
    if (quote.record && quote.record.Id) {
        quoteId = quote.record.Id;
    } else if (quote.record && quote.record['Id']) {
        quoteId = quote.record['Id'];
    }

    // Prepare the query to check if the discount has been approved
    var quoteStatusQuery;
    if (quoteId) {
        quoteStatusQuery = conn.query(
            "SELECT Discount_Approved__c, SBQQ__Status__c " +
            "FROM SBQQ__Quote__c " +
            "WHERE Id = '" + quoteId + "'"
        );
    } else {
        quoteStatusQuery = Promise.resolve({ records: [] });
    }

    // Query to get account information
    var accountQuery = conn.query(
        "SELECT Is_Student__c, Is_Telecom_Employee__c, BillingCountry, " +
        "(SELECT Id FROM Orders WHERE Status = 'Activated' LIMIT 1), " +
        "(SELECT Id FROM Contracts WHERE Status = 'Activated' LIMIT 1) " +
        "FROM Account WHERE Id = '" + accountId + "'"
    );

    // Run both queries at the same time
    return Promise.all([accountQuery, quoteStatusQuery]).then(function(results) {

        // --- Get data from queries ---

        var accountResult = results[0];
        var quoteResult   = results[1] || { records: [] };

        // Account record
        var acc = {};
        if (accountResult.records && accountResult.records.length > 0) {
            acc = accountResult.records[0];
        }

        // Is the customer a telecom employee?
        var isEmployee = acc['Is_Telecom_Employee__c'] || false;

        // Is the customer a student?
        var isStudent = acc['Is_Student__c'] || false;

        // Does the account have an active contract?
        var hasContract = false;
        if (acc['Contracts'] && acc['Contracts'].records && acc['Contracts'].records.length > 0) {
            hasContract = true;
        }

        // Does the account have an active order?
        var hasOrder = false;
        if (acc['Orders'] && acc['Orders'].records && acc['Orders'].records.length > 0) {
            hasOrder = true;
        }

        // Is the customer new (no contract and no order)?
        var isNew = !hasContract && !hasOrder;

        // Is the customer from Morocco?
        var country = (acc['BillingCountry'] || '').toLowerCase().trim();
        var isMorocco = false;
        if (country === 'morocco' || country === 'maroc' || country === 'ma') {
            isMorocco = true;
        }

        // Check if the quote date falls in the Ramadan period
        var startDateRaw = quote.record['SBQQ__StartDate__c'] || '';
        var quoteDate;
        if (startDateRaw) {
            quoteDate = parseDate(startDateRaw.split('-').reverse().join('/'));
        } else {
            quoteDate = new Date();
        }
        var today = toDateOnly(quoteDate);

        var isRamadan = false;
        if (isMorocco) {
            var r2026Start = toDateOnly(parseDate('28/02/2026'));
            var r2026End   = toDateOnly(parseDate('30/03/2026'));
            var r2027Start = toDateOnly(parseDate('17/02/2027'));
            var r2027End   = toDateOnly(parseDate('18/03/2027'));

            if ((today >= r2026Start && today <= r2026End) ||
                (today >= r2027Start && today <= r2027End)) {
                isRamadan = true;
            }
        }

        // Check if the discount has been approved by the manager
        var qRec = {};
        if (quoteResult.records && quoteResult.records.length > 0) {
            qRec = quoteResult.records[0];
        }

        var isDiscountApproved = false;
        if (qRec['Discount_Approved__c'] === true)        { isDiscountApproved = true; }
        if (qRec['Discount_Approved__c'] === 'true')      { isDiscountApproved = true; }
        if (qRec['SBQQ__Status__c'] === 'Approved')       { isDiscountApproved = true; }
        if (quote.record['SBQQ__Status__c'] === 'Approved')       { isDiscountApproved = true; }
        if (quote.record['Discount_Approved__c'] === true)        { isDiscountApproved = true; }
        if (quote.record['Discount_Approved__c'] === 'true')      { isDiscountApproved = true; }

        // --- Calculate global discounts ---
        // These are fixed amounts based on the customer profile

        var globalDiscount = 0;
        var globalBreakdown = [];

        // Employee discount: 80 MAD
        if (isEmployee) {
            var employeeAmt = toLocal(80);
            globalDiscount = globalDiscount + employeeAmt;
            globalBreakdown.push('Employee: ' + employeeAmt.toFixed(2) + ' ' + sym);
        } else if (isStudent) {
            // Student discount: 30 MAD (cannot combine with employee)
            var studentAmt = toLocal(30);
            globalDiscount = globalDiscount + studentAmt;
            globalBreakdown.push('Student: ' + studentAmt.toFixed(2) + ' ' + sym);
        }

        // New customer discount: 40 MAD
        if (isNew) {
            var newAmt = toLocal(40);
            globalDiscount = globalDiscount + newAmt;
            globalBreakdown.push('New Customer: ' + newAmt.toFixed(2) + ' ' + sym);
        }

        // Ramadan discount: 30 MAD
        if (isRamadan) {
            var ramadanAmt = toLocal(30);
            globalDiscount = globalDiscount + ramadanAmt;
            globalBreakdown.push('Ramadan: ' + ramadanAmt.toFixed(2) + ' ' + sym);
        }

        var globalLabel = globalBreakdown.join(' | ');

        // Write discount amounts to quote fields for reporting
        quote.record['Employee_Discount_Amount__c'] = isEmployee ? toLocal(80) : 0;
        quote.record['Student_Discount_Amount__c']  = isStudent  ? toLocal(30) : 0;
        quote.record['New_Discount_Amount__c']      = isNew      ? toLocal(40) : 0;
        quote.record['Ramadan_Discount_Amount__c']  = isRamadan  ? toLocal(30) : 0;

        // --- PASS 1: Scan lines to know what products are in the quote ---

        var bundleCodes  = {};
        var bundleCount  = 0;
        var deviceCount  = 0;
        var hasMobile    = false;
        var hasHome      = false;
        var hasFiber     = false;

        for (var i = 0; i < lines.length; i++) {
            var scanLine   = lines[i];
            var scanCode   = scanLine.record['SBQQ__ProductCode__c']  || '';
            var scanFamily = scanLine.record['SBQQ__ProductFamily__c'] || '';

            // Count unique bundles
            if (scanFamily === 'Bundles' && !bundleCodes[scanCode]) {
                bundleCodes[scanCode] = true;
                bundleCount++;
            }

            // Count devices
            if (scanFamily === 'Devices') {
                deviceCount = deviceCount + (scanLine.record['SBQQ__Quantity__c'] || 0);
            }

            // Detect mobile bundle
            if (scanCode === 'MOB-Bun' || scanCode === 'MOB-FAMILY-SHARE-PACK') {
                hasMobile = true;
            }

            // Detect home bundle
            if (scanCode === 'BND-TV-HOME' || scanCode === 'BND-SMART-SEC') {
                hasHome = true;
            }

            // Detect fiber product
            if (scanCode === 'NET-FIB500' || scanCode === 'NET-FIB1G' || scanCode === 'NET-BUS1.5G') {
                hasFiber = true;
            }
        }

        // --- PASS 2: Calculate discounts for each line ---

        var lineData            = [];
        var totalNet            = 0;
        var totalManualDiscount = 0;
        var hasHighDiscount     = false;
        var highDiscountProducts = [];

        for (var j = 0; j < lines.length; j++) {
            var line      = lines[j];
            var code      = line.record['SBQQ__ProductCode__c']   || '';
            var family    = line.record['SBQQ__ProductFamily__c'] || '';
            var chargeType = line.record['SBQQ__ChargeType__c']   || '';
            var qty       = line.record['SBQQ__Quantity__c']       || 0;
            var listPrice = line.record['SBQQ__ListPrice__c']      || 0;
            var isBundled = line.record['SBQQ__Bundled__c']        || false;

            // Read manual discount entered by the sales rep
            var manualAmt = parseFloat(line.record['Manual_Discount_Amt__c'] || 0);
            if (isNaN(manualAmt) || manualAmt < 0) {
                manualAmt = 0;
            }

            // Check if this product is a recurring charge
            var isRecurring = false;
            if (chargeType === 'Recurring') { isRecurring = true; }
            if (family === 'Plans')         { isRecurring = true; }
            if (family === 'Internet')      { isRecurring = true; }
            if (family === 'TV')            { isRecurring = true; }
            if (code === 'MOB-UNLTD')       { isRecurring = true; }
            if (code === 'MOB-5G-PREM')     { isRecurring = true; }
            if (code === 'MOB-5G-STRT')     { isRecurring = true; }
            if (code === 'NET-FIB500')      { isRecurring = true; }
            if (code === 'NET-FIB1G')       { isRecurring = true; }
            if (code === 'NET-BUS1.5G')     { isRecurring = true; }
            if (code === 'BIZ-FIB1G')       { isRecurring = true; }
            if (code === 'BIZ-FIB2G')       { isRecurring = true; }
            if (code === 'BIZ-FIB3G')       { isRecurring = true; }

            // Base price = list price * quantity
            var base = listPrice * qty;

            // Bundled options are free (price = 0)
            if (isBundled) {
                line.record['SBQQ__NetPrice__c']      = 0;
                line.record['SBQQ__CustomerPrice__c'] = 0;
                line.record['Discount_Breakdown__c']  = 'Included in bundle';
                lineData.push({ idx: j, family: family, base: 0, net: 0,
                                lineDisc: 0, isExempt: true, breakdown: [], skip: true });
                continue;
            }

            // Bundle header lines have no direct price
            if (family === 'Bundles') {
                lineData.push({ idx: j, family: family, base: base,
                                net: 0, breakdown: [], isExempt: true });
                continue;
            }

            // These products are not subject to the 20% cap
            var isExempt = false;
            if (code === 'SRV-INST'      && bundleCount >= 2) { isExempt = true; }
            if (code === 'HW-WIFI-BOOST' && hasFiber)         { isExempt = true; }
            if (code === 'ADD-TV-PREMIUM'&& isStudent)         { isExempt = true; }

            var lineDisc  = 0;
            var breakdown = [];

            // 1. Manual discount from the sales rep
            if (manualAmt > 0) {
                var manualTotal     = manualAmt * qty;
                lineDisc            = lineDisc + manualTotal;
                totalManualDiscount = totalManualDiscount + manualTotal;
                breakdown.push('Manual Discount: -' + manualTotal.toFixed(2) + ' ' + sym);
            }

            // 2. Free installation when 2 or more bundles
            if (code === 'SRV-INST' && bundleCount >= 2) {
                lineDisc = lineDisc + base;
                breakdown.push('Free Install: -' + base.toFixed(2) + ' ' + sym);
            }

            // 3. Free WiFi booster when fiber is present
            if (code === 'HW-WIFI-BOOST' && hasFiber) {
                lineDisc = lineDisc + base;
                breakdown.push('Free WiFi Booster: -' + base.toFixed(2) + ' ' + sym);
            }

            // 4. Free TV premium for students
            if (code === 'ADD-TV-PREMIUM' && isStudent) {
                lineDisc = lineDisc + base;
                breakdown.push('Student Premium Free: -' + base.toFixed(2) + ' ' + sym);
            }

            // 5. Multi-bundle discount for recurring products
            if (bundleCount >= 2 && isRecurring && code !== 'SRV-INST' && code !== 'HW-WIFI-BOOST') {
                if (hasMobile && hasHome) {
                    // 20% for the Home + Mobile combo
                    var comboDisc = base * 0.20;
                    lineDisc = lineDisc + comboDisc;
                    breakdown.push('Home+Mobile Combo 20%: -' + comboDisc.toFixed(2) + ' ' + sym);
                } else {
                    // 15% for any other multi-bundle
                    var bundleDisc = base * 0.15;
                    lineDisc = lineDisc + bundleDisc;
                    breakdown.push('Bundle 15%: -' + bundleDisc.toFixed(2) + ' ' + sym);
                }
            }

            // 6. Volume discount for devices (10% when 3 or more)
            if (family === 'Devices' && deviceCount >= 3) {
                var volDisc = base * 0.10;
                lineDisc = lineDisc + volDisc;
                breakdown.push('Device Volume 10%: -' + volDisc.toFixed(2) + ' ' + sym);
            }

            // 7. Check if total discount exceeds 20% (needs manager approval)
            if (!isExempt && base > 0 && lineDisc > base * 0.20) {

                var requestedDisc = lineDisc;
                var maxDisc       = base * 0.20;

                // Flag this line as high discount
                hasHighDiscount = true;

                // Add product name to the list
                var productName = line.record['SBQQ__ProductName__c'] || code;
                var alreadyInList = false;
                for (var k = 0; k < highDiscountProducts.length; k++) {
                    if (highDiscountProducts[k] === productName) {
                        alreadyInList = true;
                    }
                }
                if (!alreadyInList) {
                    highDiscountProducts.push(productName);
                }

                if (!isDiscountApproved) {
                    // Block at 20% until the manager approves
                    lineDisc = maxDisc;
                    breakdown.push(
                        'Blocked at 20% (requested: -' + requestedDisc.toFixed(2) + ' ' + sym +
                        ', applied: -' + maxDisc.toFixed(2) + ' ' + sym + '): pending approval'
                    );
                } else {
                    // Discount approved — apply the full amount
                    breakdown.push('Approved: full discount -' + requestedDisc.toFixed(2) + ' ' + sym + ' applied');
                }
            }

            // Net price after line discounts
            var net = base - lineDisc;
            if (net < 0) { net = 0; }

            totalNet = totalNet + net;

            lineData.push({
                idx: j, family: family,
                base: base, net: net,
                lineDisc: lineDisc,
                isExempt: isExempt,
                breakdown: breakdown
            });
        }

        // Write approval info to the quote
        quote.record['High_Discount_Approval__c']      = hasHighDiscount && !isDiscountApproved;
        quote.record['High_Discount_Products__c']       = highDiscountProducts.join(', ');
        quote.record['Total_Manual_Discount_Amount__c'] = parseFloat(totalManualDiscount.toFixed(2));

        // --- PASS 3: Apply global discounts proportionally across all lines ---

        var grandTotal = 0;

        for (var m = 0; m < lineData.length; m++) {
            var ld = lineData[m];

            // Skip bundled option lines (already set to 0)
            if (ld.skip) {
                continue;
            }

            var currentLine = lines[ld.idx];
            var bdList      = ld.breakdown.slice(); // copy the breakdown array

            // Bundle header lines only display the global discount label
            if (ld.family === 'Bundles') {
                if (globalLabel) {
                    currentLine.record['Discount_Breakdown__c'] = 'GLOBAL: ' + globalLabel;
                } else {
                    currentLine.record['Discount_Breakdown__c'] = 'No Discount';
                }
                continue;
            }

            // Proportional share of the global discount for this line
            var weight      = 0;
            if (totalNet > 0) {
                weight = ld.net / totalNet;
            }
            var globalShare = parseFloat((weight * globalDiscount).toFixed(2));

            // Final net price after global discount
            var finalNet = ld.net - globalShare;
            if (finalNet < 0) { finalNet = 0; }

            grandTotal = grandTotal + finalNet;

            // Price per unit
            var lineQty = lines[ld.idx].record['SBQQ__Quantity__c'] || 1;
            var perUnit = finalNet;
            if (lineQty > 0) {
                perUnit = finalNet / lineQty;
            }

            // Write the final prices to the line
            currentLine.record['SBQQ__NetPrice__c']      = perUnit;
            currentLine.record['SBQQ__CustomerPrice__c'] = perUnit;

            // Add global discount to the breakdown text
            if (globalShare > 0) {
                bdList.push('Global (' + globalLabel + '): -' + globalShare.toFixed(2) + ' ' + sym);
            }

            // Write the discount breakdown text
            if (bdList.length > 0) {
                currentLine.record['Discount_Breakdown__c'] = bdList.join(' | ');
            } else {
                currentLine.record['Discount_Breakdown__c'] = 'No Discount';
            }
        }

        return Promise.resolve();
    });
}
