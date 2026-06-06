import { LightningElement, api, track } from 'lwc';

export default class CpqBundleConfigurator extends LightningElement {
    @api labels;
    @api currentLang = 'en';
    @api selectedCurrency = 'MAD';

    @track modalFeatures = [];
    @track modalBanner = [];
    @track modalBundleName = '';
    @track modalBundleCode = '';
    @track modalBundleId = '';
    @track modalConfigTotal = 0;
    @track modalIsValid = false;

    _exclusionMap = {};
    _dependencyMap = {};
    _modalBasePrice = 0;
    _prevSelectedSet = new Set();

    get lbl() {
        return this.labels ? this.labels[this.currentLang] : {};
    }

    get isConfigInvalid() {
        return !this.modalIsValid;
    }

    @api
    openConfigurator(raw, prevSelectedCodes = []) {
        this._prevSelectedSet = new Set(prevSelectedCodes || []);
        this._buildModal(raw);
    }

    _buildModal(r) {
        this._exclusionMap = {};
        this._dependencyMap = {};
        for (const c of (r.constraints || [])) {
            if (c.type === 'Exclusion') {
                if (!this._exclusionMap[c.constraining]) this._exclusionMap[c.constraining] = [];
                this._exclusionMap[c.constraining].push(c.constrained);
            } else if (c.type === 'Dependency') {
                if (!this._dependencyMap[c.constrained]) this._dependencyMap[c.constrained] = [];
                this._dependencyMap[c.constrained].push(c.constraining);
            }
        }

        this.modalBundleName = r.bundleName || r.bundleCode;
        this.modalBundleCode = r.bundleCode;
        this.modalBundleId = r.bundleId || r.bundleCode;
        this._modalBasePrice = parseFloat(r.basePrice || 0);

        const features = (r.features || []).map(f => {
            const minOpt = parseInt(f.minOpt, 10) || 0;
            const maxOpt = parseInt(f.maxOpt, 10) || 999;
            return {
                featureId: f.id,
                name: f.name,
                minOpt: minOpt,
                maxOpt: maxOpt,
                isRadio: (minOpt === 1 && maxOpt === 1),
                options: (f.options || []).map(o => {
                    const isReq = !!o.isRequired;
                    // If editing, use previous selections, else default isSelected
                    const isSel = this._prevSelectedSet.size > 0 ? (isReq || this._prevSelectedSet.has(o.productCode)) : !!(o.isSelected || isReq);
                    
                    return {
                        optionId: o.optionId,
                        productId: o.productId,
                        productCode: o.productCode,
                        name: o.name,
                        price: parseFloat(o.price || 0),
                        chargeType: o.chargeType || 'One-Time',
                        isBundled: !!o.isBundled,
                        isRequired: isReq,
                        isSelected: isSel,
                        isFree: parseFloat(o.price || 0) === 0,
                        disabledReason: '',
                        cardClass: 'cpq-option-card'
                    };
                }),
                isSatisfied: false,
                statusClass: '',
                statusIcon: '',
                statusLabel: '',
                validationError: ''
            };
        });

        this._refreshModal(features);
    }

    _refreshModal(features) {
        for (const f of features)
            for (const o of f.options) { o.isDisabled = false; o.disabledReason = ''; }

        const sel = new Set();
        for (const f of features)
            for (const o of f.options)
                if (o.isSelected) sel.add(o.productCode);

        for (const code of sel) {
            for (const ex of (this._exclusionMap[code] || [])) {
                for (const f of features)
                    for (const o of f.options)
                        if (o.productCode === ex && !o.isRequired) {
                            o.isDisabled = true; o.disabledReason = `Excluded by ${code}`; o.isSelected = false;
                        }
            }
        }

        for (const f of features)
            for (const o of f.options) {
                if (o.isRequired) continue;
                const unmet = (this._dependencyMap[o.productCode] || []).filter(p => !sel.has(p));
                if (unmet.length > 0) {
                    o.isDisabled = true; o.disabledReason = `Requires: ${unmet.join(', ')}`; o.isSelected = false;
                }
            }

        for (const f of features)
            for (const o of f.options) {
                if (o.isRequired) { o.isDisabled = false; o.isSelected = true; }
                const cls = ['cpq-option-card'];
                if (o.isSelected) cls.push('is-selected');
                if (o.isDisabled) cls.push('is-disabled');
                if (o.isRequired) cls.push('is-required');
                o.cardClass = cls.join(' ');
            }

        let allOk = true;
        for (const f of features) {
            const count = f.options.filter(o => o.isSelected).length;
            f.selectedCount = count;
            if (f.minOpt === 0 && f.maxOpt >= 999) {
                f.isSatisfied = true; f.statusClass = 'cpq-vstatus-optional';
                f.statusIcon = '○'; f.statusLabel = `${count} selected (optional)`;
                f.validationError = '';
            } else if (count < f.minOpt) {
                f.isSatisfied = false; f.statusClass = 'cpq-vstatus-error';
                f.statusIcon = '✗'; f.statusLabel = `${count} / ${f.minOpt} required`;
                f.validationError = f.statusLabel; allOk = false;
            } else if (f.maxOpt < 999 && count > f.maxOpt) {
                f.isSatisfied = false; f.statusClass = 'cpq-vstatus-error';
                f.statusIcon = '✗'; f.statusLabel = `${count} selected — max ${f.maxOpt}`;
                f.validationError = f.statusLabel; allOk = false;
            } else {
                f.isSatisfied = true; f.statusClass = 'cpq-vstatus-ok';
                f.statusIcon = '✓'; f.statusLabel = `${count} selected`;
                f.validationError = '';
            }
        }

        let total = this._modalBasePrice || 0;
        for (const f of features)
            for (const o of f.options) {
                if (o.isSelected) {
                    if (!o.isBundled || o.price > 0) {
                        total += o.price;
                    }
                }
            }

        this.modalFeatures = features.map(f => ({ ...f, options: f.options.map(o => ({ ...o })) }));
        this.modalConfigTotal = parseFloat(total.toFixed(2));
        this.modalIsValid = allOk;
        this.modalBanner = features.map(f => ({
            featureId: f.featureId,
            name: f.name,
            isSatisfied: f.isSatisfied,
            statusClass: f.statusClass,
            statusIcon: f.statusIcon,
            statusLabel: f.statusLabel,
            rule: f.isRadio ? 'Choose exactly 1'
                : f.minOpt === 0 && f.maxOpt >= 999 ? 'Optional'
                    : f.minOpt === f.maxOpt ? `Exactly ${f.minOpt}`
                        : f.maxOpt >= 999 ? `Min ${f.minOpt}`
                            : `${f.minOpt} – ${f.maxOpt}`
        }));
    }

    handleBundleOptionToggle(event) {
        const featureId = event.currentTarget.dataset.featureId;
        const productCode = event.currentTarget.dataset.productCode;
        const checked = event.currentTarget.checked;

        const features = this.modalFeatures.map(f => ({
            ...f, options: f.options.map(o => ({ ...o }))
        }));

        const feature = features.find(f => f.featureId === featureId);
        if (!feature) return;
        const opt = feature.options.find(o => o.productCode === productCode);
        if (!opt) return;

        if (feature.isRadio) {
            feature.options.forEach(o => { if (!o.isRequired) o.isSelected = false; });
            opt.isSelected = true;
            opt.isDisabled = false;
            this._refreshModal(features);
            return;
        }

        if (opt.isDisabled) return;

        if (opt.isRequired && !checked) {
            this.dispatchEvent(new CustomEvent('toast', { detail: { title: 'Error', message: `"${opt.name}" is required`, variant: 'error' } }));
            return;
        }

        if (checked) {
            const cur = feature.options.filter(o => o.isSelected).length;
            if (feature.maxOpt < 999 && cur >= feature.maxOpt) {
                this.dispatchEvent(new CustomEvent('toast', { detail: { title: 'Error', message: `Max ${feature.maxOpt} for "${feature.name}"`, variant: 'error' } }));
                return;
            }
        }
        opt.isSelected = checked;

        this._refreshModal(features);
    }

    handleSaveBundleConfig() {
        if (!this.modalIsValid) {
            this.dispatchEvent(new CustomEvent('toast', { detail: { title: 'Error', message: 'Complete required selections before saving', variant: 'error' } }));
            return;
        }

        const bundleItem = {
            id: this.modalBundleCode,
            productId: this.modalBundleId,
            name: this.modalBundleName,
            productCode: this.modalBundleCode,
            family: 'Bundles',
            unitPrice: this.modalConfigTotal,
            lineTotal: this.modalConfigTotal,
            quantity: 1,
            bundleProducts: this.modalFeatures.flatMap(f => f.options).filter(o => o.isSelected).map(o => ({
                id: o.productId,
                productId: o.productId,
                productCode: o.productCode,
                optionId: o.optionId,
                name: o.name,
                chargeType: o.chargeType,
                unitPrice: o.price,
                isBundled: o.isBundled,
                isRequired: o.isRequired,
                selected: true
            }))
        };

        this.dispatchEvent(new CustomEvent('saveconfig', { detail: bundleItem }));
    }

    handleCloseBundleModal() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleModalContentClick(event) {
        event.stopPropagation();
    }
}
