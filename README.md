# 💧 Water Stock App v4 - Gestion de Dépôt d'Eau

[![Flutter Build](https://img.shields.io/badge/Flutter-v3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![SQLite](https://img.shields.io/badge/SQLite-v3-003B57?logo=sqlite&logoColor=white)](https://sqlite.org)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-blue)](#)

**Water Stock App** est une solution de Gestion Commerciale (ERP) légère et performante conçue spécifiquement pour les grossistes et dépôts d'eau. Elle permet de gérer les stocks, de suivre les ventes en temps réel et de déléguer la saisie à une secrétaire en toute sécurité.

---

## 🚀 Fonctionnalités Clés

### 🔐 Gestion des Rôles (RBAC)
* **Admin :** Contrôle total, gestion du catalogue, validation des ventes, accès à la caisse et aux statistiques.
* **Secrétaire :** Saisie des opérations quotidiennes. Les ventes restent "En attente" jusqu'à validation par l'Admin.
* **Mots de passe hashés (SHA-256)** : plus aucun secret en clair dans le code ni dans le stockage.

### 📦 Gestion des Stocks
* Suivi des quantités par marque et format.
* Système d'alertes visuelles en cas de stock bas (seuil critique).
* Mise à jour du stock **atomique** (transactions SQL) : aucune incohérence possible en cas de coupure.

### 💰 Caisse, Clients & Crédits
* **Vraies commandes numérotées** (`VEN-20260712-0001`) regroupant le panier complet — factures PDF fiables.
* **Fiches clients réelles** : plus de doublons "Ali / ali / ALI".
* **Paiements partiels** : un client peut rembourser sa dette en plusieurs fois, chaque encaissement est tracé.
* **Filtres temporels :** Bilan financier par jour, par mois ou historique global.

### 📊 Rapports & Finance
* Tableau de bord financier avec **graphiques** (ventes/bénéfices des 14 derniers jours) et top 5 des produits.
* Rapports journaliers automatiques (ventes, dépenses, encaissé, bénéfice net).
* **Export Excel** (rapport journalier + état du stock).

### 💾 Sauvegardes
* **Sauvegarde automatique quotidienne** (14 dernières copies conservées).
* Sauvegarde manuelle et restauration vers/depuis n'importe quel dossier.
* **Migration automatique** des données de l'ancienne version (v3) au premier lancement.

### 💻 Multi-Plateforme
* Optimisé pour **Android** et **iOS**.
* Support **Windows/Linux** via SQLite FFI pour une gestion sur ordinateur de bureau.

---

## 🏗️ Architecture

```
lib/
├── core/        # Thème (couleurs centralisées) et formats (FCFA, dates)
├── models/      # Produit, Client, Commande / LigneCommande / Paiement
├── data/        # AppDatabase (schéma + migration) et repositories
│   ├── app_database.dart    # Schéma SQL, clés étrangères, migration v3 -> v4
│   ├── produit_repo.dart
│   ├── client_repo.dart
│   └── commande_repo.dart   # Toute la logique métier (transactions SQL)
├── services/    # Auth (SHA-256), Backup, PDF, Export Excel
├── screens/     # UI uniquement — aucune logique métier
└── widgets/     # Composants réutilisables
test/
└── commande_repo_test.dart  # Tests de la logique critique
```

**Schéma de données** : `produits`, `clients`, `commandes` (1) ── (N) `lignes`, `commandes` (1) ── (N) `paiements`. Les suppressions sont propagées par `ON DELETE CASCADE`.

---

## 🛠️ Stack Technique

* **Framework :** [Flutter](https://flutter.dev) / Dart
* **Base de données :** SQLite (via `sqflite` + `sqflite_common_ffi` sur desktop)
* **Graphiques :** `fl_chart` — **PDF :** `pdf` + `printing` — **Excel :** `excel`

---

## 📦 Installation & Déploiement

### Prérequis
* Flutter SDK installé.
* Un émulateur Android/iOS ou un appareil physique.

### Installation locale
1.  Installer les dépendances :
    ```bash
    flutter pub get
    ```
2.  Lancer les tests :
    ```bash
    flutter test
    ```
3.  Lancer l'application :
    ```bash
    flutter run
    ```

### Compilation (Build)
* **Android APK :** `flutter build apk --release`
* **Windows :** `flutter build windows --release`
* **iOS (Codemagic/Xcode) :** `flutter build ipa --release`

---

## 🔒 Sécurité & Confidentialité
* **Base de données locale :** Aucune donnée n'est envoyée sur un serveur tiers. Tout est stocké sur l'appareil.
* **Mots de passe :** Stockés uniquement sous forme d'empreintes SHA-256 salées. Les actions sensibles (annulation, réinitialisation) exigent le mot de passe administrateur.
* **Données sensibles :** Le fichier `.gitignore` est configuré pour exclure les fichiers de build, les secrets d'IDE et les certificats de signature.

---

## 👨‍💻 Développeur
**Dao Junior** - Étudiant en Licence Informatique Réseaux (L3).
