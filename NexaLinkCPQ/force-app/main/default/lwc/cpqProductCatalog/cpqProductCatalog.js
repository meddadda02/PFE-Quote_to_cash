import { LightningElement, api, track } from 'lwc';

export default class CpqProductCatalog extends LightningElement {
    @api labels;
    @api currentLang = 'en';
    @api allProducts = [];
    @api bundles = [];
    @api selectedCurrency = 'MAD';

    @track productSearchQuery = '';
    _searchTimeout;

    get lbl() {
        return this.labels ? this.labels[this.currentLang] : {};
    }

    get filteredProducts() {
        const term = (this.productSearchQuery || '').toLowerCase();
        if (!term) return this.allProducts || [];
        return (this.allProducts || []).filter(p =>
            (p.name && p.name.toLowerCase().includes(term)) ||
            (p.productCode && p.productCode.toLowerCase().includes(term)) ||
            (p.family && p.family.toLowerCase().includes(term))
        );
    }

    get filteredBundles() {
        const term = (this.productSearchQuery || '').toLowerCase();
        if (!term) return this.bundles || [];
        return (this.bundles || []).filter(b =>
            (b.name && b.name.toLowerCase().includes(term)) ||
            (b.description && b.description.toLowerCase().includes(term))
        );
    }

    handleProductSearchChange(event) {
        this.productSearchQuery = event.target.value;
        // The filtering happens locally in the getter, so we don't need to call Apex here.
        // We just clear any timeout since the parent used to handle debounced Apex calls.
        window.clearTimeout(this._searchTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimeout = window.setTimeout(() => { 
            // In the parent, _loadCatalog() was called, but here we already have the items locally
            // If we still need to notify parent:
            this.dispatchEvent(new CustomEvent('searchchange', { detail: this.productSearchQuery }));
        }, 400);
    }

    handleProductDragStart(event) {
        const btn = event.currentTarget;
        const dragData = {
            type: 'product',
            id: btn.dataset.id,
            productId: btn.dataset.productid,
            name: btn.dataset.name,
            price: btn.dataset.price,
            code: btn.dataset.code,
            family: btn.dataset.family,
            charge: btn.dataset.charge
        };
        event.dataTransfer.setData('text/plain', JSON.stringify(dragData));
        event.dataTransfer.effectAllowed = 'copy';
        
        // Let parent know if it needs to know, though standard drag/drop works across DOM
        this.dispatchEvent(new CustomEvent('productdragstart', { detail: dragData }));
    }

    handleBundleDragStart(event) {
        const btn = event.currentTarget;
        const dragData = {
            type: 'bundle',
            id: btn.dataset.id,
            name: btn.dataset.name
        };
        event.dataTransfer.setData('text/plain', JSON.stringify(dragData));
        event.dataTransfer.effectAllowed = 'copy';
        
        this.dispatchEvent(new CustomEvent('bundledragstart', { detail: dragData }));
    }

    handleQuickAddProduct(event) {
        const btn = event.currentTarget;
        const detail = {
            id: btn.dataset.id,
            productId: btn.dataset.productid,
            name: btn.dataset.name,
            price: btn.dataset.price,
            code: btn.dataset.code,
            family: btn.dataset.family,
            charge: btn.dataset.charge
        };
        this.dispatchEvent(new CustomEvent('quickaddproduct', { detail }));
    }

    handleSelectBundle(event) {
        const btn = event.currentTarget;
        const detail = {
            id: btn.dataset.id,
            name: btn.dataset.name
        };
        this.dispatchEvent(new CustomEvent('selectbundle', { detail }));
    }
}
