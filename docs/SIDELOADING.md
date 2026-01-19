# iOS Sideloading Guide

This guide covers how to install the Todue app on your iPhone using a free Apple Developer account. The app will remain active for **7 days**. After that, you must repeat the "Renewal" steps.

## Prerequisites

*   iPhone connected to your Mac via USB.
*   **Developer Mode** enabled on your iPhone (Settings > Privacy & Security > Developer Mode).
*   Xcode installed on your Mac.
*   Terminal open in the `mobile` directory of the project.

---

## Part 1: Release Mode (Standard Use)

This installs the optimized version of the app for normal use. It connects to the **Production Server** (`todue.ethandean.dev`) by default.

### A. First-Time Setup (One-Off)

1.  **Open Xcode Workspace:**
    ```bash
    open ios/Runner.xcworkspace
    ```
2.  **Configure Signing:**
    *   In Xcode, select **Runner** (top-left blue icon).
    *   Go to the **Signing & Capabilities** tab.
    *   **Team:** Select "Add an Account..." and log in with your free Apple ID.
    *   **Bundle Identifier:** Change `com.example.todue` to something unique (e.g., `com.yourname.todue.mobile`).
    *   **Team:** Select your "Personal Team".
    *   Ensure no red error messages appear.

### B. Installing / Renewing (Weekly)

Perform these steps every 7 days or whenever you want to update the app.

1.  **Connect your iPhone** to your Mac.
2.  **Run the install command:**
    ```bash
    # Run from the 'mobile' directory
    flutter run --release
    ```
3.  **Trust the App (First install only):**
    *   If the app installs but won't open ("Untrusted Developer"):
    *   Go to iPhone **Settings > General > VPN & Device Management**.
    *   Tap your Apple ID email.
    *   Tap **Trust**.

*Note: You do not need to delete the old app; `flutter run` will overwrite it and keep your local data (unless you changed the Bundle ID).*

---

## Part 2: Debug Mode (Development)

Use this to debug the app on your physical phone while viewing logs in your terminal. 

**Critical:** By default, Debug mode tries to connect to `localhost:8080`. Your phone cannot reach your laptop's localhost. You must temporarily point the app to the Production server.

### 1. Point Debug to Production
Open `mobile/lib/config/environment.dart` and modify the `devApiUrl` and `devWsUrl` to use your real server:

```dart
class Environment {
  // Development - TEMPORARILY Pointing to Prod for physical device debugging
  static const String devApiUrl = 'https://todue.ethandean.dev/api';
  static const String devWsUrl = 'wss://todue.ethandean.dev/ws';

  // ... rest of the file
}
```

### 2. Run in Debug Mode
1.  **Connect your iPhone.**
2.  **Run the command:**
    ```bash
    flutter run
    ```
    *(Do not use `--release`)*.
3.  The app will launch, and you will see **logs** in your terminal.
4.  **Important:** The app will only work while connected to your Mac.

### 3. Revert Changes
When finished, remember to revert `mobile/lib/config/environment.dart` back to localhost if you plan to use the iOS Simulator later:

```dart
  static const String devApiUrl = 'http://localhost:8080/api';
  static const String devWsUrl = 'ws://localhost:8080/ws';
```
