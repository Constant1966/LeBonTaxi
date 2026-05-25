# 🚕 Le Bon Taxi - Application Chauffeur

L'application **Le Bon Taxi Chauffeur** est l'outil de travail quotidien conçu pour les conducteurs de la flotte. Elle permet de gérer les demandes de courses, de naviguer efficacement vers les passagers et de suivre ses performances financières en temps réel.

## ✨ Fonctionnalités Principales

*   **Gestion de la Disponibilité** : Basculez facilement entre le mode "En ligne" (prêt à recevoir des courses) et "Hors ligne".
*   **Réception des Courses en Temps Réel** : Recevez des notifications instantanées pour les nouvelles demandes à proximité avec détails du point de départ.
*   **Navigation GPS Intégrée** : Guidage étape par étape vers le client, puis vers la destination finale grâce à l'intégration de Google Maps.
*   **Suivi des Revenus (Portefeuille)** : Consultez vos gains détaillés par course, par jour et votre solde total.
*   **Historique des Activités** : Accès complet à la liste de vos courses passées et des montants perçus.
*   **Gestion du Véhicule** : Mise à jour des informations de votre taxi (modèle, numéro de plaque, photo).
*   **Système de Notation** : Visualisez les avis et les notes laissés par les passagers pour améliorer votre service.

## 🛠️ Stack Technique

*   **Framework** : [Flutter](https://flutter.dev/) (iOS & Android)
*   **Backend** : [Supabase](https://supabase.com/) (Gestion des données, Authentification et Realtime)
*   **Géolocalisation** : 
    *   `geolocator` pour le suivi de la position.
    *   `flutter_polyline_points` pour le tracé des itinéraires.
*   **Cartographie** : [Google Maps SDK](https://developers.google.com/maps)
*   **Localisation en Arrière-plan** : Capacité à suivre la position même lorsque l'application est réduite (essentiel pour le dispatching).

## 🚀 Installation et Configuration

### Prérequis
*   Flutter SDK (dernière version stable)
*   Un projet [Supabase](https://supabase.com/) configuré
*   Clés API Google Cloud (Maps SDK, Directions API)

### Étapes d'installation

1.  **Cloner le dépôt** :
    
