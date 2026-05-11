# 💧 Water Stock App - Gestion de Dépôt d'Eau

[![Flutter Build](https://img.shields.io/badge/Flutter-v3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![SQLite](https://img.shields.io/badge/SQLite-v3-003B57?logo=sqlite&logoColor=white)](https://sqlite.org)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-blue)](#)

**Water Stock App** est une solution de Gestion Commerciale (ERP) légère et performante conçue spécifiquement pour les grossistes et dépôts d'eau. Elle permet de gérer les stocks, de suivre les ventes en temps réel et de déléguer la saisie à une secrétaire en toute sécurité.

---

## 🚀 Fonctionnalités Clés

### 🔐 Gestion des Rôles (RBAC)
* **Admin :** Contrôle total, gestion du catalogue, validation des ventes, accès à la caisse et aux statistiques.
* **Secrétaire :** Saisie des opérations quotidiennes. Les ventes restent "En attente" jusqu'à validation par l'Admin.

### 📦 Gestion des Stocks
* Suivi des quantités par marque et format.
* Système d'alertes visuelles en cas de stock bas (seuil critique).
* Mise à jour automatique du stock après validation des transactions.

### 💰 Caisse & Crédits
* **Historique complet :** Suivi des entrées (ravitaillements) et sorties (ventes).
* **Suivi des dettes :** Enregistrement du nom du client/livreur pour chaque vente, avec distinction visuelle des impayés.
* **Filtres temporels :** Bilan financier par jour, par mois ou historique global.

### 💻 Multi-Plateforme
* Optimisé pour **Android** et **iOS**.
* Support **Windows/Linux** via SQLite FFI pour une gestion sur ordinateur de bureau.

---

## 🛠️ Stack Technique

* **Framework :** [Flutter](https://flutter.dev)
* **Langage :** Dart
* **Base de données :** SQLite (via `sqflite`)
* **Architecture :** Pattern State Management (StatefulWidgets) avec séparation des services (DBHelper).

---

## 📦 Installation & Déploiement

### Prérequis
* Flutter SDK installé.
* Un émulateur Android/iOS ou un appareil physique.

### Installation locale
1.  Cloner le projet :
    ```bash
    git clone [https://github.com/votre-compte/water-stock-app.git](https://github.com/votre-compte/water-stock-app.git)
    ```
2.  Installer les dépendances :
    ```bash
    flutter pub get
    ```
3.  Lancer l'application :
    ```bash
    flutter run
    ```

### Compilation (Build)
* **Android APK :** `flutter build apk --release`
* **iOS (Codemagic/Xcode) :** `flutter build ipa --release`

---

## 🔒 Sécurité & Confidentialité
* **Base de données locale :** Aucune donnée n'est envoyée sur un serveur tiers. Tout est stocké sur l'appareil.
* **Données sensibles :** Le fichier `.gitignore` est configuré pour exclure les fichiers de build, les secrets d'IDE et les certificats de signature.

---

## 👨‍💻 Développeur
**Dao Junior** - Étudiant en Licence Informatique Réseaux (L3).