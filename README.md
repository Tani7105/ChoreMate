<p align="center">
  <img src="assets/logo.png" alt="ChoreMate logo" width="120" />
</p>

<h1 align="center">ChoreMate</h1>

<p align="center">
  A Flutter + Firebase iOS app that helps housemates split chores, plan events, and keep shared house info in one place.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Platform-iOS-lightgrey?logo=apple" />
</p>

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Screenshots](#screenshots)
- [Getting Started](#getting-started)
- [Firebase Setup](#firebase-setup)
- [Running on a Physical iPhone](#running-on-a-physical-iphone)
- [Project Structure](#project-structure)
- [Data Model](#data-model)
- [Theming](#theming)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [Author](#author)

---

## About

Living with housemates means constantly negotiating who takes out the trash, who cleans the kitchen, and when the next house dinner is. ChoreMate gives every house a shared space to:

- assign and track chores,
- schedule house events on a shared calendar, and
- store important house contacts.

The app is built with Flutter, backed by Firebase (Auth, Firestore, Cloud Functions), and deployed to production on iOS.

---

## Features

### Authentication
- Email/password **Sign Up** and **Log In** with Firebase Auth
- A Firestore user document is created automatically on sign up

### Chores
- Assign chores to a specific housemate
- **"Anyone (first available)"** option -- stored as `assignedTo: 'anyone'` so whoever is free can claim it

### Events
- Shared house calendar built with [`table_calendar`](https://pub.dev/packages/table_calendar)
- Monthly and weekly views
- Dot markers on days that have events
- Per-day event list when a date is selected

### House Info
- Shared list of house contacts (landlord, maintenance, etc.)
- **Add Contact** screen via the `+` button -- restricted to the house rep

### Backend
- Cloud Functions running on the Firebase **Blaze** plan
- Firestore as the real-time data store

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Server logic | Firebase Cloud Functions |
| Calendar | `table_calendar` |
| Build tooling | Xcode, `xcodebuild`, CocoaPods |
| Target platform | iOS (tested on a physical iPhone) |

---

## Screenshots

> Add screenshots to `docs/screenshots/` and update the paths below.

| Login | Chores | Events | House Info |
|:-----:|:------:|:------:|:----------:|
| ![Login](docs/screenshots/login.png) | ![Chores](docs/screenshots/chores.png) | ![Events](docs/screenshots/events.png) | ![House Info](docs/screenshots/house_info.png) |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Xcode (latest stable) + Command Line Tools
- CocoaPods (`sudo gem install cocoapods`)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) (`dart pub global activate flutterfire_cli`)
- A Firebase project on the **Blaze** plan (required for Cloud Functions)

### Installation

```bash
# 1. Clone the repo
git clone https://github.com/<your-username>/choremate.git
cd choremate

# 2. Install Flutter dependencies
flutter pub get

# 3. Install iOS pods
cd ios && pod install && cd ..
```

---

## Firebase Setup

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication -> Email/Password**.
3. Create a **Cloud Firestore** database.
4. Upgrade the project to the **Blaze** plan.
5. Connect the Flutter app:
   ```bash
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart` and adds `GoogleService-Info.plist` to `ios/Runner/`.
6. Deploy Cloud Functions:
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

### Local emulators (optional)

```bash
firebase emulators:start
```

> **Important:** Remove (or guard behind a debug flag) any `useFirestoreEmulator` / `useAuthEmulator` / `useFunctionsEmulator` lines in `main.dart` before building against live Firebase.

---

## Running on a Physical iPhone

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Under **Signing & Capabilities**, select your Apple Developer team.
3. Plug in your iPhone and trust the computer.
4. Make sure your **iPhone and Mac are on the same network**.
5. Build and run:

```bash
# Debug
flutter run

# Release build (stays installed and runs untethered)
flutter run --release
```

If Flutter can't find the right destination, list devices with Xcode and target by ID:

```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -showdestinations
```

---

## Project Structure

```
choremate/
├── assets/
│   └── logo.png
├── functions/              # Firebase Cloud Functions
├── ios/                    # iOS runner + Podfile
├── lib/
│   ├── main.dart           # App entry, theme, navigation
│   ├── firebase_options.dart
│   └── ...                 # Screens: login, sign up, chores, events, house info, add contact
├── pubspec.yaml
└── README.md
```

---

## Data Model

Simplified Firestore layout:

```
users/{uid}
  name, email, houseId, role ('rep' | 'member')

houses/{houseId}
  name, ...

houses/{houseId}/chores/{choreId}
  title, assignedTo (uid | 'anyone'), dueDate, completed

houses/{houseId}/events/{eventId}
  title, dateTime, description

houses/{houseId}/contacts/{contactId}
  name, phone, role
```

> Adjust to match your actual collection names.

---

## Theming

Colors are defined as named constants in one place and applied across the AppBars and bottom `NavigationBar`.

| Token | Hex | Use |
|-------|-----|-----|
| `kPrimary` | `#8BB0D4` | Primary blue |
| `kAccent` | `#E8843C` | Orange accent |

The palette follows a soft blue/peach gradient.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `EXC_BAD_ACCESS` on device | Check the iPhone and Mac are on the **same network** -- this was a network issue, not a code bug. |
| `setState() called after dispose()` | Check `if (!mounted) return;` before calling `setState` after async work. |
| Event times shift by several hours | `toIso8601String()` converts to UTC. Format the date/time string manually without timezone conversion. |
| Xcode destination mismatch | Use device IDs from `xcodebuild -showdestinations` instead of `flutter devices`. |
| Pod install errors / corrupted Podfile | Delete `ios/Podfile` (and `Podfile.lock`), recreate it, then run `pod install` again. |
| App still talking to emulators in production | Remove the emulator connection lines from `main.dart`. |

---

## Roadmap

- [ ] Push notifications for chore reminders
- [ ] Recurring chores
- [ ] Chore completion history and stats
- [ ] Android support
- [ ] App Store / TestFlight release

---

## Author

**Tanishq** -- Computer Science, University of Cincinnati

Feel free to open an issue or submit a pull request.
