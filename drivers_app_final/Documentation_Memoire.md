# Documentation du Projet : Application Chauffeur "Le Bon Taxi"
*Document préparatoire pour la rédaction du Mémoire de Fin d'Études*

## 1. Introduction
Ce document présente l'analyse technique et fonctionnelle de l'application mobile dédiée aux chauffeurs pour le projet "Le Bon Taxi". L'application est conçue pour offrir aux chauffeurs de VTC/Taxi une interface complète pour la gestion de leurs courses, le suivi de leurs revenus et la navigation en temps réel.

## 2. Architecture du Projet
Le projet repose sur une architecture moderne découpée en couches afin de garantir la maintenabilité, l'évolutivité et le fonctionnement "Offline-First".

### 2.1. Frontend (Client Mobile)
Développé avec le framework **Flutter** (Dart), l'application est multiplateforme (iOS & Android). L'interface utilisateur (UI) suit les principes du Material Design avec une gestion intégrée du mode clair/sombre.

* **Couche Présentation (`lib/pages/` & `lib/widgets/`)** : Contient toutes les vues de l'application (Accueil, Tableau de bord, Profil, Paramètres, Historique des courses) et les composants graphiques natifs réutilisables.
* **Gestion des Thèmes (`lib/theme/`)** : Centralise la palette de couleurs et les thèmes structurels.

### 2.2. Backend et Services Cloud
L'application s'appuie sur des solutions de type BaaS (Backend-as-a-Service) et des API tierces robustes :
* **Supabase** : Constitue le cœur du backend. Utilisé pour la base de données relationnelle (PostgreSQL), l'authentification et la synchronisation des données en temps réel.
* **Firebase Cloud Messaging (FCM)** : Dédié exclusivement à l'implémentation et à la gestion des notifications push.
* **OpenStreetMap (OSM) & OSRM** : Utilisés comme alternatives open-source à Google Maps pour réduire les coûts d'interface de programmation liés à l'affichage cartographique et au calcul d'itinéraires.

### 2.3. Accès aux Données et Logique Métier (Services Layer)
* **Dossier `lib/services/`** : Architecture modulaire qui isole la logique métier.
  * *Interactions Cloud* : `supabase_service.dart` (CRUD global) et `google_signin_service.dart` (Authentification SSO).
  * *Stratégie Offline* : `local_database_service.dart` (Base SQLite pour mise en cache) & `sync_service.dart` (Synchronisation des données asynchrones pour opérer sans réseau).
  * *Géolocalisation continue* : `foreground_location_service.dart` (Suivi GPS en premier/arrière-plan).

## 3. Technologies et Stack Technique
* **Framework** : Flutter (SDK >= 3.2.6)
* **API Backend DaaS** : Supabase (`supabase_flutter`)
* **Notifications Push et Locales** : Firebase Core, Firebase Messaging, `flutter_local_notifications`
* **Cartographie & Routage** : `flutter_map`, `latlong2`, `geolocator`, Bibliothèque d'appels `http`
* **Stockage Local** : `sqflite`, `shared_preferences`
* **Sécurité & Authentification** : `local_auth` (FaceID/TouchID biométrique), Google Sign-In
* **Outils d'Exportation** : `pdf` & `printing` (Rapports visuels et analyses financières exportables)

## 4. Dissection des Fonctionnalités Principales
* **Gestion du Cycle de Vie des Courses** : Réception dynamique (`new_trip_page.dart`), acceptation, et navigation en direct pour finaliser le transport des clients.
* **Suivi des Gains et Comptabilité** : Tableaux de bord financiers périodiques (`earnings_page.dart`) permettant au chauffeur d'exporter ses résultats (Rapports PDF via `pdf_report_service.dart`).
* **Messagerie In-App** : Communication en temps réel (Chat) entre le chauffeur et le passager via Supabase Realtime (`chat_page.dart`).
* **Sécurité Personnelle** : Intégration d'un module d'urgence via `emergency_page.dart` (Bouton SOS) reliant directement aux services locaux de sécurité ou au support.
* **Résilience Réseau (Offline-First)** : L'application stocke les trajets et le solde en mode déconnecté. Une fois la connexion récupérée, le système synchronise automatiquement le référentiel avec la base distante.

## 5. Recommandations Pédagogiques pour le Mémoire (Format Word)
Dans la rédaction de votre mémoire ou présentation de soutenance, concentrez-vous sur les angles suivants :
1. **La Problématique "Offline"** : Les chauffeurs VTC sont souvent dans des zones à faible couverture réseau (parkings souterrains, campagnes routières). Montrer que le composant SQLite (`local_database_service.dart`) couplé à la file d'attente système gère intelligemment ce défi réseau majeur est un atout technique fort.
2. **Choix Architecturaux (Spatio-Temporel)** : Pourquoi le choix d'une base relationnelle via Supabase (PostgreSQL) combinée avec Flutter, au lieu des solutions de bases documentaires standard.
3. **Sécurisation par la Biométrie** : Aborder la nécessité métier d'encapsuler les revenus et informations comptables du chauffeur par identification locale stricte (`biometric_service.dart`).
4. **Optimisation des Coûts de Mapping** : Expliquer comment la mise à l'écart des APIs payantes (Google Maps) au profit d'une combinaison astucieuse entre OSM (Layer Map) et OSRM (Algorithme de routage localisé) rend le projet économiquement viable en production.
