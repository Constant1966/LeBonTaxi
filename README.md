# 🚖 Écosystème Le Bon Taxi

Bienvenue dans le dépôt central de **Le Bon Taxi**, une solution complète de transport à la demande. Ce projet intègre un écosystème complet composé d'une plateforme d'administration web et de deux applications mobiles natives.

## 📂 Structure du Projet

L'écosystème est organisé en trois sous-projets indépendants mais connectés :

### 1. [💻 Panneau d'Administration Web](./admin_lebontaxi_web_panel)
Le centre de commande pour les gestionnaires de la flotte.
- **Rôle** : Monitoring en temps réel, validation des chauffeurs, gestion des tarifs, abonnements et analyse des revenus.
- **Technologies** : Flutter Web, Supabase Realtime, FL Chart.

### 2. [📱 Application Client (User App)](./User_App_Final)
L'interface mobile destinée aux passagers pour commander leurs courses.
- **Rôle** : Recherche de chauffeurs, suivi GPS en direct, calcul automatique des tarifs et gestion des paiements.
- **Technologies** : Flutter (iOS/Android), Google Maps SDK, Supabase Auth.

### 3. [🚕 Application Chauffeur (Driver App)](./Driver_App_final)
L'outil de travail optimisé pour les conducteurs.
- **Rôle** : Réception des demandes, navigation assistée, suivi des gains quotidiens et gestion du statut du véhicule.
- **Technologies** : Flutter, Localisation en arrière-plan, Supabase Database.

---

## ✨ Fonctionnalités Globales

*   **Suivi Temps Réel** : Géolocalisation précise des chauffeurs et des trajets en cours.
*   **Tarification Dynamique** : Système flexible de calcul des prix basé sur la distance et le temps.
*   **Gestion des Abonnements** : Module "Le Bon Taxi Plus" offrant des réductions aux utilisateurs fidèles.
*   **Sécurité & Audit** : Journalisation de toutes les actions administratives et validation rigoureuse des chauffeurs.
*   **Interface Moderne** : Design soigné avec support des modes **Clair** et **Sombre**.

## 🛠️ Stack Technique Commune

*   **Frontend** : Flutter & Dart (Multiplateforme)
*   **Backend** : Supabase (Base de données PostgreSQL, Authentification, Realtime)
*   **Cartographie** : Google Maps API & OpenStreetMap
*   **Gestion d'état** : Provider

## ⚙️ Installation

Chaque application dispose de sa propre documentation d'installation dans son dossier respectif. Globalement :

1. Clonez le dépôt :
   
