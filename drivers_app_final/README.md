# 🚖 Le Bon Taxi - Application Chauffeur

Bienvenue dans le dépôt de l'application mobile **Le Bon Taxi (Chauffeurs)**. Cette application est dédiée aux partenaires conducteurs souhaitant recevoir des courses et générer des revenus.

## ✨ Fonctionnalités Principales

*   **Inscription & Vérification** : Soumission des documents (permis, assurance, photos du véhicule) directement via l'application.
*   **Réception de Courses** : Alertes en temps réel lorsqu'un client demande une course à proximité.
*   **Navigation Intégrée** : Guidage GPS vers le client et vers la destination finale.
*   **Système d'Abonnement** : Accès à différentes offres d'abonnement pour recevoir plus de courses ou bénéficier de réductions sur la commission.
*   **Gains & Historique** : Suivi des revenus journaliers et hebdomadaires.
*   **Mises à Jour Automatiques** : Système de notification bloquant si une nouvelle version (APK) est disponible sur le serveur.
*   **Sécurité Biomètrique** : Connexion par empreinte digitale ou reconnaissance faciale.

## 🛠️ Technologies Utilisées

*   **Framework** : [Flutter](https://flutter.dev/) (Dart)
*   **Backend & Base de données** : [Supabase](https://supabase.com/) (PostgreSQL, Auth, Storage)
*   **Cartographie** : Google Maps SDK, Geolocator
*   **Paiement** : Intégrations de services tiers (si applicable)

## 🚀 Installation & Démarrage

1. **Prérequis** : Assurez-vous d'avoir installé [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```
3. **Lancer l'application** :
   ```bash
   flutter run
   ```

## 📦 Générer une version finale (APK)

Pour générer l'APK à distribuer aux chauffeurs :
```bash
flutter build apk --release
```
Le fichier généré se trouvera dans `build/app/outputs/flutter-apk/app-release.apk`. Renommez-le et hébergez-le (Drive, Serveur) puis mettez le lien dans le Panel Admin.
