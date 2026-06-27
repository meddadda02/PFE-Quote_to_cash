import { LightningElement, track } from 'lwc'; // Importation des classes de base LWC (Composant et décorateur de réactivité)
import getAccounts from '@salesforce/apex/CPQCustomerOnboardingController.getAccounts'; // Importation de la méthode Apex pour rechercher des comptes
import getOpportunities from '@salesforce/apex/CPQCustomerOnboardingController.getOpportunities'; // Importation de la méthode Apex pour récupérer les opportunités
import getProducts from '@salesforce/apex/CPQProductCatalogController.getProducts'; // Importation de la méthode Apex pour lister les produits simples
import getBundles from '@salesforce/apex/CPQProductCatalogController.getBundles'; // Importation de la méthode Apex pour lister les bundles
import getBundleWithFeatures from '@salesforce/apex/CPQProductCatalogController.getBundleWithFeatures'; // Importation de la méthode Apex pour la structure d'un bundle
import createQuote from '@salesforce/apex/CPQCustomerOnboardingController.createQuote'; // Importation de la méthode Apex pour créer un nouveau devis
import clearAndAddAllBundles from '@salesforce/apex/CPQPricingController.clearAndAddAllBundles'; // Importation de la méthode pour réinitialiser et ajouter les items
import calculatePricing from '@salesforce/apex/CPQPricingController.calculatePricing'; // Importation de la méthode pour lancer le calcul CPQ
import syncProductsToQuote from '@salesforce/apex/CPQPricingController.syncProductsToQuote'; // Importation de la méthode de synchronisation du canvas
import getQuotes from '@salesforce/apex/CPQDashboardController.getQuotes'; // Importation de la méthode de recherche de devis
import getRecentQuotes from '@salesforce/apex/CPQDashboardController.getRecentQuotes'; // Importation de la méthode pour les devis récents
import getQuoteLines from '@salesforce/apex/CPQPricingController.getQuoteLines'; // Importation de la méthode pour charger les lignes d'un devis
import submitHighDiscountForApproval from '@salesforce/apex/CPQPricingController.submitHighDiscountForApproval';
import getQuoteHeader from '@salesforce/apex/CPQQuoteController.getQuoteHeader'; // Pour charger les métadonnées du devis
import updateQuoteStatus from '@salesforce/apex/CPQQuoteController.updateQuoteStatus'; // Pour changer le statut du devis
import markQuoteOrdered from '@salesforce/apex/CPQOrderContractController.markQuoteOrdered'; // Déclenche la création de l'Order CPQ
import markOrderContracted from '@salesforce/apex/CPQOrderContractController.markOrderContracted'; // Déclenche la création du Contract CPQ
import getOrderLines from '@salesforce/apex/CPQOrderContractController.getOrderLines'; // Récupère les items de la commande
import updateOrderStatus from '@salesforce/apex/CPQOrderContractController.updateOrderStatus'; // Pour activer l'order
import getContractsForOrder from '@salesforce/apex/CPQOrderContractController.getContractsForOrder'; // Pour vérifier le contrat
import getOrdersForQuote from '@salesforce/apex/CPQOrderContractController.getOrdersForQuote'; // Pour le polling de création d'order
import getOrderHeader from '@salesforce/apex/CPQOrderContractController.getOrderHeader'; // Pour charger les métadonnées de la commande
import createNewCustomerQuote from '@salesforce/apex/CPQCustomerOnboardingController.createNewCustomerQuote'; // Importation de la méthode pour créer compte+opp+devis d'un coup
import getNexaLinkTemplateId from '@salesforce/apex/CPQQuoteController.getNexaLinkTemplateId';
import createOpportunityForAccount from '@salesforce/apex/CPQQuoteController.createOpportunityForAccount';
import generateAndSendEmail from '@salesforce/apex/CPQQuoteController.generateAndSendEmail';
import generateDocument from '@salesforce/apex/CPQQuoteController.generateDocument';
import generateAndSendForSignature from '@salesforce/apex/CPQQuoteController.generateAndSendForSignature';

import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // Importation de l'utilitaire pour afficher des notifications (toasts)
import NEXA_CREATE_ICON from '@salesforce/resourceUrl/NexaCreateIcon';
import NEXA_RECENT_ICON from '@salesforce/resourceUrl/NexaRecentIcon';
import NEXA_SEARCH_ICON from '@salesforce/resourceUrl/NexaSearchIcon';
import NEXA_LANG_ICON from '@salesforce/resourceUrl/NexaLangIcon';

const LABELS = {
    en: {
        dashboardTitle: 'NexaLink CPQ Configurator',
        dashboardSubtitle: 'Select a quote to edit or create a new one to get started.',
        searchCardTitle: 'Search on a Quote',
        searchCardSubtitle: 'Edit an existing quote by number or account name.',
        searchPlaceholder: 'Quote # or Account...',
        createCardTitle: 'New Quote',
        createCardSubtitle: 'Instantly create a new customer and a ready-to-configure quote.',
        newQuoteBtn: '+ New Quote',
        recentCardTitle: 'Recent Quotes',
        recentCardSubtitle: 'Quickly access your most recently created quotes.',
        noRecentQuotes: 'No recent quotes found.',
        configuratorTitle: 'NexaLink Visual CPQ Configurator',
        orderInterfaceTitle: 'Order Interface',
        stepQuoteCreated: 'Quote Created',
        stepConfigurePrice: 'Configure & Price',
        stepMarkOrdered: 'Mark Ordered',
        stepActivateOrder: 'Activate Order',
        stepContract: 'Contract',
        leftPanelTitle: 'Search Products & Bundles',
        searchInputLabel: 'Find Product or Bundle',
        searchInputPlaceholder: 'Mobile, 5G, TV, Fiber, SmartHome...',
        bundleBadge: 'BUNDLE',
        bundlesSectionLabel: 'Bundles',
        noResultsMsg: 'No products or bundles found matching',
        addBtn: '+ Add',
        modifyBtn: '✏️ Modify',
        canvasTitle: 'Configuration Canvas',
        clearCanvasBtn: 'Clear Canvas',
        canvasEmptyMsg: 'Search products above or select a bundle to add items',
        summaryTitle: 'Quote Summary',
        noItemsMsg: 'No items added yet',
        subtotal: 'Subtotal (Before Discount)',
        totalDiscount: 'Total Discount',
        netTotal: 'Net Total (HT)',
        discountDetailsLabel: 'DISCOUNT DETAILS',
        appliedDiscountsLabel: 'Applied Discounts',
        quoteConfigTitle: 'Quote Configuration',
        quoteStatusLabel: 'Quote Status',
        saveQuoteStatusBtn: 'Save Quote Status',
        addToQuoteBtn: 'Add to Quote',
        calculateDiscountsBtn: 'Calculate Discounts',
        generatePDFBtn: 'Generate & Send Email',
        orderReadyLabel: 'Quote is ready to order',
        statusWarningMsg: 'Quote pending approval — wait for manager to approve before ordering.',
        markOrderedBtn: 'Mark Ordered — Create Order',
        orderCreatedPrefix: 'Order',
        orderCreatedSuffix: 'created —',
        openOrderInterfaceLink: 'Open Order Interface →',
        backToQuoteLink: '← Back to Quote',
        orderStatusLabel: 'Order Status:',
        orderNumberLabel: 'Order Number:',
        activateHint: 'Change the Order Status to Activated to enable contract generation.',
        setOrderStatusLabel: 'Set Order Status',
        saveOrderStatusBtn: 'Save Order Status',
        orderActivatedMsg: 'Order is Activated — ready for contracting',
        orderProductsTitle: 'Order Products',
        loadingMsg: 'Loading...',
        colProduct: 'Product',
        colCode: 'Code',
        colQty: 'Qty',
        colUnitPrice: 'Unit Price',
        colTotalPrice: 'Total Price',
        colChargeType: 'Charge Type',
        orderTotalLabel: 'Order Total',
        markContractedBtn: 'Mark Contracted — Generate Contract',
        orderActivatedForContract: 'Order is Activated — generate contract now.',
        activateFirstMsg: 'Activate the Order first to enable contract generation.',
        saveStatusWarning: 'Please SAVE the status change to "Activated" before contracting.',
        contractCreatedMsg: 'Contract Generated!',
        contractPrefix: 'Contract',
        contractStatusSep: '— Status:',
        openContractLink: 'Open Contract in Salesforce →',
        bundleModalBadge: 'CPQ CONFIGURATOR',
        bundleReadyMsg: 'Bundle ready to add',
        completeRequiredMsg: 'Complete required selections',
        saveConfigBtn: 'Save Configuration',
        bundleTotalLabel: 'Bundle Total:',
        cancelBtn: 'Cancel',
        includedTag: 'INCLUDED',
        requiredTag: 'REQUIRED',
        newQuoteModalBadge: 'AUTOMATION',
        newQuoteModalTitle: 'Generate New Quote',
        newCustomerTab: 'New Customer',
        existingCustomerTab: 'Existing Customer',
        individualLabel: 'Individual',
        companyLabel: 'Company',
        firstNameLabel: 'First Name',
        lastNameLabel: 'Last Name',
        companyNameLabel: 'Company Name',
        contactFirstNameLabel: 'Contact First Name',
        contactLastNameLabel: 'Contact Last Name',
        emailLabel: 'Email Address',
        phoneLabel: 'Phone Number',
        discountEligibilityTitle: 'Discount Eligibility',
        isNewCustomerLabel: 'Is New Customer',
        isStudentLabel: 'Is Student',
        isTelecomEmployeeLabel: 'Is Telecom Employee',
        isExistingCustomerLabel: 'Is Existing Customer',
        opportunityNameLabel: 'Opportunity Name',
        opportunityNamePlaceholder: 'e.g. New Business 2024',
        currencyLabel: 'Currency',
        countryLabel: 'Country',
        generateRecordsBtn: 'Generate Records & Configure',
        findAccountLabel: 'Find Account',
        findAccountPlaceholder: 'Search by name...',
        usingCurrencyLabel: 'Using Currency:',
        selectOpportunityLabel: 'Select Opportunity',
        addNewOpportunityBtn: '+ New Opportunity',
        newOppNameLabel: 'Opportunity Name',
        newOppCloseDateLabel: 'Close Date',
        createOppAndQuoteBtn: 'Create Opportunity & Quote',
        generateDocumentLabel: 'Generate Quote Document',
        generateDocumentBtn: 'Generate Document',
        sendForSignatureLabel: 'Send for Signature via DocuSign',
        sendForSignatureBtn: 'Send for Signature',
        sendForSignatureHint: 'Generate the document first, then send it to the client for signature.'
    },
    fr: {
        dashboardTitle: 'Configurateur CPQ NexaLink',
        dashboardSubtitle: 'Sélectionnez un devis à modifier ou créez-en un nouveau pour commencer.',
        searchCardTitle: 'Rechercher un devis',
        searchCardSubtitle: 'Modifier un devis existant par numéro ou nom de compte.',
        searchPlaceholder: 'N° de devis ou compte...',
        createCardTitle: 'Nouveau devis',
        createCardSubtitle: 'Créez instantanément un nouveau client et un devis prêt à configurer.',
        newQuoteBtn: '+ Nouveau devis',
        recentCardTitle: 'Devis récents',
        recentCardSubtitle: 'Accédez rapidement à vos devis créés récemment.',
        noRecentQuotes: 'Aucun devis récent trouvé.',
        configuratorTitle: 'Configurateur CPQ Visuel NexaLink',
        orderInterfaceTitle: 'Interface de commande',
        stepQuoteCreated: 'Devis créé',
        stepConfigurePrice: 'Configurer et tarifer',
        stepMarkOrdered: 'Marquer commandé',
        stepActivateOrder: 'Activer la commande',
        stepContract: 'Contrat',
        leftPanelTitle: 'Rechercher produits et offres groupées',
        searchInputLabel: 'Trouver un produit ou une offre groupée',
        searchInputPlaceholder: 'Mobile, 5G, TV, Fibre, Maison connectée...',
        bundleBadge: 'OFFRE',
        bundlesSectionLabel: 'Offres groupées',
        noResultsMsg: 'Aucun produit ou offre groupée trouvé correspondant à',
        addBtn: '+ Ajouter',
        modifyBtn: '✏️ Modifier',
        canvasTitle: 'Canevas de configuration',
        clearCanvasBtn: 'Effacer le canevas',
        canvasEmptyMsg: 'Recherchez des produits ci-dessus ou sélectionnez une offre groupée',
        summaryTitle: 'Résumé du devis',
        noItemsMsg: 'Aucun article ajouté',
        subtotal: 'Sous-total (avant remise)',
        totalDiscount: 'Remise totale',
        netTotal: 'Total net (HT)',
        discountDetailsLabel: 'DÉTAILS DES REMISES',
        appliedDiscountsLabel: 'Remises appliquées',
        quoteConfigTitle: 'Configuration du devis',
        quoteStatusLabel: 'Statut du devis',
        saveQuoteStatusBtn: 'Enregistrer le statut',
        addToQuoteBtn: 'Ajouter au devis',
        calculateDiscountsBtn: 'Calculer les remises',
        generatePDFBtn: 'Générer & Envoyer par email',
        orderReadyLabel: 'Le devis est prêt à être commandé',
        statusWarningMsg: 'Devis en attente d\'approbation — attendez l\'approbation du manager avant de commander.',
        markOrderedBtn: 'Marquer commandé — Créer une commande',
        orderCreatedPrefix: 'Commande',
        orderCreatedSuffix: 'créée —',
        openOrderInterfaceLink: "Ouvrir l'interface de commande →",
        backToQuoteLink: '← Retour au devis',
        orderStatusLabel: 'Statut de la commande :',
        orderNumberLabel: 'Numéro de commande :',
        activateHint: "Changez le statut de la commande en Activée pour permettre la génération du contrat.",
        setOrderStatusLabel: 'Définir le statut de la commande',
        saveOrderStatusBtn: 'Enregistrer le statut de la commande',
        orderActivatedMsg: 'Commande activée — prête pour la contractualisation',
        orderProductsTitle: 'Produits commandés',
        loadingMsg: 'Chargement...',
        colProduct: 'Produit',
        colCode: 'Code',
        colQty: 'Qté',
        colUnitPrice: 'Prix unitaire',
        colTotalPrice: 'Prix total',
        colChargeType: 'Type de facturation',
        orderTotalLabel: 'Total de la commande',
        markContractedBtn: 'Marquer contractualisé — Générer le contrat',
        orderActivatedForContract: 'Commande activée — générez le contrat maintenant.',
        activateFirstMsg: "Activez d'abord la commande pour permettre la génération du contrat.",
        saveStatusWarning: 'Veuillez ENREGISTRER le changement de statut en "Activée" avant de contractualiser.',
        contractCreatedMsg: 'Contrat généré !',
        contractPrefix: 'Contrat',
        contractStatusSep: '— Statut :',
        openContractLink: 'Ouvrir le contrat dans Salesforce →',
        bundleModalBadge: 'CONFIGURATEUR CPQ',
        bundleReadyMsg: "Offre groupée prête à ajouter",
        completeRequiredMsg: 'Complétez les sélections requises',
        saveConfigBtn: 'Enregistrer la configuration',
        bundleTotalLabel: "Total de l'offre :",
        cancelBtn: 'Annuler',
        includedTag: 'INCLUS',
        requiredTag: 'REQUIS',
        newQuoteModalBadge: 'AUTOMATISATION',
        newQuoteModalTitle: 'Générer un nouveau devis',
        newCustomerTab: 'Nouveau client',
        existingCustomerTab: 'Client existant',
        individualLabel: 'Particulier',
        companyLabel: 'Entreprise',
        firstNameLabel: 'Prénom',
        lastNameLabel: 'Nom de famille',
        companyNameLabel: "Nom de l'entreprise",
        contactFirstNameLabel: 'Prénom du contact',
        contactLastNameLabel: 'Nom du contact',
        emailLabel: 'Adresse e-mail',
        phoneLabel: 'Numéro de téléphone',
        discountEligibilityTitle: 'Éligibilité aux remises',
        isNewCustomerLabel: 'Nouveau client',
        isStudentLabel: 'Étudiant',
        isTelecomEmployeeLabel: 'Employé télécom',
        isExistingCustomerLabel: 'Client existant',
        opportunityNameLabel: "Nom de l'opportunité",
        opportunityNamePlaceholder: 'ex. Nouvelle affaire 2024',
        currencyLabel: 'Devise',
        countryLabel: 'Pays',
        generateRecordsBtn: 'Générer les enregistrements et configurer',
        findAccountLabel: 'Trouver un compte',
        findAccountPlaceholder: 'Rechercher par nom...',
        usingCurrencyLabel: 'Devise utilisée :',
        selectOpportunityLabel: 'Sélectionner une opportunité',
        addNewOpportunityBtn: '+ Nouvelle Opportunité',
        newOppNameLabel: "Nom de l'Opportunité",
        newOppCloseDateLabel: 'Date de Clôture',
        createOppAndQuoteBtn: 'Créer Opportunité & Devis',
        generateDocumentLabel: 'Générer le document du devis',
        generateDocumentBtn: 'Générer le document',
        sendForSignatureLabel: 'Envoyer pour signature via DocuSign',
        sendForSignatureBtn: 'Envoyer pour signature',
        sendForSignatureHint: 'Générez d\'abord le document, puis envoyez-le au client pour signature.'
    }
};

export default class CpqConfigurator extends LightningElement { // Définition de la classe principale du composant

    // Icons for Dashboard
    createIcon = NEXA_CREATE_ICON;
    recentIcon = NEXA_RECENT_ICON;
    searchIcon = NEXA_SEARCH_ICON;
    langIcon = NEXA_LANG_ICON;

    @track currentLang = 'en';
    @track quoteId = null; // Identifiant du devis actuellement sélectionné ou créé
    @track quoteName = ''; // Nom affiché du devis
    @track quoteStatus = 'Draft'; // Statut actuel du devis
    @track selectedAccount = null; // Objet stockant les infos du compte sélectionné (id, nom, pays)
    @track selectedCurrency = 'MAD'; // Code devise par défaut pour les recherches de prix
    @track accountSearch = ''; // Terme saisi par l'utilisateur pour rechercher un compte

    // Order & Contract Workflow State
    @track showOrderView = false;      // Toggle between Quote and Order screens
    @track orderId = null;            // Created Order ID
    @track orderNumber = '';          // Created Order Number
    @track orderStatus = 'Draft';     // Order Status (current UI value)
    @track persistedOrderStatus = 'Draft'; // Order Status (saved in Salesforce)
    @track orderLines = [];           // Order Products
    @track orderTotalAmount = 0;      // Total of the order
    @track isOrdered = false;         // Is the quote marked as ordered?
    @track isContracted = false;      // Is the order marked as contracted?
    @track contractId = null;         // Created Contract ID
    @track contractNumber = '';       // Created Contract Number
    @track contractStatus = '';       // Created Contract Status
    @track isStatusChanged = false;   // Flag to show "Save" button for quote status
    @track nexaLinkTemplateId = null;

    // New Quote Modal State
    @track showNewQuoteModal = false;
    @track quoteWorkflow = 'New'; // 'New' or 'Existing'
    @track customerType = 'Individual';
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track phone = '';
    @track companyName = '';
    @track opportunityName = '';
    @track country = 'Morocco';
    @track isNewCustomer = false;
    @track isStudent = false;
    @track isTelecomEmployee = false;
    @track isExistingCustomer = false;

    // UI Helpers for Progress Tracker
    get isOrderActivating() { return this.persistedOrderStatus === 'Draft' && this.orderId; }
    get isOrderActivated() { return this.persistedOrderStatus === 'Activated' || this.persistedOrderStatus === 'Contracted'; }
    get isOrderStatusChanged() { return this.orderStatus !== this.persistedOrderStatus; }

    get isQuoteReadyToOrder() {
        // Draft is allowed — Apex auto-advances to Presented before creating the order
        // Block only quotes pending approval
        const blockedStatuses = ['Needs Review', 'In Review'];
        return !blockedStatuses.includes(this.quoteStatus) && this.quoteStatus !== '';
    }

    get isQuotePresented() {
        return this.quoteStatus === 'Presented';
    }

    get isMarkOrderedDisabled() {
        return this.isLoading || !this.hasCpqLines || !this.isQuoteReadyToOrder;
    }

    get isMarkContractedDisabled() {
        // Must be activated, not already contracted, and NO pending status changes
        return this.isLoading || !this.isOrderActivated || this.isContracted || this.isOrderStatusChanged;
    }

    get orderStatusOptions() {
        return [
            { label: 'Draft', value: 'Draft' },
            { label: 'Activated', value: 'Activated' }
        ];
    }

    get quoteStatusOptions() {
        return [
            { label: 'Draft', value: 'Draft' },
            { label: 'In Review', value: 'In Review' },
            { label: 'Presented', value: 'Presented' },
            { label: 'Approved', value: 'Approved' },
            { label: 'Denied', value: 'Denied' },
            { label: 'Accepted', value: 'Accepted' },
            { label: 'Rejected', value: 'Rejected' }
        ];
    }

    get quoteStatusBadgeClass() {
        const map = {
            'Draft': 'cpq-status-badge-pill cpq-status-draft',
            'In Review': 'cpq-status-badge-pill cpq-status-inreview',
            'Presented': 'cpq-status-badge-pill cpq-status-presented',
            'Approved': 'cpq-status-badge-pill cpq-status-approved-badge',
            'Denied': 'cpq-status-badge-pill cpq-status-denied',
            'Accepted': 'cpq-status-badge-pill cpq-status-accepted',
            'Rejected': 'cpq-status-badge-pill cpq-status-rejected'
        };
        return map[this.quoteStatus] || 'cpq-status-badge-pill cpq-status-draft';
    }

    get isStatusInReview() { return this.quoteStatus === 'In Review'; }
    get isStatusApproved() { return this.quoteStatus === 'Approved'; }

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

    get lbl() { return LABELS[this.currentLang]; }
    get labelsConfig() { return LABELS; }

    get langToggleLabel() { return this.currentLang === 'en' ? 'FR' : 'EN'; }

    get userInitials() {
        const name = this.selectedAccount && this.selectedAccount.name ? this.selectedAccount.name : '';
        return name.split(' ').filter(Boolean).map(w => w[0]).join('').substring(0, 2).toUpperCase() || 'U';
    }

    get selectedAccountName() {
        return this.selectedAccount && this.selectedAccount.name ? this.selectedAccount.name : '';
    }

    get quoteStatusOptionsI18n() {
        if (this.currentLang === 'fr') {
            return [
                { label: 'Brouillon', value: 'Draft' },
                { label: "En cours d'examen", value: 'In Review' },
                { label: 'Présenté', value: 'Presented' },
                { label: 'Approuvé', value: 'Approved' },
                { label: 'Refusé', value: 'Denied' },
                { label: 'Accepté', value: 'Accepted' },
                { label: 'Rejeté', value: 'Rejected' }
            ];
        }
        return this.quoteStatusOptions;
    }

    get orderStatusOptionsI18n() {
        if (this.currentLang === 'fr') {
            return [
                { label: 'Brouillon', value: 'Draft' },
                { label: 'Activée', value: 'Activated' }
            ];
        }
        return this.orderStatusOptions;
    }

    get currencyOptionsI18n() {
        if (this.currentLang === 'fr') {
            return [
                { label: 'MAD - Dirham marocain', value: 'MAD' },
                { label: 'EUR - Euro', value: 'EUR' },
                { label: 'USD - Dollar américain', value: 'USD' }
            ];
        }
        return this.currencyOptions;
    }

    get countryOptionsI18n() {
        if (this.currentLang === 'fr') {
            return [
                { label: 'Maroc', value: 'Morocco' },
                { label: 'France', value: 'France' },
                { label: 'Allemagne', value: 'Germany' },
                { label: 'États-Unis', value: 'USA' },
                { label: 'Espagne', value: 'Spain' }
            ];
        }
        return this.countryOptions;
    }

    get isIndividual() { return this.customerType === 'Individual'; }
    get isCompany() { return this.customerType === 'Company'; }
    get isNewWorkflow() { return this.quoteWorkflow === 'New'; }
    get isExistingWorkflow() { return this.quoteWorkflow === 'Existing'; }
    get isOppDropdownDisabled() { return this.showNewOppForm; }
    @track accounts = []; // Liste des comptes trouvés lors de la recherche
    @track opportunityOptions = []; // Options formatées pour le menu déroulant des opportunités
    @track selectedOpportunityId = null; // Identifiant de l'opportunité choisie
    @track showNewOppForm = false;
    @track newOppName = '';
    @track newOppCloseDate = '';
    @track newOppCurrency = 'MAD';

    @track quoteSearchTerm = ''; // Terme saisi pour rechercher un devis existant
    @track searchedQuotes = []; // Liste des devis correspondants à la recherche
    @track recentQuotes = []; // Liste des derniers devis consultés

    @track productSearchQuery = ''; // Terme saisi pour filtrer les produits et bundles dans le catalogue
    @track allProducts = []; // Liste des produits simples disponibles (filtrés par devise)
    @track bundles = []; // Liste des bundles disponibles (filtrés par devise)
    @track canvasItems = []; // Éléments actuellement présents sur l'espace de travail (canvas)

    @track showBundleConfigModal = false; // Booléen pour afficher/masquer la fenêtre de configuration de bundle
    @track modalFeatures = []; // Liste des caractéristiques du bundle en cours de configuration
    @track modalBanner = []; // Éléments de résumé de validation pour l'en-tête de la modal
    @track modalBundleName = ''; // Nom du bundle dans la modal
    @track modalBundleCode = ''; // Code produit du bundle dans la modal
    @track modalBundleId = ''; // Identifiant technique du bundle dans la modal
    @track modalConfigTotal = 0; // Total dynamique du bundle selon les options choisies
    @track modalIsValid = false; // Statut de validation de la configuration (respect des min/max)

    _exclusionMap = {}; // Carte interne des règles d'exclusion entre produits
    _dependencyMap = {}; // Carte interne des règles de dépendance (nécessite un autre produit)
    _reconfiguringUid = null; // UID de l'item en cours de modification sur le canvas
    _allProductsRaw = null; // Cache des produits bruts reçus de Salesforce
    _allBundlesRaw = null; // Cache des bundles bruts reçus de Salesforce
    _opportunitiesFull = []; // Données complètes des opportunités (incluant la devise)

    @track subtotalPrice = 0; // Montant total avant remises
    @track netPrice = 0; // Montant total après remises (prix final)
    @track totalDiscountAmount = 0; // Montant total des économies réalisées
    @track hasDiscounts = false; // Booléen pour afficher les badges de remise
    @track discountBreakdown = ''; // Texte explicatif des remises appliquées (provient du QCP)
    @track hasCpqLines = false; // Indique si le canvas contient des lignes déjà sauvegardées en base

    @track isLoading = false; // État de chargement pour afficher le spinner
    @track errorMessage = ''; // Message d'erreur à afficher dans l'UI
    @track successMessage = ''; // Message de succès à afficher dans l'UI
    @track hasGeneratedDoc = false; // true after Generate Document succeeds — enables Send for Signature

    /* ═══════════════ GETTERS ═══════════════ */ // Section des propriétés calculées
    get filteredProducts() { // Filtre local des produits selon la recherche utilisateur
        const term = (this.productSearchQuery || '').toLowerCase(); // Normalise le terme en minuscules
        if (!term) return this.allProducts; // Retourne tout si pas de recherche
        return this.allProducts.filter(p => // Filtre sur le nom, le code ou la famille
            p.name.toLowerCase().includes(term) ||
            (p.productCode || '').toLowerCase().includes(term) ||
            (p.family || '').toLowerCase().includes(term));
    }

    get filteredBundles() { // Filtre local des bundles selon la recherche utilisateur
        const term = (this.productSearchQuery || '').toLowerCase(); // Normalise le terme
        if (!term) return this.bundles; // Retourne tout si pas de recherche
        return this.bundles.filter(b => // Filtre sur le nom, le code ou la description
            b.name.toLowerCase().includes(term) ||
            (b.productCode || '').toLowerCase().includes(term) ||
            (b.description || '').toLowerCase().includes(term));
    }

    get isConfigInvalid() { return !this.modalIsValid; } // Raccourci pour désactiver le bouton de sauvegarde modal
    get isAddToQuoteDisabled() { return this.isLoading || !this.canvasItems.length; } // Désactive l'ajout si chargement ou canvas vide
    get isCalculateDiscountsDisabled() { return this.isLoading || !this.canvasItems.length || !this.quoteId; } // Désactive le calcul si conditions non remplies

    /* ═══════════════ LIFECYCLE ═══════════════ */ // Événements du cycle de vie du composant
    connectedCallback() { // Appelé à l'insertion du composant dans le DOM
        this._loadCatalog(); // Charge le catalogue initial
        this._loadRecentQuotes(); // Charge les derniers devis créés
        getNexaLinkTemplateId()
            .then(id => { this.nexaLinkTemplateId = id; })
            .catch(() => { this.nexaLinkTemplateId = null; });
    }

    _loadRecentQuotes() { // Récupère les devis récents via Apex
        getRecentQuotes()
            .then(r => { this.recentQuotes = r || []; }) // Stocke les résultats
            .catch(e => console.error('Recent quotes error', e)); // Log d'erreur
    }

    _loadCatalog() { // Charge les produits et bundles depuis Salesforce
        this.isLoading = true; // Affiche le spinner
        const cur = this.selectedCurrency || 'MAD'; // Utilise la devise sélectionnée
        const term = this.productSearchQuery || ''; // Terme de recherche
        Promise.all([ // Exécute les deux recherches en parallèle
            getProducts({ searchTerm: term, currencyCode: cur }),
            getBundles({ searchTerm: term, currencyCode: cur })
        ]).then(([prods, bunds]) => {
            this._allProductsRaw = (prods || []).map(p => ({ // Formate les produits pour le canvas
                id: p.productCode || p.id,
                productId: p.id,
                name: p.name,
                nameEn: p.nameEn || p.name,
                nameFr: p.nameFr || '',
                productCode: p.productCode || p.id,
                family: p.family || '',
                chargeType: p.type || 'One-Time',
                unitPrice: parseFloat(p.price || 0)
            }));
            this._allBundlesRaw = (bunds || []).map(b => ({ // Formate les bundles pour le catalogue
                id: b.id,
                productId: b.id,
                productCode: b.productCode || b.id,
                name: b.name,
                nameEn: b.nameEn || b.name,
                nameFr: b.nameFr || '',
                description: b.description || '',
                descriptionEn: b.descriptionEn || b.description || '',
                descriptionFr: b.descriptionFr || '',
                basePrice: parseFloat(b.price || 0).toFixed(2),
                bundleProducts: b.bundleProducts
            }));
            this._applyLanguageToProducts(); // Applique la langue active et met à jour les listes
            this._refreshPrices(); // Met à jour les prix sur le canvas si nécessaire
            this.isLoading = false; // Masque le spinner
        }).catch(e => this._handleError('Failed to load catalog', e)); // Gère les erreurs
    }

    handleToggleLanguage() {
        this.currentLang = this.currentLang === 'en' ? 'fr' : 'en';
        this._applyLanguageToProducts();
    }

    _applyLanguageToProducts() { // Remet à jour les noms selon la langue active
        const isFr = this.currentLang === 'fr';
        this.allProducts = (this._allProductsRaw || []).map(p => ({
            ...p,
            name: isFr && p.nameFr ? p.nameFr : p.nameEn
        }));
        this.bundles = (this._allBundlesRaw || []).map(b => ({
            ...b,
            name: isFr && b.nameFr ? b.nameFr : b.nameEn,
            description: isFr && b.descriptionFr ? b.descriptionFr : b.descriptionEn
        }));
    }

    _refreshPrices() { // Synchronise les prix du canvas avec les données fraîches du catalogue
        if (!this._allProductsRaw) return; // Sécurité si pas de données
        this._applyLanguageToProducts(); // Met à jour les listes avec la langue active

        if (this.canvasItems && this.canvasItems.length) { // Si des items sont sur le canvas
            const productPriceById = {}; // Crée un dictionnaire de prix par ID produit
            (this.allProducts || []).forEach(p => { productPriceById[p.productId] = p.unitPrice; });
            this.canvasItems = this.canvasItems.map(item => { // Parcourt les items du canvas
                if (item.family === 'Bundles') return item; // Les bundles gèrent leurs propres prix complexes
                const newPrice = productPriceById[item.productId] !== undefined
                    ? productPriceById[item.productId]
                    : item.unitPrice; // Trouve le nouveau prix ou garde l'ancien
                const newTotal = parseFloat((newPrice * (item.quantity || 1)).toFixed(2)); // Calcule le nouveau total de ligne
                return { ...item, unitPrice: newPrice, lineTotal: newTotal.toFixed(2) }; // Retourne l'item mis à jour
            });
            this._recalcTotals(); // Recalcule les totaux globaux du canvas
        }
    }

    /* ═══════════════ ACCOUNT / OPPORTUNITY ═══════════════ */ // Gestion de la sélection du client
    handleAccountSearch(event) { // Déclenché à chaque frappe dans le champ recherche compte
        this.accountSearch = event.target.value; // Récupère la saisie
        if (this.accountSearch.length >= 2) { // Démarre la recherche à partir de 2 caractères
            this.isLoading = true; // Affiche le spinner
            getAccounts({ searchTerm: this.accountSearch })
                .then(r => { this.accounts = r || []; this.isLoading = false; }) // Stocke les comptes trouvés
                .catch(e => this._handleError('Account search failed', e)); // Gère l'erreur
        } else { this.accounts = []; } // Vide la liste si saisie trop courte
    }

    handleAccountSelect(event) { // Déclenché au clic sur un compte dans les résultats
        const accountId = event.currentTarget.dataset.id; // ID du compte
        const accountName = event.currentTarget.dataset.name; // Nom du compte
        const accountCountry = event.currentTarget.dataset.country; // Pays du compte
        this.selectedAccount = { id: accountId, name: accountName, country: accountCountry }; // Enregistre la sélection
        this.accountSearch = ''; // Vide le champ recherche
        this.accounts = []; // Vide la liste de résultats
        this.isLoading = true; // Affiche le spinner
        getOpportunities({ accountId }) // Charge les opportunités du compte choisi
            .then(r => {
                if (r && r.length > 0) {
                    this._opportunitiesFull = r; // Stocke les données complètes
                    this.opportunityOptions = r.map(o => ({ label: o.name, value: o.id })); // Prépare les options UI
                    this.selectedCurrency = r[0].currency || 'MAD'; // Par défaut, prend la devise de la 1ère opportunité
                } else {
                    this._opportunitiesFull = []; // Réinitialise si vide
                    this.opportunityOptions = [];
                    this.selectedCurrency = 'MAD';
                }
                this._loadCatalog(); // Recharge le catalogue avec la devise du client
                this.isLoading = false; // Masque le spinner
            })
            .catch(e => this._handleError('Failed to load opportunities', e)); // Gère l'erreur
    }

    handleClearAccount() { // Réinitialise la sélection du client
        this.selectedAccount = null;
        this.selectedOpportunityId = null;
        this.opportunityOptions = [];
    }

    handleOpportunitySelect(event) { // Déclenché au changement d'opportunité
        const oppId = event.target.value; // ID sélectionné
        this.selectedOpportunityId = oppId;
        const opp = (this._opportunitiesFull || []).find(o => o.id === oppId); // Trouve l'objet complet
        if (opp && opp.currency && opp.currency !== this.selectedCurrency) { // Si la devise change
            this.selectedCurrency = opp.currency; // Met à jour la devise
            this._loadCatalog(); // Recharge les prix catalogue
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
        const field = event.target.name;
        const value = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this[field] = value;
    }

    handleCreateOppAndQuote() {
        if (!this.selectedAccount || !this.selectedAccount.id) {
            this._toast('Error', 'Select an account first', 'error');
            return;
        }
        if (!this.newOppName) {
            this._toast('Error', this.lbl.newOppNameLabel + ' is required', 'error');
            return;
        }
        if (!this.newOppCloseDate) {
            this._toast('Error', this.lbl.newOppCloseDateLabel + ' is required', 'error');
            return;
        }
        this.isLoading = true;
        const currency = this.newOppCurrency || this.selectedCurrency || 'MAD';
        createOpportunityForAccount({
            accountId: this.selectedAccount.id,
            oppName: this.newOppName,
            closeDate: this.newOppCloseDate,
            currencyCode: currency
        })
            .then(oppResult => {
                this.selectedOpportunityId = oppResult.id;
                this.selectedCurrency = currency;
                return createQuote({
                    accountId: this.selectedAccount.id,
                    opportunityId: oppResult.id,
                    currencyCode: currency
                });
            })
            .then(quoteResult => {
                this.quoteId = quoteResult.id;
                this.quoteName = quoteResult.name;
                this.quoteStatus = 'Draft';
                this.isStatusChanged = false;
                this.showNewQuoteModal = false;
                this.showNewOppForm = false;
                this.newOppName = '';
                this.newOppCloseDate = '';
                this.isLoading = false;
                this._toast('Success', `Quote ${quoteResult.name} generated successfully!`, 'success');
                this._loadRecentQuotes();
                this._loadCatalog();
            })
            .catch(e => this._handleError('Failed to create opportunity and quote', e));
    }

    handleDashboardQuoteSelect(event) {
        this.quoteId = event.detail.id;
        this.quoteName = event.detail.name;
        this.selectedAccount = { id: '', name: event.detail.account };
        this.selectedCurrency = event.detail.currency;
        this._loadQuoteHeader();
        this._loadQuoteLines();
    }

    _loadQuoteHeader() {
        if (!this.quoteId) return;
        getQuoteHeader({ quoteId: this.quoteId })
            .then(header => {
                this.quoteStatus = header.status;
                this.isStatusChanged = false;
                this.selectedCurrency = header.currency;
                // Store accountId and opportunityId so operations like "create new opp" work
                // even when the quote was loaded from the dashboard (not from account search)
                this.selectedAccount = {
                    id:   header.accountId   || '',
                    name: header.accountName || ''
                };
                if (header.opportunityId) {
                    this.selectedOpportunityId = header.opportunityId;
                }
            })
            .catch(err => console.error('Error loading quote header', err));
    }

    _loadQuoteLines() {
        if (!this.quoteId) return;
        getQuoteLines({ quoteId: this.quoteId })
            .then(lines => {
                this.canvasItems = (lines || []).map((l, idx) => ({
                    ...l,
                    uid: this._uid(),
                    style: `left:${100 + (idx % 3) * 230}px;top:${100 + Math.floor(idx / 3) * 230}px;`
                }));
                this._recalcTotals();
                this.hasCpqLines = this.canvasItems.length > 0;
            })
            .catch(e => this._handleError('Failed to load quote lines', e));
    }

    // --- NEW QUOTE MODAL HANDLERS ---
    handleOpenNewQuoteModal() {
        this.showNewQuoteModal = true;
    }

    handleCloseNewQuoteModal() {
        this.showNewQuoteModal = false;
    }

    handleNewQuoteCreated(event) {
        this.quoteId = event.detail.id;
        this.quoteName = event.detail.name;
        this.quoteStatus = 'Draft';
        this.isStatusChanged = false;
        this.selectedAccount = {
            id: '', 
            name: event.detail.accountName
        };
        this.selectedCurrency = event.detail.currency;
        this.showNewQuoteModal = false;
        this._toast('Success', `Quote ${this.quoteName} generated successfully!`, 'success');
        
        this._loadQuoteHeader();
        this._loadQuoteLines();
        this._loadCatalog();
    }

    /* ═══════════════ SEARCH ═══════════════ */ // Gestion de la recherche de produits
    _searchTimeout; // Timer pour le délai de recherche (debouncing)
    handleProductSearchChange(event) { // Déclenché à la saisie dans le catalogue
        this.productSearchQuery = event.target.value; // Récupère le terme
        window.clearTimeout(this._searchTimeout); // Annule le timer précédent
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimeout = window.setTimeout(() => { this._loadCatalog(); }, 400); // Lance la recherche après 400ms d'inactivité
    }
    handleBundleSearchChange(event) { this.handleProductSearchChange(event); } // Même logique pour les bundles

    /* ═══════════════ CANVAS ═══════════════ */ // Gestion de l'espace de travail interactif
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
    }

    handleCanvasDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
        event.currentTarget.classList.add('cpq-canvas-dragover');
    }

    handleCanvasDragLeave(event) {
        event.currentTarget.classList.remove('cpq-canvas-dragover');
    }

    handleCanvasDrop(event) {
        event.preventDefault();
        event.currentTarget.classList.remove('cpq-canvas-dragover');
        const raw = event.dataTransfer.getData('text/plain');
        if (!raw) return;

        let drop;
        try {
            drop = JSON.parse(raw);
        } catch (e) {
            return;
        }

        const rect = event.currentTarget.getBoundingClientRect();
        const style = `left:${event.clientX - rect.left}px;top:${event.clientY - rect.top}px;`;

        this.handleCanvasDropEvent({
            detail: { dropData: drop, style: style }
        });
    }

    handleCanvasItemMouseDown(event) {
        const item = event.currentTarget;
        const sx = event.clientX - item.offsetLeft;
        const sy = event.clientY - item.offsetTop;
        const mv = e => {
            item.style.left = (e.clientX - sx) + 'px';
            item.style.top = (e.clientY - sy) + 'px';
            // Update coordinates in the local array to persist coordinates
            const uid = item.dataset.uid;
            this.canvasItems = this.canvasItems.map(i => {
                if (i.uid === uid) {
                    return { ...i, style: `left:${item.style.left};top:${item.style.top};` };
                }
                return i;
            });
        };
        const up = () => {
            document.removeEventListener('mousemove', mv);
            document.removeEventListener('mouseup', up);
        };
        document.addEventListener('mousemove', mv);
        document.addEventListener('mouseup', up);
    }

    handleQuantityChange(event) {
        const uid = event.currentTarget.dataset.uid;
        const qty = Math.max(1, parseInt(event.currentTarget.value, 10) || 1);
        this.handleCanvasQuantityChange({
            detail: { uid, qty }
        });
    }

    handleCanvasItemRemove(event) {
        const uid = event.currentTarget.dataset.uid;
        this.handleCanvasItemRemoveEvent({
            detail: { uid }
        });
    }

    handleQuickAddProduct(event) {
        const btn = event.currentTarget;
        this.handleCatalogQuickAddProduct({
            detail: {
                id: btn.dataset.id,
                productId: btn.dataset.productid,
                name: btn.dataset.name,
                price: btn.dataset.price,
                code: btn.dataset.code,
                family: btn.dataset.family,
                charge: btn.dataset.charge
            }
        });
    }

    handleCatalogQuickAddProduct(event) {
        const detail = event.detail;
        const newItem = {
            uid: this._uid(), 
            id: detail.id, 
            productId: detail.productId,
            name: detail.name, 
            productCode: detail.code,
            family: detail.family, 
            chargeType: detail.charge,
            unitPrice: parseFloat(detail.price || 0), 
            quantity: 1,
            style: `left:${50 + Math.random() * 200}px;top:${50 + Math.random() * 200}px;`
        };
        this._pushToCanvas(newItem);
    }

    handleCatalogSelectBundle(event) {
        this._reconfiguringUid = null;
        this._openConfigurator(event.detail.id, event.detail.name);
    }

    _pushToCanvas(p) { // Fonction utilitaire pour ajouter un item à la liste locale
        p.lineTotal = (p.unitPrice * (p.quantity || 1)).toFixed(2); // Calcule le total de la ligne
        this.canvasItems = [...this.canvasItems, p]; // Ajoute à la liste réactive
        this._recalcTotals(); // Recalcule les totaux UI
    }

    handleCanvasDropEvent(event) {
        const { dropData, style } = event.detail;
        if (dropData.type === 'product') {
            const newItem = {
                uid: this._uid(), id: dropData.id, productId: dropData.productId,
                name: dropData.name, productCode: dropData.code,
                family: dropData.family, chargeType: dropData.charge,
                unitPrice: parseFloat(dropData.price || 0), quantity: 1, style
            };
            this._pushToCanvas(newItem);
        } else if (dropData.type === 'bundle') {
            this._openConfigurator(dropData.id, dropData.name);
        }
    }

    _apiAddProducts(products) { // Synchronise les produits du canvas vers Salesforce QuoteLines
        const clean = (products || []) // Prépare les données pour Apex
            .filter(p => p && p.productId)
            .map(p => ({
                productId: p.productId,
                quantity: p.quantity || 1,
                manualDiscount: p.manualDiscount || 0,
                bundleProducts: p.bundleProducts || p.options || []
            }));
        if (clean.length === 0) { // Sécurité
            this._toast('Error', 'No valid products to add (missing productId)', 'error');
            return;
        }
        this.isLoading = true; // Affiche le spinner
        syncProductsToQuote({ // Appel Apex
            quoteId: this.quoteId,
            productsJson: JSON.stringify(clean)
        })
            .then(r => {
                if (r && r.success) {
                    this._processCalculationResults(r); // Traite les prix calculés par CPQ
                    this.successMessage = 'Synced & Calculated'; // Succès
                } else {
                    this._handleError('API Sync Failed', (r && r.error) || 'Unknown error'); // Erreur serveur
                }
            })
            .catch(e => this._handleError('API Error', e)); // Erreur réseau/Apex
    }

    handleCanvasManualDiscountChange(event) {
        const { uid, disc } = event.detail;
        this.canvasItems = this.canvasItems.map(i => {
            if (i.uid !== uid) return i;
            const newTotal = ((i.unitPrice - disc) * (i.quantity || 1)).toFixed(2);
            return { ...i, manualDiscount: disc, lineTotal: newTotal };
        });
        this._recalcTotals();
    }

    handleManualDiscountChange(event) {
        const uid = event.target.dataset.uid;
        const disc = parseFloat(event.target.value) || 0;
        this.canvasItems = this.canvasItems.map(i => {
            if (i.uid !== uid) return i;
            const newTotal = ((i.unitPrice - disc) * (i.quantity || 1)).toFixed(2);
            return { ...i, manualDiscount: disc, lineTotal: newTotal };
        });
        this._recalcTotals();
    }

    handleCanvasQuantityChange(event) {
        const { uid, qty } = event.detail;
        this.canvasItems = this.canvasItems.map(i => {
            if (i.uid !== uid) return i;
            let updatedBundleProducts = i.bundleProducts;
            if (i.bundleProducts) {
                updatedBundleProducts = i.bundleProducts.map(bp => ({ ...bp, quantity: qty }));
            }
            const disc = parseFloat(i.manualDiscount) || 0;
            const newTotal = ((i.unitPrice - disc) * qty).toFixed(2);
            return { ...i, quantity: qty, lineTotal: newTotal, bundleProducts: updatedBundleProducts };
        });
        this._recalcTotals();
    }

    handleCanvasItemRemoveEvent(event) {
        this.canvasItems = this.canvasItems.filter(i => i.uid !== event.detail.uid);
        this._recalcTotals();
    }

    handleCanvasModifyBundle(event) {
        const fakeEvent = { currentTarget: { dataset: { uid: event.detail.uid } } };
        this.handleModifyBundle(fakeEvent);
    }

    /* ═══════════════ BUNDLE CONFIGURATOR ═══════════════ */ // Logique complexe de configuration de bundle
    handleSelectBundle(event) { // Ouvre la modal pour un nouveau bundle
        this._reconfiguringUid = null; // Pas de ré-édition
        this._openConfigurator(event.currentTarget.dataset.id, event.currentTarget.dataset.name);
    }

    handleConfigureBundle(event) {
        const uid = event.currentTarget.dataset.uid;
        const bundle = this.canvasItems.find(i => i.uid === uid);
        if (!bundle) return;
        
        this._reconfiguringUid = uid;
        
        const prevSelected = new Set(
            (bundle.bundleProducts || [])
                .filter(bp => bp.selected !== false)
                .map(bp => bp.productCode)
        );

        this._openConfigurator(bundle.productCode || bundle.id, bundle.name, Array.from(prevSelected));
    }

    handleModifyBundle(event) {
        this.handleConfigureBundle(event);
    }

    handleCloseBundleModal() {
        this.showBundleConfigModal = false;
        this._reconfiguringUid = null;
    }

    _openConfigurator(bundleCode, bundleName, prevSelected = []) {
        this.isLoading = true;
        getBundleWithFeatures({ bundleCode, currencyCode: this.selectedCurrency })
            .then(raw => {
                if (!raw || raw.error) {
                    this._handleError('Bundle load error', (raw && raw.error) || 'Unknown error');
                    return;
                }
                this.showBundleConfigModal = true;
                this.isLoading = false;
                
                // Wait for the modal to render in DOM
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    const configurator = this.template.querySelector('c-cpq-bundle-configurator');
                    if (configurator) {
                        configurator.openConfigurator(raw, prevSelected);
                    }
                }, 50);
            })
            .catch(e => this._handleError('Failed to load bundle', e));
    }

    handleSaveBundleConfigEvent(event) {
        const bundleItem = event.detail;
        
        bundleItem.uid = this._reconfiguringUid || this._uid();
        bundleItem.style = `left:${80 + Math.random() * 160}px;top:${60 + Math.random() * 120}px;`;

        if (this._reconfiguringUid) {
            const existing = this.canvasItems.find(i => i.uid === this._reconfiguringUid);
            if (existing) bundleItem.style = existing.style;
            this.canvasItems = this.canvasItems.map(i => i.uid === this._reconfiguringUid ? bundleItem : i);
            this.successMessage = `${bundleItem.name} updated!`;
        } else {
            this.canvasItems = [...this.canvasItems, bundleItem];
            this.successMessage = `${bundleItem.name} added!`;
        }

        this._recalcTotals();
        
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.successMessage = ''; }, 3000);
        this.handleCloseBundleModal();
    }

    handleChildToast(event) {
        this._toast(event.detail.title, event.detail.message, event.detail.variant);
    }

    handleClearCanvas() { // Vide tout le canvas après confirmation
        if (confirm('Are you sure you want to clear all items from the canvas?')) {
            this.canvasItems = [];
            this._recalcTotals();
            this.hasCpqLines = false;
        }
    }

    /* ═══════════════ QUOTE — Add + Calculate ═══════════════ */ // Actions sur le devis réel
    handleAddToQuote() { // Envoie tout le canvas vers le devis Salesforce (Écrase l'existant)
        if (!this.canvasItems.length) { this._toast('Error', 'Add products first', 'error'); return; }
        if (!this.quoteId) { this._toast('Error', 'Create a quote first', 'error'); return; }

        this.isLoading = true;

        const bundles = this.canvasItems.filter(i => i.family === 'Bundles' && i.bundleProducts && i.bundleProducts.length);
        const standalones = this.canvasItems.filter(i => !(i.family === 'Bundles' && i.bundleProducts && i.bundleProducts.length));

        const standaloneMap = new Map();
        standalones.forEach(i => {
            const key = i.productId || i.id;
            if (!key) return;
            if (standaloneMap.has(key)) {
                standaloneMap.get(key).quantity += (i.quantity || 1);
                if (i.manualDiscount) standaloneMap.get(key).manualDiscount = i.manualDiscount;
            } else {
                standaloneMap.set(key, { productId: key, quantity: i.quantity || 1, manualDiscount: i.manualDiscount || 0 });
            }
        });

        const bundleMap = new Map();
        bundles.forEach(item => {
            const key = item.bundleSfId || item.productId || item.id;
            if (!key) return;
            bundleMap.set(key, {
                productId: key,
                quantity: item.quantity || 1,
                manualDiscount: item.manualDiscount || 0,
                options: (item.bundleProducts || [])
                    .filter(bp => bp.selected !== false)
                    .map(bp => ({
                        productId: bp.productId || bp.id,
                        optionId: bp.optionId,
                        quantity: bp.quantity || 1,
                        isBundled: !!bp.isBundled
                    }))
            });
        });

        clearAndAddAllBundles({
            quoteId: this.quoteId,
            bundlesJson: JSON.stringify(Array.from(bundleMap.values())),
            standaloneJson: standaloneMap.size > 0 ? JSON.stringify(Array.from(standaloneMap.values())) : null
        })
            .then(r => {
                if (r && r.success === false) { this._handleError('Add to Quote failed', r.error); return; }
                const missing = (r && r.missingPbe) || [];
                if (missing.length > 0) {
                    this.errorMessage = `Warning — no price in ${this.selectedCurrency} for: ${missing.join(', ')}. These were skipped.`;
                    setTimeout(() => { this.errorMessage = ''; }, 8000);
                }
                // clearAndAddAllBundles already runs calculatePricing — use its result directly
                // Do NOT call handleCalculateDiscounts() here — that would delete+reinsert lines a second time
                this._processCalculationResults(r);
                this.hasCpqLines = true;
                this.successMessage = 'Products added and priced!';
                this.isLoading = false;
                setTimeout(() => { this.successMessage = ''; }, 3000);
            })
            .catch(e => {
                this._handleError('Failed to add lines', e);
                this.isLoading = false;
            });
    }

    handleCalculateDiscounts() { // Force le calcul des remises via le moteur CPQ
        if (!this.quoteId) { this._toast('Error', 'Create a quote first', 'error'); return; }
        this.isLoading = true;

        // CRITICAL: We must PUSH the current canvas state to Salesforce BEFORE calculating
        syncProductsToQuote({ // Synchronise avant calcul
            quoteId: this.quoteId,
            productsJson: JSON.stringify(this.canvasItems.map(i => ({
                productId: i.productId,
                quantity: i.quantity,
                manualDiscount: i.manualDiscount || 0,
                bundleProducts: i.bundleProducts || []
            })))
        })
            .then(r => {
                if (r && r.success) {
                    this._processCalculationResults(r); // Applique les résultats
                    // START POLLING: Only if standard CPQ is actively calculating in the background
                    if (r.isCalculating) {
                        this._startPricePolling();
                    } else {
                        this.successMessage = 'Synced & Prices Updated';
                        this.isLoading = false;
                    }
                } else {
                    this._handleError('Calculation Error', (r && r.error) || 'Could not calculate discounts');
                }
            })
            .catch(e => this._handleError('Calculation Failed', e));
    }

    _processCalculationResults(r) { // Traite les données renvoyées par le moteur de prix Apex/CPQ
        if (!r || !r.success) return;

        // 1. Update Header Totals // Met à jour les totaux d'en-tête
        this.subtotalPrice = r.subtotal || 0;
        this.netPrice = r.netTotal || 0;
        this.totalDiscountAmount = r.discount || 0;
        this.discountBreakdown = r.breakdown || '';
        this.hasDiscounts = (this.totalDiscountAmount > 0);

        if (r.highDiscountApproval && !r.discountApproved && this.quoteStatus !== 'In Review' && this.quoteStatus !== 'Pending Approval') {
            this._submitForApproval();
        }

        if (!r.lines) { // Si pas de lignes détaillées, utilise le calcul local
            if (this.subtotalPrice === 0 && this.canvasItems.length > 0) this._recalcTotals();
            return;
        }

        // 2. Identify Parents and Children // Sépare parents et options
        const parentLines = r.lines.filter(l => !l.requiredBy);
        const childLines = r.lines.filter(l => !!l.requiredBy);

        // 3. Map Salesforce Lines to Canvas Cards // Associe les lignes Salesforce aux cartes du canvas
        let newCanvasItems = this.canvasItems.map(item => {
            const line = parentLines.find(l =>
                l.productId === item.productId || (l.productCode === item.productCode || l.id === item.productCode)
            );

            if (line) {
                const unitPrice = parseFloat(item.unitPrice || 0);
                const netPrice = parseFloat(line.unitNetPrice || 0);
                const isDisc = Math.abs(unitPrice - netPrice) > 0.01; // Détecte une remise

                const nestedOptions = (childLines || []) // Reconstruit la liste des options pour l'UI
                    .filter(cl => cl.requiredBy === line.id || cl.requiredBy === line.productId)
                    .map(cl => ({
                        id: cl.productId,
                        productId: cl.productId,
                        productCode: cl.productCode,
                        name: cl.name || cl.productCode,
                        unitPrice: parseFloat(cl.unitPrice || 0).toFixed(2),
                        unitNetPrice: parseFloat(cl.unitNetPrice || 0).toFixed(2),
                        lineTotal: parseFloat(cl.lineTotal || 0).toFixed(2),
                        discountPercent: parseFloat(cl.discountPercent || 0).toFixed(2),
                        isBundled: !!cl.isBundled,
                        optionId: cl.optionId
                    }));

                return { // Retourne l'item enrichi des prix CPQ
                    ...item,
                    unitNetPrice: parseFloat(line.unitNetPrice || 0).toFixed(2),
                    lineTotal: parseFloat(line.lineTotal || 0).toFixed(2),
                    discountAmount: parseFloat(line.discountAmount || 0).toFixed(2),
                    discountPercent: parseFloat(line.discountPercent || 0).toFixed(2),
                    discountReason: line.breakdown || '',
                    isDiscounted: isDisc,
                    bundleProducts: nestedOptions.length > 0 ? nestedOptions : item.bundleProducts
                };
            }
            return item;
        });

        this.canvasItems = newCanvasItems; // Met à jour le canvas
        this.hasCpqLines = true;
        this.isLoading = false;
        setTimeout(() => { this.successMessage = ''; }, 3000);
    }

    _submitForApproval() {
        this.isLoading = true;
        submitHighDiscountForApproval({ 
            quoteId: this.quoteId, 
            comments: 'Discount exceeds 20% — manager approval required.' 
        })
            .then(res => {
                if (res && res.success) {
                    this._toast('Approval Required', 'Discount exceeds 20%. Submitted for Manager Approval.', 'warning');
                    this.quoteStatus = 'In Review';
                    this.successMessage = 'Submitted for Manager Approval';
                    this._loadQuoteHeader();
                } else {
                    this._handleError('Submission Failed', res.message || res.error);
                }
                this.isLoading = false;
            })
            .catch(err => {
                this._handleError('Approval Submission Error', err);
                this.isLoading = false;
            });
    }

    handleGenerateDocument() {
        if (!this.quoteId)     { this._toast('Error', 'Create a quote first', 'error'); return; }
        if (!this.hasCpqLines) { this._toast('Error', 'Add products to the quote first', 'error'); return; }
        this.isLoading = true;
        this.successMessage = this.currentLang === 'fr' ? 'Génération du document...' : 'Generating document...';
        generateDocument({ quoteId: this.quoteId })
            .then(() => {
                this.isLoading = false;
                this.successMessage = '';
                this.hasGeneratedDoc = true;
                // Apex auto-advanced Draft → Presented — sync the UI
                if (this.quoteStatus === 'Draft') this.quoteStatus = 'Presented';
                this._toast(
                    this.currentLang === 'fr' ? 'Succès' : 'Success',
                    this.currentLang === 'fr'
                        ? 'Document généré et sauvegardé dans les Fichiers du devis. Cliquez "Envoyer pour signature" pour l\'envoyer au client.'
                        : 'Document generated and saved in Quote Files. Click "Send for Signature" to send it to the client.',
                    'success'
                );
            })
            .catch(e => {
                this.isLoading = false;
                this._handleError(this.currentLang === 'fr' ? 'Génération échouée' : 'Document generation failed', e);
            });
    }

    handleSendForSignature() {
        if (!this.quoteId) { this._toast('Error', 'Create a quote first', 'error'); return; }
        this.isLoading = true;
        this.successMessage = this.currentLang === 'fr' ? 'Envoi via DocuSign...' : 'Sending via DocuSign...';
        generateAndSendForSignature({ quoteId: this.quoteId })
            .then(() => {
                this.isLoading = false;
                this.successMessage = '';
                this._toast(
                    this.currentLang === 'fr' ? 'Envoyé' : 'Sent',
                    this.currentLang === 'fr'
                        ? 'Le devis a été envoyé au client pour signature via DocuSign.'
                        : 'Quote sent to client for signature via DocuSign.',
                    'success'
                );
            })
            .catch(e => {
                this.isLoading = false;
                this._handleError(this.currentLang === 'fr' ? 'Envoi DocuSign échoué' : 'DocuSign send failed', e);
            });
    }

    handleGeneratePDF() {
        if (!this.quoteId) {
            this._toast('Error', 'Create a quote first', 'error');
            return;
        }
        if (!this.hasCpqLines) {
            this._toast('Error', 'Add products and sync to the quote first', 'error');
            return;
        }
        this.isLoading = true;
        this.successMessage = this.currentLang === 'fr'
            ? 'Génération du PDF et envoi de l\'e-mail en cours...'
            : 'Generating PDF and sending email...';
        generateAndSendEmail({ quoteId: this.quoteId })
            .then(() => {
                this.isLoading = false;
                this.successMessage = '';
                this._toast(
                    this.currentLang === 'fr' ? 'Succès' : 'Success',
                    this.currentLang === 'fr'
                        ? 'E-mail envoyé ! Le PDF est en cours de génération et sera joint automatiquement.'
                        : 'Email sent! The PDF is being generated and will be attached automatically.',
                    'success'
                );
            })
            .catch(e => this._handleError('Email send failed', e));
    }

    /* ═══════════════ UTILITIES ═══════════════ */ // Outils internes
    _recalcTotals() { // Recalcule les totaux locaux du canvas (estimation rapide)
        if (!this.canvasItems || this.canvasItems.length === 0) {
            this.subtotalPrice = 0;
            this.netPrice = 0;
            this.totalDiscountAmount = 0;
            this.hasDiscounts = false;
            return;
        }

        let sub = 0;
        let disc = 0;
        this.canvasItems.forEach(i => {
            const qty = i.quantity || 1;
            const up = parseFloat(i.unitPrice) || 0;
            const md = parseFloat(i.manualDiscount) || 0;
            const cpqDiscAmt = parseFloat(i.discountAmount) || 0;

            sub += up * qty;
            if (cpqDiscAmt > 0) {
                disc += cpqDiscAmt;
            } else if (md > 0) {
                disc += md * qty;
            }
        });

        this.subtotalPrice = parseFloat(sub.toFixed(2));
        this.totalDiscountAmount = parseFloat(disc.toFixed(2));
        this.netPrice = parseFloat((sub - disc).toFixed(2));
        this.hasDiscounts = this.totalDiscountAmount > 0;
    }

    _uid() { return 'uid_' + Math.random().toString(36).substring(2, 11) + Date.now(); } // ID unique

    _pollTimer; // Stocke le timer de polling
    _pollCount = 0; // Compteur de tentatives
    _startPricePolling() { // Démarre la vérification périodique des prix (CPQ Async)
        this._pollCount = 0;
        this.successMessage = 'Calculating final discounts...';
        this._poll();
    }

    _poll() { // Vérifie les prix toutes les 600ms
        if (this._pollCount >= 30) { // S'arrête après 18 secondes (30 * 600ms)
            this.successMessage = 'Synced & Prices Updated';
            this.isLoading = false;
            return;
        }
        this._pollCount++;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._pollTimer = setTimeout(() => {
            calculatePricing({ quoteId: this.quoteId }) // Appel léger pour vérifier les totaux
                .then(r => {
                    if (r && r.success) {
                        this._processCalculationResults(r); // Met à jour l'UI
                        // S'arrête si le calcul est terminé ou une remise est appliquée
                        if (parseFloat(this.totalDiscountAmount) > 0 || this.discountBreakdown || !r.isCalculating) {
                            this.successMessage = 'Prices Updated';
                            this.isLoading = false;
                        } else {
                            this._poll(); // Sinon on continue de vérifier
                        }
                    }
                })
                .catch(() => { this.isLoading = false; });
        }, 600);
    }

    _handleError(title, error) { // Gère et affiche les erreurs
        let msg;
        if (typeof error === 'string') {
            msg = error;
        } else if (error) {
            msg = (error.body && error.body.message)
               || (error.body && error.body.output && error.body.output.errors && error.body.output.errors[0] && error.body.output.errors[0].message)
               || error.message
               || JSON.stringify(error);
        } else {
            msg = 'Unknown error';
        }
        this.errorMessage = `${title}: ${msg}`;
        this.successMessage = ''; // Clear success message on error
        this.isLoading = false;
        setTimeout(() => { this.errorMessage = ''; }, 6000);
    }

    _toast(title, message, variant) { // Affiche un toast
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleGoToQuote() { // Redirige l'utilisateur vers la page standard du devis dans Salesforce
        if (this.quoteId) {
            window.open(`/lightning/r/SBQQ__Quote__c/${this.quoteId}/view`, '_blank');
        }
    }

    handleRefresh() { // Recharge les données du catalogue (prix, stocks, etc.)
        this._loadCatalog();
    }

    /* ══════════════════════════════════════════════════════════
       ORDER & CONTRACT HANDLERS
       ══════════════════════════════════════════════════════════ */

    /**
     * Step 3: handleMarkOrdered
     * Sets SBQQ__Ordered__c = true on Quote.
     * CPQ trigger creates the Order record.
     */
    handleMarkOrdered() {
        if (!this.quoteId) return;
        this.isLoading = true;
        this.successMessage = 'Generating Order in background...';

        markQuoteOrdered({ quoteId: this.quoteId })
            .then(result => {
                this.isOrdered = true;
                if (result.orderId) {
                    this.orderId = result.orderId;
                    this.orderNumber = result.orderNumber;
                    this._toast('Success', `Order ${this.orderNumber} created!`, 'success');
                    this.handleGoToOrderView();
                } else {
                    this.successMessage = 'CPQ is processing the order. This may take a few seconds...';
                    this._pollOrderCreation(0);
                }
            })
            .catch(err => {
                this.isLoading = false;
                this._handleError('Order Error', err);
            });
    }

    /**
     * Polling mechanism for asynchronous CPQ Order creation
     */
    _pollOrderCreation(count) {
        if (count > 10) { // Timeout after ~20 seconds
            this._handleError('Order Timeout', 'Order creation is taking longer than expected. Please check the Quote record in Salesforce.');
            return;
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            getOrdersForQuote({ quoteId: this.quoteId })
                .then(orders => {
                    if (orders && orders.length > 0) {
                        const latestOrder = orders[0];
                        this.orderId = latestOrder.id;
                        this.orderNumber = latestOrder.orderNumber;
                        this.orderStatus = latestOrder.status || 'Draft';
                        this.persistedOrderStatus = latestOrder.status || 'Draft';
                        this._toast('Success', `Order ${this.orderNumber} created!`, 'success');
                        this.handleGoToOrderView();
                    } else {
                        this._pollOrderCreation(count + 1);
                    }
                })
                .catch(err => this._handleError('Polling Error', err));
        }, 2000);
    }

    /**
     * Navigation: handleGoToOrderView
     * Switches LWC to the Order Interface screen.
     */
    handleGoToOrderView() {
        this.showOrderView = true;
        this.successMessage = '';
        this._loadOrderDetails();
    }

    /**
     * Navigation: handleBackToQuote
     * Switches back to the Quote Configurator screen.
     */
    handleBackToQuote() {
        this.showOrderView = false;
        this._loadQuoteLines(); // Refresh lines to sync state
    }

    /**
     * Data Loading: _loadOrderDetails
     * Fetches Order Products and Status.
     */
    _loadOrderDetails() {
        if (!this.orderId) return;
        this.isLoading = true;

        getOrderLines({ orderId: this.orderId })
            .then(lines => {
                this.orderLines = (lines || []).map(l => ({
                    ...l,
                    unitPrice: parseFloat(l.unitPrice || 0).toFixed(2),
                    totalPrice: parseFloat(l.totalPrice || 0).toFixed(2)
                }));
                const total = this.orderLines.reduce((sum, l) => sum + parseFloat(l.totalPrice || 0), 0);
                this.orderTotalAmount = total.toFixed(2);

                // Also load Order Header for Status
                return getOrderHeader({ orderId: this.orderId });
            })
            .then(header => {
                if (header) {
                    this.orderStatus = header.status || 'Draft';
                    this.persistedOrderStatus = header.status || 'Draft';
                    this.orderNumber = header.orderNumber;
                    this.isContracted = header.contracted || false;
                }
                this.isLoading = false;
            })
            .catch(err => this._handleError('Load Order Error', err));
    }

    /**
     * Step 4: handleOrderStatusChange & handleSaveOrderStatus
     * Updates the Order status to 'Activated'.
     */
    handleOrderStatusChange(event) {
        this.orderStatus = event.detail.value;
    }

    handleSaveOrderStatus() {
        if (!this.orderId) return;
        this.isLoading = true;
        updateOrderStatus({ orderId: this.orderId, status: this.orderStatus })
            .then(result => {
                this.persistedOrderStatus = result.status;
                this._toast('Success', `Order Status updated to ${result.status}`, 'success');
                this._loadOrderDetails();
                this.isLoading = false;
            })
            .catch(err => {
                this.isLoading = false;
                this._handleError('Save Status Error', err);
            });
    }

    /**
     * Step 5: handleMarkContracted
     * Sets SBQQ__Contracted__c = true on Order.
     * CPQ trigger creates the Contract record.
     */
    handleMarkContracted() {
        if (!this.orderId) return;
        this.isLoading = true;
        this.successMessage = 'Generating Contract...';

        markOrderContracted({ orderId: this.orderId })
            .then(result => {
                this.isContracted = true;
                this.contractId = result.contractId;
                this.contractNumber = result.contractNumber;
                this.contractStatus = result.contractStatus;
                this._toast('Success', `Contract ${this.contractNumber} created!`, 'success');
                this.successMessage = `Contract ${this.contractNumber} generated successfully.`;
                this.isLoading = false;
            })
            .catch(err => {
                this.isLoading = false;
                this._handleError('Contract Error', err);
            });
    }

    handleGoToOrder() {
        if (this.orderId) {
            window.open(`/lightning/r/Order/${this.orderId}/view`, '_blank');
        }
    }

    handleGoToContract() {
        if (this.contractId) {
            window.open(`/lightning/r/Contract/${this.contractId}/view`, '_blank');
        }
    }

    /**
     * Quote Status Handlers
     */
    handleQuoteStatusChange(event) {
        this.quoteStatus = event.detail.value;
        this.isStatusChanged = true;
    }

    handleSaveQuoteStatus() {
        if (!this.quoteId) return;
        this.isLoading = true;
        updateQuoteStatus({ quoteId: this.quoteId, status: this.quoteStatus })
            .then(result => {
                if (result.success) {
                    this._toast('Success', 'Quote Status updated', 'success');
                    this.isStatusChanged = false;
                    this.isLoading = false;
                } else {
                    this._handleError('Update Error', result.error);
                }
            })
            .catch(err => this._handleError('Save Status Error', err));
    }
} // Fin de la classe CpqConfigurator
