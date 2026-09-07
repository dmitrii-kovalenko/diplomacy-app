# Diplomacy Mobile App

A cross-platform mobile application for the classic board game **Diplomacy**, built with Flutter.

## Features

- 🔐 **JWT Authentication** with Apple, Google, and Email/Password sign-in
- 🗺️ **Interactive SVG Map** with pan/zoom, province hit-testing, and Bézier order arrows
- ⚔️ **Full Order System** — Move, Support, Convoy, Hold, Build, Disband, Retreat
- 💬 **End-to-End Encrypted Chat** (ECDH P-256 + AES-GCM-256)
- 🔔 **Push Notifications** with deep-linking to games and conversations
- 🏆 **Tournament Support**
- 🌍 **6 Languages** — English, Russian, Ukrainian, German, Chuvash, Esperanto
- 📡 **Real-time WebSocket Updates** — no polling

## Architecture

```
lib/
├── blocs/           # State management (ChangeNotifier + Provider)
│   ├── chat/        # ChatBloc (WebSocket per conversation)
│   ├── game/        # OrderBloc (order state machine)
│   └── lobby/       # LobbyBloc (WebSocket lobby updates)
├── config/          # App configuration
├── l10n/            # ARB translation files
├── models/          # Data models
├── providers/       # LocaleProvider
├── screens/
│   ├── auth/        # Login, Register, Nickname
│   ├── chat/        # Conversations, Messages
│   ├── game/        # GameScreen, PreviewScreen
│   ├── lobby/       # Lobby, Create Game, Find Game
│   ├── settings/    # Settings
│   └── tournament/  # Tournament
├── services/
│   ├── auth_service.dart    # Dio + JWT interceptor
│   ├── e2ee_service.dart    # ECDH + AES-GCM encryption
│   ├── game_service.dart    # Game API calls
│   ├── lobby_service.dart   # Lobby API calls
│   └── push_service.dart    # FCM push notifications
└── widgets/
    ├── game_card.dart       # Lobby game card
    ├── map_viewer.dart      # Interactive SVG map renderer
    └── order_arrows.dart    # Bézier order arrow painter
```

## Getting Started

### Prerequisites

- Flutter SDK >= 3.24.0
- Firebase project configured (for push notifications)
- Backend server running (Django)

### Setup

```bash
# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run the app
flutter run
```

### Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires Xcode)
flutter build ios --release
```

### Environment Configuration

Override the backend URL at build time:

```bash
flutter run --dart-define=BASE_URL=https://your-server.com
```

## Backend

The Django backend is located in `../DjangoProject/`. It provides:
- REST API for game logic, lobbies, tournaments
- WebSocket channels for real-time updates
- FCM push notification delivery
- Telegram Mini App compatibility (maintained alongside the mobile app)
