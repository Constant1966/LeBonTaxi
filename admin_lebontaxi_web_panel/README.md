# 💻 Le Bon Taxi - Panel d'Administration Web

Bienvenue dans le dépôt du **Panel d'Administration (Web)** pour Le Bon Taxi. Ce tableau de bord permet aux administrateurs de gérer l'ensemble de la plateforme (clients, chauffeurs, courses, tarifs et paramètres globaux).

## ✨ Fonctionnalités Principales

*   **Gestion des Utilisateurs** : Voir la liste des clients inscrits, bloquer/débloquer des comptes.
*   **Gestion des Chauffeurs** : Validation des documents (permis, photos véhicule), suivi de leur statut d'abonnement.
*   **Suivi des Courses** : Vision globale des trajets en cours, terminés ou annulés.
*   **Tarification et Abonnements** : Modification des prix au kilomètre, définition des forfaits d'abonnement pour les chauffeurs.
*   **Paramètres Généraux** : 
    *   Informations de contact du support (Email, WhatsApp, Téléphone).
    *   **Gestion des Mises à jour (APK)** : Renseignement des numéros de version actuels et liens de téléchargement pour forcer la mise à jour des applications mobiles Utilisateur et Chauffeur.
*   **Sécurité RLS** : Accès strictement réservé aux comptes administrateurs via les Row Level Security (RLS) de Supabase.

## 🛠️ Technologies Utilisées

*   **Framework** : [Flutter Web](https://flutter.dev/multi-platform/web)
*   **Backend & Base de données** : [Supabase](https://supabase.com/)
*   **Design** : Interface web réactive, avec un mode sombre/clair et un système de graphiques statistiques.

## 🚀 Installation & Démarrage

1. **Prérequis** : Assurez-vous d'avoir installé [Flutter SDK](https://docs.flutter.dev/get-started/install) et activé le support web (`flutter config --enable-web`).
2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```
3. **Lancer l'application sur Chrome** :
   ```bash
   flutter run -d chrome
   ```

## 📦 Déploiement

Pour compiler l'application web pour la production (Hébergement Firebase, Vercel, Supabase Hosting ou serveur propre) :
```bash
flutter build web --release
```
Les fichiers statiques seront générés dans le dossier `build/web/`. Il suffit d'héberger le contenu de ce dossier sur n'importe quel serveur web.
