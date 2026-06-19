# 🚕 Le Bon Taxi - Application Utilisateur

Bienvenue dans le dépôt de l'application mobile **Le Bon Taxi (Utilisateurs)**. Cette application permet aux clients de commander un taxi rapidement, de suivre l'arrivée de leur chauffeur en temps réel et de gérer leurs courses.

## ✨ Fonctionnalités Principales

*   **Inscription et Profil** : Création de compte sécurisée via Supabase (email, informations personnelles).
*   **Commande de Taxi** : Choix de la destination, estimation du prix et de la distance.
*   **Suivi en Temps Réel** : Visualisation de la position du chauffeur sur la carte grâce à l'intégration Google Maps.
*   **Historique des Courses** : Accès aux détails des trajets passés.
*   **Notifications & Mises à Jour** : Système d'alerte pour télécharger automatiquement les dernières versions de l'application (APK).

## 🛠️ Technologies Utilisées

*   **Framework** : [Flutter](https://flutter.dev/) (Dart)
*   **Backend & Base de données** : [Supabase](https://supabase.com/) (PostgreSQL, Auth, Storage, Edge Functions)
*   **Cartographie** : Google Maps SDK & Geolocator
*   **Gestion d'état & UI** : Composants Material Design personnalisés

## 🚀 Installation & Démarrage

1. **Prérequis** : Assurez-vous d'avoir installé [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. **Cloner le projet** : (Assurez-vous d'avoir accès au dépôt GitHub)
3. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```
4. **Lancer l'application** :
   ```bash
   flutter run
   ```

## 📦 Générer une version finale (APK)

Pour générer un fichier `.apk` prêt à être distribué aux utilisateurs (ou à ajouter dans le Panel Admin) :
```bash
flutter build apk --release
```
Le fichier généré se trouvera dans `build/app/outputs/flutter-apk/app-release.apk`.

## ⚙️ Configuration Supabase
L'application utilise Supabase. Les clés API et les identifiants de projet doivent être configurés dans le fichier `.env` ou directement à l'initialisation dans `main.dart`.
