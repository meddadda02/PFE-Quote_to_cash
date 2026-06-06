import { LightningElement, api } from 'lwc';

export default class CpqSummaryPanel extends LightningElement {
    @api labels = {};
    @api currentLang = 'en';
    @api canvasItems = [];
    @api selectedCurrency = 'MAD';
    
    @api subtotalPrice = 0;
    @api hasDiscounts = false;
    @api totalDiscountAmount = 0;
    @api netPrice = 0;
    @api discountBreakdown = '';
    
    @api quoteStatus = 'Draft';
    @api quoteStatusOptions = [];
    @api quoteStatusBadgeClass = '';
    @api isStatusChanged = false;
    @api isStatusInReview = false;
    @api isStatusApproved = false;
    
    @api isAddToQuoteDisabled = false;
    @api isCalculateDiscountsDisabled = false;
    
    @api hasCpqLines = false;
    @api isOrdered = false;
    @api isQuoteReadyToOrder = false;
    @api isMarkOrderedDisabled = false;
    @api orderNumber = '';
    
    @api isLoading = false;
    @api errorMessage = '';
    @api successMessage = '';

    get lbl() {
        return this.labels ? (this.labels[this.currentLang] || {}) : {};
    }

    handleManualDiscountChange(event) {
        this.dispatchEvent(new CustomEvent('manualdiscountchange', {
            detail: {
                uid: event.target.dataset.uid,
                disc: parseFloat(event.target.value) || 0
            }
        }));
    }

    handleQuoteStatusChange(event) {
        this.dispatchEvent(new CustomEvent('quotestatuschange', {
            detail: { value: event.detail.value }
        }));
    }

    handleSaveQuoteStatus() {
        this.dispatchEvent(new CustomEvent('savequotestatus'));
    }

    handleAddToQuote() {
        this.dispatchEvent(new CustomEvent('addtoquote'));
    }

    handleCalculateDiscounts() {
        this.dispatchEvent(new CustomEvent('calculatediscounts'));
    }

    handleMarkOrdered() {
        this.dispatchEvent(new CustomEvent('markordered'));
    }

    handleGoToOrderView() {
        this.dispatchEvent(new CustomEvent('gotoorderview'));
    }
}
