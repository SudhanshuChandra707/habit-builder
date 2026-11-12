# To Do List - Flutter Mobile App

A beautiful, feature-rich to-do list mobile app built with Flutter.

## Features

- ✅ **Add, Edit & Delete Tasks** — Full CRUD operations
- 🔍 **Search** — Quickly find tasks by title or description
- 🏷️ **Categories** — Organize tasks (General, Work, Personal, Shopping, Health, Study)
- 🚩 **Priority Levels** — Low, Medium, and High with color indicators
- 📅 **Due Dates** — Set deadlines with overdue detection
- 🌙 **Dark Mode** — Toggle between light and dark themes
- 📊 **Stats Dashboard** — See total, pending, and completed task counts
- 🔄 **Filter & Sort** — View All, Active, or Completed tasks
- 💾 **Persistent Storage** — Tasks saved locally with SharedPreferences
- ↔️ **Swipe to Delete** — Intuitive gesture-based deletion

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── todo.dart                # Todo data model
├── providers/
│   └── todo_provider.dart       # State management (Provider)
├── screens/
│   └── home_screen.dart         # Main screen
├── theme/
│   └── app_theme.dart           # Light & dark themes
└── widgets/
    ├── add_todo_sheet.dart       # Add/Edit task bottom sheet
    ├── stats_header.dart         # Stats dashboard card
    └── todo_tile.dart            # Individual task tile
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>=3.0.0)
- Android Studio / Xcode (for emulators)

### Setup

```bash
cd to-do-list
flutter pub get
flutter run
```

### Build

```bash
# Android APK
flutter build apk

# iOS
flutter build ios
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `shared_preferences` | Local data persistence |
| `uuid` | Unique task IDs |
| `intl` | Date formatting |

## Screenshots

The app supports both light and dark themes with a clean, modern Material 3 design.
