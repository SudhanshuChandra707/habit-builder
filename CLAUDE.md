# To-Do List App - Claude Instructions

## Project Overview
**Habit Builder** — a Flutter mobile app for habits and tasks, with categories, priorities, due dates, reminders, and dark mode support. (Package/application ID is still `to_do_list` / `com.todolist.to_do_list`.)

App icon sources live in `assets/icon/`; regenerate platform icons with `dart run flutter_launcher_icons`.

## Development Guidelines

### Task Protocol
- **Start every task by saying "ZEMO"** as a starting keyword before beginning any work.

## Tech Stack
- **Framework**: Flutter 3.47.2
- **State Management**: Provider
- **Local Storage**: SharedPreferences
- **Language**: Dart

## Project Structure
```
lib/
├── main.dart                 # Entry point
├── models/                   # Data models
│   └── todo.dart
├── providers/                # State management
│   └── todo_provider.dart
├── screens/                  # UI screens
│   └── home_screen.dart
├── theme/                    # Theming
│   └── app_theme.dart
└── widgets/                  # Reusable components
    ├── add_todo_sheet.dart
    ├── stats_header.dart
    └── todo_tile.dart
```

## Running the App

### Web (Brave Browser)
```bash
export PATH="$PATH:/c/Flutter/flutter_windows_3.47.2-stable/flutter/bin"
export CHROME_EXECUTABLE="C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"
flutter run -d chrome
```

### Mobile
```bash
flutter run
```

## Key Features
- Add/Edit/Delete tasks
- Search functionality
- Filter by status (All/Active/Completed)
- Priority levels (Low/Medium/High)
- Categories (General, Work, Personal, Shopping, Health, Study)
- Due date tracking with overdue detection
- Dark/Light theme toggle
- Swipe to delete
- Local data persistence

## Notes
- Developer Mode must be enabled on Windows for symlink support
- App uses Material 3 with a neutral grey & white theme: near-black accent in light mode, near-white in dark; red/amber only for status (see `lib/theme/app_theme.dart`)
- Data persists locally using SharedPreferences
