# Perplexity Style AI Chat

A powerful, multi-model AI chat application built with Flutter. This app allows users to seamlessly switch between the world's top AI models in a single, unified, dark-themed interface. 

## ✨ Features

* **Multi-Provider Support:** Instantly switch between Google Gemini, OpenAI, Anthropic (Claude), xAI (Grok), Moonshot (Kimi), and DeepSeek.
* **Dynamic API Configuration:** Users can input and securely save their own API keys directly within the app via the Settings menu.
* **Deep Research Mode:** Toggle an exhaustive research mode that injects advanced system prompts and utilizes native web-search tools (where supported).
* **Multimodal Capabilities:** Upload images and documents directly into the chat for vision-capable models to analyze.
* **Local Chat History:** Conversations are automatically saved to your device using `shared_preferences`.
* **Sleek UI:** A modern, dark-mode interface inspired by Perplexity, complete with a collapsible sidebar and pinned chats.

## 🛠️ Tech Stack

* **Framework:** Flutter / Dart
* **State Management:** Provider
* **Storage:** Shared Preferences
* **Environment Variables:** `flutter_dotenv`
* **Networking:** `http` package

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
* An IDE like VS Code or Android Studio.

### Installation

1. **Clone the repository**
```bash
git clone [https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git](https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git)
cd YOUR_REPO_NAME
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Set up Environment Variables**
Create a `.env` file in the root directory of the project and add your default API keys (these act as fallbacks if the user hasn't set their own in the app):
```env
GEMINI_API_KEY=your_google_key_here
CLAUDE_API_KEY=your_anthropic_key_here
GROK_API_KEY=your_xai_key_here
KIMI_API_KEY=your_moonshot_key_here
DEEPSEEK_API_KEY=your_deepseek_key_here
```
*Note: Ensure `.env` is added to your `.gitignore` file to keep your keys secure!*

4. **Add Assets Configuration**
Ensure your `pubspec.yaml` is configured to load the `.env` file and your brand logos:
```yaml
flutter:
  assets:
    - .env
    - assets/
```

5. **Run the App**
```bash
flutter run
```

## 🏗️ Building for Release (Android)

To create a release-ready APK to install on a physical device:

1. Clean the build directories to ensure a fresh compilation:
```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
```
2. Build the APK:
```bash
flutter build apk --release
```
3. Locate the generated APK at:
`build/app/outputs/flutter-apk/app-release.apk`

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the issues page.
