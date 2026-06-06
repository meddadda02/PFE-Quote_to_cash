import { LightningElement, api } from 'lwc';

export default class CpqOrderInterface extends LightningElement {
    @api labels;
    @api currentLang = 'en';
    @api quoteName;
    @api orderNumber;
    @api orderStatus;
    @api orderStatusOptions = [];
    @api selectedCurrency;
    @api userInitials;
    @api selectedAccountName;
    
    @api isOrderActivated;
    @api isOrderActivating;
    @api isContracted;
    @api isOrderStatusChanged;
    @api isMarkContractedDisabled;
    
    @api orderLines = [];
    @api orderTotalAmount;
    @api contractNumber;
    @api contractStatus;
    
    @api isLoading;
    @api errorMessage;
    @api successMessage;

    get lbl() {
        return this.labels ? this.labels[this.currentLang] : {};
    }

    get hasOrderLines() {
        return this.orderLines && this.orderLines.length > 0;
    }

    handleBackToQuote() {
        this.dispatchEvent(new CustomEvent('backtoquote'));
    }

    handleOrderStatusChange(event) {
        this.dispatchEvent(new CustomEvent('orderstatuschange', { detail: { value: event.detail.value } }));
    }

    handleSaveOrderStatus() {
        this.dispatchEvent(new CustomEvent('saveorderstatus'));
    }

    handleMarkContracted() {
        this.dispatchEvent(new CustomEvent('markcontracted'));
    }

    handleGoToContract() {
        this.dispatchEvent(new CustomEvent('gotocontract'));
    }
}
