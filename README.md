# Hifdh - Quran Memorization Tracker

Hifdh is a comprehensive cross-platform Flutter application designed to assist users in their journey of memorizing the Holy Quran. It provides tools for tracking progress, scheduling revisions, and noting down observations or mistakes per Ayah.

## Features

-   **📊 Dashboard**: Get a quick overview of your active tasks and recent notes.
-   **📈 Progress Tracking**:
    -   Track memorization status by **Surah**, **Juz**, and **Hizb**.
    -   **Mistakes Analysis**: Heatmap visualization to identify weak spots (Green/Yellow/Red indicators).
    -   **Detailed History**: View chronological history of notes and mistakes per Ayah.
-   **🧠 Quiz Mode**:
    -   Test your memorization with "Complete the Verse" challenges.
    -   Customizable question scope (Surah/Page range).
-   **📅 Planner**:
    -   Assign new memorization or revision tasks.
    -   Set specific deadlines with **Date & Time** limits.
-   **📝 Notes System**:
    -   Create notes, flag doubts, or mark mistakes.
    -   Link notes directly to specific Ayahs.
    -   **External Links**: Open specific Ayahs in external Quran apps or websites.
-   **⚙️ Settings & Tools**:
    -   **Backup & Restore**: Export/Import your progress data.
    -   **Themes**: Light and Dark mode support.
-   **💻 Cross-Platform**: Optimized for Android, iOS, Windows, Linux, and macOS.

## Tech Stack

-   **Framework**: [Flutter](https://flutter.dev)
-   **Language**: Dart
-   **State Management**: [Provider](https://pub.dev/packages/provider)
-   **Database**: [sqflite](https://pub.dev/packages/sqflite) (Mobile), [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi) (Desktop)
-   **Local Storage**: [shared_preferences](https://pub.dev/packages/shared_preferences)

## Getting Started

### Prerequisites

-   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
-   An IDE like VS Code or Android Studio.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/mahdiware/hifdh.git
    cd hifdh
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    # For Android/iOS
    flutter run

    # For Desktop (Linux/Windows/macOS)
    flutter run -d linux # or windows/macos
    ```

## Build & Release

This project uses **GitHub Actions** for automated builds.

-   **Android APK**: The workflow builds split APKs per ABI (e.g., `armeabi-v7a`, `arm64-v8a`) to reduce file size.
-   **Versioning**: Semantic versioning is used (e.g., `1.0.1`).

To build locally:

```bash
flutter build apk --release --split-per-abi
```

To change icon:

```bash
flutter pub run flutter_launcher_icons
```

To change version:
```bash
dart run set_version.dart 1.0.1
```

To update translations:
```bash
flutter gen-l10n
```

To change package name:
```bash
flutter pub global activate change_app_package_name
flutter pub global run change_app_package_name:main com.mahdiware.hifdh
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Contact
For any questions or suggestions, please open an issue on GitHub.
Or contact me at: https://t.me/mahdiware

## License

[MIT](LICENSE)
