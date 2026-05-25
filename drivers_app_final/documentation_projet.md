### **Documentation Complète : Application Chauffeur "LeBonTaxi"**

#### **1. Vue d'ensemble du Projet**

L'application "LeBonTaxi - Chauffeur" est une application mobile développée avec Flutter qui permet aux chauffeurs de s'inscrire, de se connecter, de gérer leur disponibilité et de répondre aux demandes de courses des utilisateurs. Elle s'intègre profondément avec les services Firebase pour l'authentification, la base de données en temps réel et les notifications, ainsi qu'avec l'API Google Maps pour la géolocalisation et les itinéraires.

#### **2. Fonctionnalités Principales**

*   **Authentification du Chauffeur** : Les chauffeurs peuvent créer un compte avec leur e-mail, mot de passe, informations personnelles, et détails du véhicule (modèle, couleur, plaque). Ils peuvent également se connecter à un compte existant.
*   **Gestion du Statut** : Les chauffeurs peuvent se mettre "En Ligne" pour recevoir des demandes de courses ou "Hors Ligne" pour ne plus en recevoir.
*   **Réception des Demandes de Course** : Lorsqu'un utilisateur fait une demande, les chauffeurs disponibles reçoivent une notification push en temps réel avec les détails du point de départ et de la destination.
*   **Acceptation/Refus des Courses** : Un dialogue s'affiche, donnant au chauffeur 20 secondes pour "ACCEPTER" ou "REFUSER" la course.
*   **Navigation en Course** : Une fois la course acceptée, l'application affiche l'itinéraire pour se rendre au point de départ du client, puis l'itinéraire vers la destination finale.
*   **Calcul et Perception du Tarif** : À la fin de la course, le tarif est calculé en fonction de la distance et de la durée. Un dialogue de paiement s'affiche pour que le chauffeur puisse percevoir le montant en espèces.
*   **Historique et Profil** : Le chauffeur peut consulter le nombre total de courses effectuées, voir un historique détaillé, et gérer les informations de son profil.

#### **3. Structure du Projet (Répertoire `lib`)**

*   `main.dart`:
    *   **Rôle** : Point d'entrée de l'application.
    *   **Logique** : Initialise Firebase, gère les demandes de permission (localisation, notifications) et détermine la première page à afficher : `LoginScreen` si l'utilisateur n'est pas connecté, sinon `Dashboard`.

*   `authentication/`:
    *   `login_screen.dart`: Gère la logique de connexion des chauffeurs. Il vérifie les identifiants avec Firebase Auth et s'assure que le compte chauffeur n'est pas bloqué.
    *   `signup_screen.dart`: Gère le processus d'inscription en plusieurs étapes : saisie des informations, choix d'une photo de profil (téléchargée sur Firebase Storage), et enregistrement des données dans Firebase Realtime Database.

*   `pages/`:
    *   `dashboard.dart`: L'écran principal post-connexion. Contient une `BottomNavigationBar` pour naviguer entre les quatre onglets principaux : "Accueil", "Gains", "Courses" et "Profil".
    *   `home_page.dart`: L'onglet "Accueil". Affiche la carte Google, la position actuelle du chauffeur et le bouton principal pour passer "En Ligne" ou "Hors Ligne". C'est ici que l'écoute des nouvelles courses est active.
    *   `trips_page.dart`: L'onglet "Courses". Affiche une carte sommaire avec le nombre total de courses terminées et un bouton pour accéder à l'historique détaillé.
    *   `profile_page.dart`: L'onglet "Profil". Affiche les informations non modifiables du chauffeur (photo, nom, e-mail, voiture) et fournit le bouton de déconnexion.
    *   `earnings_page.dart`: (Onglet "Gains") Destiné à afficher les revenus totaux ou détaillés du chauffeur.
    *   `new_trip_page.dart`: S'affiche après l'acceptation d'une course. Elle guide le chauffeur vers le client, puis vers la destination, en affichant l'itinéraire sur la carte.
    *   `trips_history_page.dart`: Affiche une liste détaillée de toutes les courses passées du chauffeur.

*   `widgets/`:
    *   `loading_dialog.dart`: Un dialogue d'attente réutilisable affiché lors des opérations asynchrones (connexion, inscription).
    *   `notification_dialog.dart`: Le dialogue qui apparaît à la réception d'une demande de course. Il affiche les adresses de départ/arrivée et les boutons "ACCEPTER"/"REFUSER".
    *   `payment_dialog.dart`: S'affiche à la fin d'une course pour indiquer le montant à percevoir en espèces.

*   `models/`:
    *   `trip_details.dart`: Classe modèle qui structure les informations d'une course (ID, adresses, coordonnées, informations de l'utilisateur).
    *   `direction_details.dart`: Classe modèle pour stocker les détails d'un itinéraire retourné par l'API Google Directions (distance, durée, points de la polyligne).

*   `methods/`:
    *   `common_methods.dart`: Contient des fonctions utilitaires cruciales : vérification de la connectivité réseau, affichage de messages (`SnackBar`), calcul du tarif de la course, et l'appel à l'API Google Directions.
    *   `map_theme_methods.dart`: Gère le chargement et l'application d'un style JSON personnalisé (thème sombre) à la carte Google.

*   `global/`:
    *   `global_var.dart`: Fichier central pour les variables globales, comme la clé API Google Maps, les informations du chauffeur connecté après la connexion, et les abonnements aux flux de géolocalisation.

*   `pushNotification/`:
    *   `push_notification_system.dart`: Gère toute la logique des notifications push. Il obtient le jeton de l'appareil via Firebase Cloud Messaging (FCM), s'abonne aux topics et écoute les messages entrants que l'application soit au premier plan, en arrière-plan ou terminée.

#### **4. Flux de Données et Logique d'une Course**

1.  **Mise en Ligne** : Sur `home_page.dart`, le chauffeur appuie sur "ÊTRE EN LIGNE". Sa position est enregistrée dans la base de données sous `onlineDrivers` via **Geofire**, et son statut `newTripStatus` est mis à "waiting".
2.  **Notification** : Un processus externe (l'application utilisateur) crée une nouvelle entrée dans `tripRequests`. Un service cloud (ex: Cloud Function) envoie une notification FCM au topic "drivers".
3.  **Réception** : `push_notification_system.dart` reçoit la notification, extrait le `tripID`, récupère les détails de la course depuis `tripRequests/{tripID}` et affiche le `NotificationDialog`.
4.  **Acceptation** : Le chauffeur appuie sur "ACCEPTER". L'application vérifie si la course est toujours disponible. Si oui, elle met à jour le `newTripStatus` du chauffeur avec le `tripID` de la course et le statut de la course à "accepted".
5.  **Navigation** : L'application navigue vers `new_trip_page.dart`. L'API Google Directions est appelée pour tracer l'itinéraire vers le client.
6.  **Fin de Course** : Une fois le client déposé, le chauffeur termine la course. L'état de la course dans la base de données est mis à "ended".
7.  **Paiement** : Le `PaymentDialog` s'affiche avec le tarif calculé. Après perception, l'application est réinitialisée pour que le chauffeur puisse prendre une nouvelle course.
