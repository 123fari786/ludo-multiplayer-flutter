# 🎲 Ludo Game

A Flutter-based Ludo game supporting **offline gameplay** and **real-time one-to-one online multiplayer** with Firebase integration.

The application provides a classic Ludo gaming experience with local gameplay as well as online multiplayer functionality, allowing two players to play against each other in real time.

---

## ✨ Features

* 🎮 **Offline Ludo Game**

  * Play Ludo locally without an online opponent.
  * Interactive board and token movement.

* 👥 **One-to-One Online Multiplayer**

  * Play Ludo with another player online.
  * Real-time game interaction between two players.

* ⚡ **Real-Time Gameplay**

  * Real-time synchronization of online game state.
  * Online player and match management.

* 🔥 **Firebase Integration**

  * Firebase-based online game services.
  * Real-time communication and game data synchronization.

* 🎲 **Interactive Ludo Board**

  * Dice functionality.
  * Player tokens and movement.
  * Turn-based gameplay.

* 🏆 **Leaderboard**

  * Player ranking and game-related information.

* 👤 **User Profile**

  * User account and profile functionality.

* 💰 **Coin / Wallet System**

  * In-app coin-related functionality.
  * Deposit and withdrawal related screens.

* 🔔 **Notifications**

  * Application notification functionality.

* 📱 **Flutter Responsive UI**

  * Mobile-friendly user interface.
  * Reusable Flutter UI components.

---

## 🛠️ Technology Stack

| Technology     | Purpose                                       |
| -------------- | --------------------------------------------- |
| Flutter        | Cross-platform mobile application development |
| Dart           | Application programming language              |
| Firebase       | Online multiplayer and backend services       |
| Real-Time Data | Synchronizing online gameplay                 |
| Git            | Version control                               |
| GitHub         | Source code management                        |

---

## 🎮 Game Modes

### 1. Offline Mode

The offline mode allows players to play Ludo locally without requiring an online multiplayer connection.

### 2. One-to-One Online Mode

The online mode allows two players to participate in the same Ludo match through a real-time connection.

The online gameplay uses Firebase services to manage and synchronize the game state between players.

---

## 🔥 Firebase Integration

Firebase is used to support the online multiplayer functionality of the application.

The project includes functionality related to:

* Online game management
* Matchmaking
* Real-time game state
* Player information
* Online multiplayer communication

---

## 🏗️ Project Structure

```text
lib/
│
├── Chatscreen/
│   ├── chat_service.dart
│   └── real_chat_screen.dart
│
├── Reward/
│   └── RewardService.dart
│
├── component/
│   ├── controller/
│   ├── grid_component/
│   ├── home/
│   └── ui_components/
│
├── play_with_online/
│   ├── firebase_service.dart
│   ├── match_model.dart
│   ├── matchmaking_service.dart
│   └── online_color_selection.dart
│
├── state/
│   ├── audio_manager.dart
│   ├── event_bus.dart
│   ├── game_state.dart
│   ├── player.dart
│   └── token_manager.dart
│
├── ludo.dart
├── ludo_board.dart
├── onlinegamemanager.dart
├── play_with_online.dart
└── main.dart
```

---

## 📱 Screenshots

Add screenshots of the application here to demonstrate the user interface and gameplay.

Recommended screenshots:

* Login / Signup
* Home Screen
* Offline Game
* Online Game
* Online Matchmaking
* Ludo Board
* Profile
* Leaderboard
* Wallet / Coins

Example:

```text
screenshots/
├── home.png
├── offline-game.png
├── online-game.png
├── matchmaking.png
├── leaderboard.png
└── profile.png
```

---

## 🚀 Getting Started

### Prerequisites

Make sure the following are installed:

* Flutter SDK
* Dart SDK
* Android Studio or VS Code
* Git

Check your Flutter installation:

```bash
flutter doctor
```

---

## 📥 Installation

### Clone the repository

```bash
git clone https://github.com/123fari786/ludo-multiplayer-flutter.git
```

Navigate to the project:

```bash
cd ludo-multiplayer-flutter
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

---

## 🔐 Firebase Configuration

The online multiplayer functionality requires Firebase configuration.

For security reasons, private credentials, API keys, certificates, and other sensitive configuration should not be committed to a public repository.

Configure Firebase according to your own Firebase project before running the online multiplayer functionality.

---

## 🎯 Project Highlights

This project demonstrates practical experience in:

* Flutter application development
* Dart programming
* Offline game development
* Real-time multiplayer functionality
* Firebase integration
* Matchmaking
* Game state synchronization
* State management
* Reusable UI components
* User authentication
* Leaderboards
* Real-time communication
* Git and GitHub

---

## 👨‍💻 Developer

**Muhammad Farhan**

Flutter / Mobile Application Developer

**Technologies:**

`Flutter` · `Dart` · `Firebase` · `Real-Time Multiplayer` · `Git` · `GitHub`

---

## 📄 License

This project is provided for educational and portfolio purposes.
