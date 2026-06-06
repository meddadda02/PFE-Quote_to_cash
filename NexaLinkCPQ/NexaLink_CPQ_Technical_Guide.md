# Guide Technique : NexaLink CPQ Visual Configurator

Ce document détaille l'architecture logicielle et les problématiques résolues par l'implémentation du configurateur visuel NexaLink CPQ pour Salesforce.

## 1. Problématique Initiale
Le processus standard de Salesforce CPQ (Configure, Price, Quote) peut s'avérer complexe pour les commerciaux télécoms en raison de :
*   **Complexité des Bundles** : Les offres combinant Mobile, Fibre et Services possèdent des centaines de règles de dépendance et d'exclusion difficiles à visualiser.
*   **Latence de Calcul** : Le moteur de prix standard nécessite souvent plusieurs clics et chargements de page pour afficher le prix final remisé.
*   **Expérience Utilisateur (UX) rigide** : L'éditeur de lignes de devis standard ne permet pas une manipulation fluide et visuelle des produits.

## 2. La Solution NexaLink CPQ
La solution propose un **Configurator Visuel** basé sur un "Canvas" interactif permettant de configurer des offres complexes en glisser-déposer tout en restant synchronisé en temps réel avec le moteur de calcul Salesforce CPQ.

## 3. Rôle des Fichiers du Projet

### A. `CPQConfiguratorController.cls` (Apex Controller)
C'est le **pont entre l'interface LWC et la base de données Salesforce**.
*   **Synchronisation Atomique** : Utilise des `Savepoints` pour garantir que si une erreur survient lors de la création d'un bundle, aucune donnée orpheline n'est créée.
*   **Orchestration CPQ** : Appelle les APIs `SBQQ.ServiceRouter` pour forcer le calcul des prix, l'application des remises (QCP) et la sauvegarde des lignes.
*   **Gestion de la Persistance** : Gère la suppression des anciens états et l'insertion des nouvelles configurations pour éviter les doublons.

### B. `cpqConfigurator.js` (LWC Logic)
C'est l'**orchestrateur de l'expérience utilisateur**.
*   **Gestion du State** : Maintient en mémoire l'état du canvas (positions, quantités, relations parents-enfants).
*   **Logique de Configuration** : Applique localement les règles d'exclusion et de dépendance (Exemple : "Le forfait 5G nécessite l'activation smartphone").
*   **Polling de Prix** : Implémente une boucle de vérification asynchrone (`_startPricePolling`) pour mettre à jour les prix dès que le moteur CPQ a terminé ses calculs en arrière-plan.

### C. `cpqConfigurator.html` (LWC Template)
Définit la **structure visuelle du configurateur**.
*   **Canvas Interactif** : Une zone de travail libre où les produits sont représentés par des cartes mobiles.
*   **Modal de Configuration** : Une interface dédiée à la personnalisation des bundles avec validation en temps réel des règles métiers.
*   **Résumé Dynamique** : Un panneau latéral calculant instantanément le sous-total et les remises estimées.

### D. `cpqConfigurator.css` (Design System)
Implémente l'**identité visuelle NexaLink**.
*   **Esthétique Premium** : Utilisation d'un thème "Dark Navy & Teal" (Bleu marine et Turquoise) pour un aspect professionnel et moderne.
*   **Animations Micro-UX** : Transitions douces lors du glisser-déposer et effets de surbrillance lors de la validation des options.

### E. `TelecomQCP.js` (Salesforce CPQ Script)
Bien que situé dans l'org Salesforce, ce script (Javascript côté serveur) est le **moteur de remise automatique**.
*   Il applique des remises basées sur le volume, le type de client (Etudiant, Employé Telecom) et les promotions saisonnières.

### F. `sfdx-project.json` (Configuration SFDX)
Définit les paramètres du projet Salesforce DX, notamment la version de l'API et le répertoire racine (`force-app`) pour le déploiement des métadonnées.

### G. `package.json` (Gestion des Dépendances)
Contient les scripts NPM pour le développement et liste les bibliothèques nécessaires pour les tests (Jest) et le formatage du code (Prettier).

### H. `DEPLOY.ps1` / `DEPLOY.bat` (Automatisation)
Scripts permettant de déployer en une seule commande l'ensemble du projet vers l'organisation Salesforce cible (`sf project deploy`).

### I. Scripts Apex (`.apex`)
*   **`fixFLS.apex`** / **`fixFLS_all_users.apex`** : Utilitaires pour corriger les permissions (Field Level Security) de manière massive sur tous les profils utilisateurs.
*   **`set_trace.apex`** : Active les journaux de débogage pour l'analyse du QCP.
*   **`update_qcp_codes.apex`** : **Automatisation de l'injection du code QCP**. Ce script est vital car il permet de pousser directement le code JavaScript local vers l'objet Salesforce `SBQQ__CustomScript__c` (TelecomQCP), évitant ainsi les copier-coller manuels dans l'interface Salesforce et garantissant l'intégrité de l'algorithme de calcul.
*   **`touchScript.apex`** : Utilitaire permettant de déclencher manuellement une exécution du moteur de prix pour validation.

### J. `.forceignore`
Indique à Salesforce quels fichiers locaux ne doivent jamais être envoyés vers l'organisation (fichiers de test, documentation locale, etc.).

### K. Métadonnées LWC (`cpqConfigurator.js-meta.xml`)
Définit les cibles d'exposition du composant (Lightning App Page, Record Page) et permet son intégration dans l'App Builder de Salesforce.

### L. Fichiers de Données et Snapshots (`.json`)
*   **`quote_describe.json` / `feature_describe.json`** : Contiennent une structure détaillée des objets Salesforce pour permettre le développement hors-ligne et l'analyse des métadonnées du dictionnaire de données.

### M. Plans de Tests et Guides de Recette (`.md`)
*   **`COMPLETE_TESTING_PLAN.md`** : Protocole complet pour tester chaque fonctionnalité.
*   **`QUICK_TEST_GUIDE.md`** : Version simplifiée pour une vérification rapide.
*   **`DEPLOYMENT_AND_TESTING_GUIDE.md`** : Instructions pas-à-pas pour les administrateurs.
*   **`CHANGES_SUMMARY.md`** : Journal d'audit listant chaque modification technique effectuée durant le projet.
*   **`QUICK_START.md`** : Manuel de prise en main immédiate pour les nouveaux développeurs.

### N. Configuration de l'Environnement de Développement
*   **`.prettierrc` / `.prettierignore`** : Standards de formatage.
*   **`eslint.config.js`** : Analyse statique du code.
*   **`jest.config.js`** : Configuration des tests unitaires LWC.
*   **`config/project-scratch-def.json`** : Fichier de définition pour la création d'environnements de développement isolés (Scratch Orgs).

### O. Autres Scripts Utilitaires
*   **`fix_order_perm.apex`** : Gère spécifiquement les droits d'activation des commandes liées au devis.
*   **`testCalc.apex`** : Script léger pour tester la vitesse de réponse de l'API CPQ.
*   **`makeUpdateApex.js`** : Petit script utilitaire pour générer du code Apex dynamiquement.

## 5. Schéma de Connexion et Flux de Données

Pour que le système fonctionne, les fichiers interagissent selon le cycle suivant :

1.  **Action Utilisateur (UI)** : L'utilisateur manipule un produit sur le **Canvas (HTML/CSS)**.
2.  **Déclenchement (JS)** : Le fichier **`cpqConfigurator.js`** capture l'événement et envoie les données au serveur.
3.  **Traitement Serveur (Apex)** : Le fichier **`CPQConfiguratorController.cls`** reçoit les données, nettoie le devis et prépare les lignes.
4.  **Lien vers le Moteur de Prix (API CPQ)** : L'Apex appelle l'API de Salesforce CPQ qui, à son tour, exécute le script **`TelecomQCP.js`** (dont le code a été synchronisé par **`update_qcp_codes.apex`**).
5.  **Calcul des Remises** : Le script **QCP** applique les règles métier (étudiant, devise, volume) et renvoie les prix nets.
6.  **Mise à jour Visuelle** : L'Apex récupère ces prix et les renvoie au **JS** qui met à jour le canvas en temps réel.

> [!TIP]
> **Réactivité en temps réel** : Grâce à l'utilisation combinée de `update_qcp_codes.apex` et de l'API Quote de CPQ, toute modification apportée aux règles métiers (remises, conditions) dans le code JavaScript du QCP est prise en compte **immédiatement** dès le prochain calcul sur le configurateur, sans nécessiter de rafraîchissement complet ou de nouveau déploiement de métadonnées.

**Cette architecture garantit une connexion permanente entre l'interface visuelle moderne et la puissance de calcul certifiée de Salesforce CPQ.**

| Problème | Solution NexaLink |
| :--- | :--- |
| **Doublons de lignes** | Implémentation d'un "Clean & Sync" dans l'Apex qui vide et recrée l'état exact du canvas à chaque calcul. |
| **Erreurs de Devise (MAD/EUR)** | Force l'application du `CurrencyIsoCode` du devis parent à chaque nouvelle ligne créée via le contrôleur. |
| **Quantités des Bundles** | Synchronisation récursive : changer la quantité du pack parent met à jour automatiquement tous les composants enfants pour déclencher les remises de volume. |
| **Validation complexe** | Système de "Banner de Validation" dans la modal qui explique visuellement à l'utilisateur pourquoi un bundle n'est pas encore prêt à être ajouté. |

---
**Développé dans le cadre du PFE NexaLink - 2026**
