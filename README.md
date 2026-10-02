<div align="center">

  <img src="assets/logo.png" alt="SnapQR Logo" width="120" height="120" style="border-radius: 50%;" />

  # SnapQR
  
  **A sleek, high-performance monochrome QR code scanner built with Flutter.**

  [![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-black?style=for-the-badge)](https://flutter.dev)
  [![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=for-the-badge)](LICENSE)
  [![Code Quality](https://img.shields.io/badge/Analysis-0%20Issues-brightgreen?style=for-the-badge)](https://flutter.dev)

  <p align="center">
    <a href="#-about-the-project">About</a> •
    <a href="#-key-features">Key Features</a> •
    <a href="#-tech-stack--architecture">Architecture</a> •
    <a href="#-project-structure">Structure</a> •
    <a href="#-getting-started">Getting Started</a> •
    <a href="#-testing--quality">Testing</a>
  </p>

</div>

---

## 📖 About The Project

**SnapQR** is a modern, utility-focused QR code scanner designed with a distraction-free, minimalist monochrome aesthetic. Built from the ground up using **Flutter** and **Dart**, SnapQR bridges the gap between speed, security, and refined visual design.

Unlike traditional scanner utilities cluttered with ads and chaotic interfaces, SnapQR delivers a focused experience featuring an instant light/dark monochrome theme, a dual-engine decoding pipeline (ML Kit + pure Dart fallback), smart website metadata extraction, and active security validation against harmful link schemes.

---

## ✨ Key Features

### 🌗 1. Minimalist Monochrome Design System
* **Noir Dark Mode**: True deep pitch-black (`#0C0C0C`) optimized for OLED displays with crisp white typography.
* **Minimalist Paper Light Mode**: Clean, high-contrast white and graphite palette for daylight clarity.
* **Instant Toggle**: Seamless one-tap switch in the AppBar with persistent preference stored locally.

### 🔗 2. Smart History Hierarchy
* **Website Header on Top**: Automatically parses domain names and fetches real webpage titles (e.g., *GitHub*, *Google*, *YouTube*).
* **Direct Link Underneath**: Displays the complete URL in a clean monospace container for clarity and precision.
* **Visual Type Badges**: Differentiates content types (`HTTPS`, `HTTP`, `WI-FI`, `TEXT`) at a glance.

### ⚡ 3. Dual-Engine Scanning Pipeline
* **Live Camera Feed**: Real-time camera scanning with smooth laser reticle animations, torch support, and zoom toggle.
* **Direct Gallery Picker**: Select and decode QR codes directly from device photos without opening the camera viewfinder.
* **Hybrid Fallback**: Employs Google ML Kit for native hardware performance with a pure Dart ZXing2 fallback to guarantee decode reliability.

### 🛡️ 4. Security & Protocol Verification
* **Safe Protocol Verification**: Restricts executions to standard, safe schemes (`http`, `https`).
* **Malicious Scheme Shield**: Actively blocks dangerous execution vectors such as `javascript:`, `vbscript:`, `data:`, and `blob:`.

### 🗂️ 5. History Management & Instant Search
* **Real-Time Filtering**: Search through scan history by website title or raw URL instantly.
* **Quick Actions**: One-tap clipboard copy, direct browser launch, and individual or bulk history deletion.
* **Offline Persistence**: Fast, persistent storage backed by `SharedPreferences` and local JSON serialization.

---

## 🛠️ Tech Stack & Architecture

### Core Technologies
| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) (SDK ^3.12.0) | Cross-platform UI toolkit |
| **Language** | [Dart](https://dart.dev/) | Client-optimized OOP language |
| **Camera & Scanning** | `mobile_scanner: ^7.4.2` | High-performance camera stream analysis |
| **Image Processing** | `image: ^4.10.1`, `zxing2: ^0.2.4` | Downscaling and pure-Dart barcode decoding |
| **Storage** | `shared_preferences: ^2.5.5`, `path_provider: ^2.1.6` | Persistent local key-value and file storage |
| **Hardware & Intents** | `permission_handler: ^13.0.2`, `url_launcher: ^6.3.2` | Runtime permissions and external browser intents |

### Architecture Highlights
* **Service-Oriented Design**: Dedicated services for storage (`StorageService`), web metadata fetching (`WebMetadataService`), theme management (`ThemeService`), and barcode decoding (`QrImageDecoder`).
* **Reactive State Flow**: Clean state separation using `ChangeNotifier` and `ValueListenable` patterns for efficient, jitter-free rebuilds.
* **Resilient Networking**: Background asynchronous metadata resolution using lightweight `HttpClient` streams with strict timeouts and memory boundaries.

---

## 📂 Project Structure

```text
lib/
├── main.dart                      # Application entry point and theme orchestration
├── models/
│   ├── scan_item.dart             # Scan record data model with JSON serialization
│   └── scan_result.dart           # Route result contract for scanner workflow
├── screens/
│   ├── home_screen.dart           # Dashboard with hero card, search, and history list
│   ├── scanner_screen.dart        # Fullscreen camera scanner with animated reticle
│   └── splash_screen.dart         # Adaptive monochrome branded launch sequence
├── services/
│   ├── qr_image_decoder.dart      # Image byte downscaling and multi-pass barcode decoder
│   ├── storage_service.dart       # Local persistence and migration manager
│   ├── theme_service.dart         # Monochrome theme controller and system UI sync
│   └── web_metadata_service.dart  # HTML title extractor and URL domain resolver
└── widgets/
    └── link_preview_sheet.dart    # Modal bottom sheet for link inspection and safety checks
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `3.12.0` or higher)
* [Android Studio](https://developer.android.com/studio) / [VS Code](https://code.visualstudio.com/) with Flutter extension
* A physical device or emulator/simulator with camera support

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/SnapQR.git
   cd SnapQR
   ```

2. **Install project dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run code quality verification:**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Launch the application:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing & Quality Assurance

SnapQR includes a unit and widget test suite covering:
* Web metadata resolution across diverse protocols (HTTP, HTTPS, Wi-Fi, vCard, Text).
* Model serialization and deserialization integrity.
* Theme persistence and toggling state transitions.
* App boot and navigation smoke tests.

Run tests using the Flutter CLI:
```bash
flutter test
```

---

## 📸 Screenshots & Showcase

| Noir Dark Mode | Minimalist Light Mode | Camera Scanner | Link Details |
| :---: | :---: | :---: | :---: |
| *(Add Dark Screenshot)* | *(Add Light Screenshot)* | *(Add Scanner Screenshot)* | *(Add Preview Screenshot)* |

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <sub>Built with care and attention to detail using Flutter & Dart.</sub>
</div>

