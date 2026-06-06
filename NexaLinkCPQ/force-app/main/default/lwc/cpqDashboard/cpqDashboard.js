import { LightningElement, api, track } from 'lwc';
import getQuotes from '@salesforce/apex/CPQDashboardController.getQuotes';
import getRecentQuotes from '@salesforce/apex/CPQDashboardController.getRecentQuotes';
import NEXA_CREATE_ICON from '@salesforce/resourceUrl/NexaCreateIcon';
import NEXA_RECENT_ICON from '@salesforce/resourceUrl/NexaRecentIcon';
import NEXA_SEARCH_ICON from '@salesforce/resourceUrl/NexaSearchIcon';

export default class CpqDashboard extends LightningElement {
    @api labels;
    @api currentLang = 'en';
    
    @track quoteSearchTerm = '';
    @track searchedQuotes = [];
    @track recentQuotes = [];
    @track errorMessage = '';

    createIcon = NEXA_CREATE_ICON;
    recentIcon = NEXA_RECENT_ICON;
    searchIcon = NEXA_SEARCH_ICON;

    get lbl() {
        return this.labels ? this.labels[this.currentLang] : {};
    }

    connectedCallback() {
        this.loadRecentQuotes();
    }

    loadRecentQuotes() {
        getRecentQuotes()
            .then(r => { this.recentQuotes = r || []; })
            .catch(e => { this.errorMessage = 'Recent quotes error: ' + (e.message || e.body?.message); });
    }

    handleQuoteSearch(event) {
        this.quoteSearchTerm = event.target.value;
        if (this.quoteSearchTerm.length >= 2) {
            getQuotes({ searchTerm: this.quoteSearchTerm })
                .then(r => { this.searchedQuotes = r || []; })
                .catch(e => { this.errorMessage = 'Quote search failed: ' + (e.message || e.body?.message); });
        } else {
            this.searchedQuotes = [];
        }
    }

    handleQuoteSelect(event) {
        const detail = {
            id: event.currentTarget.dataset.id,
            name: event.currentTarget.dataset.name,
            account: event.currentTarget.dataset.account,
            currency: event.currentTarget.dataset.currency
        };
        this.dispatchEvent(new CustomEvent('quoteselect', { detail }));
    }

    handleOpenNewQuoteModal() {
        this.dispatchEvent(new CustomEvent('createnew'));
    }
}
