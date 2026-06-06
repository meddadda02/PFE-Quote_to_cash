import { LightningElement, track, api } from 'lwc';
import createNewCustomerQuote from '@salesforce/apex/CPQCustomerOnboardingController.createNewCustomerQuote';
import createOpportunityForAccount from '@salesforce/apex/CPQQuoteController.createOpportunityForAccount';
import createQuote from '@salesforce/apex/CPQCustomerOnboardingController.createQuote';
import getAccounts from '@salesforce/apex/CPQCustomerOnboardingController.getAccounts';
import getOpportunities from '@salesforce/apex/CPQCustomerOnboardingController.getOpportunities';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpqNewQuoteModal extends LightningElement {
    @api labels;
    @api currentLang = 'en';

    @track quoteWorkflow = 'New';
    @track customerType = 'Individual';
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track phone = '';
    @track companyName = '';
    @track opportunityName = '';
    @track country = 'Morocco';
    @track selectedCurrency = 'MAD';
    @track isNewCustomer = false;
    @track isStudent = false;
    @track isTelecomEmployee = false;
    @track isExistingCustomer = false;
    
    @track accountSearch = '';
    @track accounts = [];
    @track selectedAccount = null;
    @track opportunityOptions = [];
    @track selectedOpportunityId = null;
    
    @track showNewOppForm = false;
    @track newOppName = '';
    @track newOppCloseDate = '';
    @track newOppCurrency = 'MAD';
    
    @track isLoading = false;
    _opportunitiesFull = [];
    
    get lbl() { return this.labels ? this.labels[this.currentLang] : {}; }
    get isIndividual() { return this.customerType === 'Individual'; }
    get isCompany() { return this.customerType === 'Company'; }
    get isNewWorkflow() { return this.quoteWorkflow === 'New'; }
    get isExistingWorkflow() { return this.quoteWorkflow === 'Existing'; }
    get isOppDropdownDisabled() { return this.showNewOppForm; }
    
    get currencyOptions() {
        return [
            { label: 'MAD - Moroccan Dirham', value: 'MAD' },
            { label: 'EUR - Euro', value: 'EUR' },
            { label: 'USD - US Dollar', value: 'USD' }
        ];
    }
    
    get countryOptions() {
        return [
            { label: 'Morocco', value: 'Morocco' },
            { label: 'France', value: 'France' },
            { label: 'Germany', value: 'Germany' },
            { label: 'USA', value: 'USA' },
            { label: 'Spain', value: 'Spain' }
        ];
    }
    
    handleCloseNewQuoteModal() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleWorkflowChange(event) {
        this.quoteWorkflow = event.target.value;
        this.selectedAccount = null;
        this.selectedOpportunityId = null;
        this.opportunityOptions = [];
        this.showNewOppForm = false;
    }

    handleNewQuoteInputChange(event) {
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        if (field === 'customerTypeToggle') {
            this.customerType = value ? 'Company' : 'Individual';
            if (this.isCompany) {
                this.isStudent = false;
            }
        } else {
            this[field] = value;
        }
    }

    handleSubmitNewQuote() {
        if (this.isExistingWorkflow) {
            this.handleCreateQuoteExisting();
            return;
        }

        const requiredFields = ['opportunityName', 'selectedCurrency', 'country'];
        if (this.isIndividual) {
            requiredFields.push('firstName', 'lastName');
        } else {
            requiredFields.push('companyName', 'firstName', 'lastName');
        }

        for (const f of requiredFields) {
            if (!this[f]) {
                this._toast('Error', `Field ${f} is required`, 'error');
                return;
            }
        }

        this.isLoading = true;
        const payload = {
            customerType: this.customerType,
            firstName: this.firstName,
            lastName: this.lastName,
            email: this.email,
            phone: this.phone,
            companyName: this.companyName,
            opportunityName: this.opportunityName,
            currencyCode: this.selectedCurrency,
            country: this.country,
            isNewCustomer: String(this.isNewCustomer),
            isStudent: String(this.isStudent),
            isTelecomEmployee: String(this.isTelecomEmployee),
            isExistingCustomer: String(this.isExistingCustomer)
        };

        createNewCustomerQuote({ formData: payload })
            .then(res => {
                this.isLoading = false;
                this.dispatchEvent(new CustomEvent('quotecreated', {
                    detail: {
                        id: res.id,
                        name: res.name,
                        accountName: this.isIndividual ? (this.firstName + ' ' + this.lastName) : this.companyName,
                        currency: this.selectedCurrency
                    }
                }));
            })
            .catch(e => {
                this.isLoading = false;
                this._toast('Error', e.body?.message || e.message, 'error');
            });
    }

    handleAccountSearch(event) {
        this.accountSearch = event.target.value;
        if (this.accountSearch.length >= 2) {
            this.isLoading = true;
            getAccounts({ searchTerm: this.accountSearch })
                .then(r => { this.accounts = r || []; this.isLoading = false; })
                .catch(e => { this.isLoading = false; });
        } else { 
            this.accounts = []; 
        }
    }

    handleModalAccountSelect(event) {
        const accountId = event.currentTarget.dataset.id;
        const accountName = event.currentTarget.dataset.name;
        this.selectedAccount = { id: accountId, name: accountName };
        this.accountSearch = '';
        this.accounts = [];
        this.isLoading = true;
        
        getOpportunities({ accountId })
            .then(r => {
                if (r && r.length > 0) {
                    this._opportunitiesFull = r;
                    this.opportunityOptions = r.map(o => ({ label: o.name, value: o.id }));
                    this.selectedCurrency = r[0].currency || 'MAD';
                } else {
                    this._opportunitiesFull = [];
                    this.opportunityOptions = [];
                    this.selectedCurrency = 'MAD';
                }
                this.isLoading = false;
            })
            .catch(e => { this.isLoading = false; });
    }

    handleClearAccount() {
        this.selectedAccount = null;
        this.selectedOpportunityId = null;
        this.opportunityOptions = [];
    }

    handleOpportunitySelect(event) {
        this.selectedOpportunityId = event.target.value;
        const opp = this._opportunitiesFull.find(o => o.id === this.selectedOpportunityId);
        if (opp && opp.currency) {
            this.selectedCurrency = opp.currency;
        }
    }

    handleToggleNewOppForm() {
        this.showNewOppForm = !this.showNewOppForm;
        if (this.showNewOppForm) {
            const d = new Date();
            d.setDate(d.getDate() + 30);
            this.newOppCloseDate = d.toISOString().split('T')[0];
            this.newOppCurrency = this.selectedCurrency || 'MAD';
            this.selectedOpportunityId = null;
        }
    }

    handleNewOppInputChange(event) {
        this[event.target.name] = event.detail?.value || event.target.value;
    }

    handleCreateOppAndQuote() {
        if (!this.selectedAccount) return;
        this.isLoading = true;
        const currency = this.newOppCurrency || this.selectedCurrency || 'MAD';
        
        createOpportunityForAccount({
            accountId: this.selectedAccount.id,
            oppName: this.newOppName,
            closeDate: this.newOppCloseDate,
            currencyCode: currency
        })
        .then(oppResult => {
            return createQuote({
                accountId: this.selectedAccount.id,
                opportunityId: oppResult.id,
                currencyCode: currency
            });
        })
        .then(quoteResult => {
            this.isLoading = false;
            this.dispatchEvent(new CustomEvent('quotecreated', {
                detail: {
                    id: quoteResult.id,
                    name: quoteResult.name,
                    accountName: this.selectedAccount.name,
                    currency: currency
                }
            }));
        })
        .catch(e => {
            this.isLoading = false;
            this._toast('Error', e.body?.message || e.message, 'error');
        });
    }

    handleCreateQuoteExisting() {
        if (!this.selectedAccount || !this.selectedOpportunityId) return;
        this.isLoading = true;
        
        createQuote({
            accountId: this.selectedAccount.id,
            opportunityId: this.selectedOpportunityId,
            currencyCode: this.selectedCurrency
        })
        .then(res => {
            this.isLoading = false;
            this.dispatchEvent(new CustomEvent('quotecreated', {
                detail: {
                    id: res.id,
                    name: res.name,
                    accountName: this.selectedAccount.name,
                    currency: this.selectedCurrency
                }
            }));
        })
        .catch(e => {
            this.isLoading = false;
            this._toast('Error', e.body?.message || e.message, 'error');
        });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
