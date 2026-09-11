# HighwayDex 🛣️

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green.svg?style=for-the-badge)

HighwayDex is a safety-conscious, elegantly designed mobile application built with Flutter that tracks, categorizes, and logs your highway journeys. Discover and collect National, State, and Asian Highways dynamically as you drive!

## ✨ Features

- **Live Drive Mode**: Real-time GPS tracking with speedometer and live route rendering.
- **Smart Highway Analysis**: Automatically queries Google Maps APIs post-trip to analyze your path and identify exactly which highways you traversed.
- **Highway Directory**: Sort and search through a dynamic database of all your discovered highways (Ascending, Descending, Latest Traveled, Most Trips).
- **Google Drive Sync**: Never lose your progress. HighwayDex securely backups and restores your travel history and highway collection directly to your personal Google Drive.
- **Beautiful UI/UX**: Built with modern, glassmorphic design principles and a pure OLED black theme for an ultra-premium feel.

## 🛠 Tech Stack

- **Framework**: Flutter (Dart)
- **Maps & Geocoding**: `flutter_map`, `geolocator`, `geocoding`
- **Storage**: `hive` (NoSQL), `sqflite`
- **Cloud Sync**: `google_sign_in`, `googleapis` (Drive API v3)
- **Permissions**: `permission_handler`

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (v3.11.4 or higher)
- Android Studio / Xcode
- A Google Cloud Platform (GCP) project with the **Geocoding API** and **Snap to Roads API** enabled.

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ALD777/HighwayDex.git
   cd HighwayDex
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the App**
   To protect API keys, HighwayDex requires the Google Maps API key to be injected at compile/run time via `--dart-define`.
   ```bash
   flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_API_KEY_HERE
   ```
   *Note: Without the API key, the app will fall back to platform-native geocoding, which may result in less accurate highway numbering (e.g. "Unknown highway").*

## 📱 Screenshots

*(Add screenshots of your Drive Mode, Directory, and Collection screens here)*

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/ALD777/HighwayDex/issues) if you want to contribute.

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
