# Auto App Re-signing with AltStore

AltStore automatically re-signs the Todue app every 7 days using your free Apple ID, preventing the "App is no longer available" expiry. After setup, re-signing happens silently in the background as long as your PC/Mac is on and connected to the same WiFi as your iPhone.

## How It Works

1. **AltServer** runs as a background daemon on your PC or Mac.
2. **AltStore** is installed on your iPhone and manages installed sideloaded apps.
3. Every 7 days, AltStore connects to AltServer over WiFi and re-signs the app with a fresh certificate — no action needed from you.

---

## Prerequisites

- iPhone connected to your PC/Mac via USB (for initial install only).
- Your free Apple ID credentials.
- The Todue `.ipa` file built from source (see [SIDELOADING.md](SIDELOADING.md) Part 1 for how to build it).

---

## Part 1: Install AltServer on Your PC or Mac

### Windows (PC)

1. Download **AltServer for Windows** from [altstore.io](https://altstore.io).
2. Run the installer. It will also install **iCloud for Windows** and **iTunes** if not already present — both are required.
3. Once installed, AltServer appears as an icon in the **system tray** (bottom-right taskbar).
4. Set AltServer to **launch at startup**:
   - Right-click the AltServer tray icon → **Launch at Login**.

### macOS (Mac)

1. Download **AltServer for Mac** from [altstore.io](https://altstore.io).
2. Move AltServer to your Applications folder and open it.
3. AltServer appears as an icon in the **menu bar** (top-right).
4. Set AltServer to **launch at startup**:
   - Right-click the AltServer menu bar icon → **Launch at Login**.

---

## Part 2: Install AltStore on Your iPhone

1. **Connect your iPhone** to your PC/Mac via USB.
2. On **Windows**: Open iTunes and make sure your device is trusted.
   On **macOS**: Open Finder and make sure your device is trusted.
3. Click the AltServer icon in the tray/menu bar → **Install AltStore** → select your iPhone.
4. Enter your **Apple ID and password** when prompted.
   - AltServer uses these locally to sign apps — your credentials are not sent to any third-party server.
5. On your iPhone, go to **Settings > General > VPN & Device Management**, tap your Apple ID, and tap **Trust**.
6. Open the **AltStore** app on your iPhone — it should launch successfully.

---

## Part 3: Install Todue via AltStore

1. **Build the Todue IPA** on your Mac (this step requires a Mac):
   ```bash
   # Run from the 'mobile' directory
   flutter build ipa --export-method development
   ```
   The IPA will be at `build/ios/ipa/Runner.ipa`.

2. **Transfer the IPA** to your iPhone:
   - AirDrop it directly to your iPhone, or
   - Copy it to iCloud Drive and open it from the Files app on iPhone.

3. On your iPhone, open the **AltStore** app → **My Apps** tab → **+** (top-left) → select the `.ipa` file.

4. Enter your Apple ID credentials if prompted.

5. Todue will install and appear on your home screen.

---

## Part 4: Automatic Renewal

AltStore refreshes app signatures automatically in the background. For this to work:

- Your **PC/Mac must be on** and AltServer must be running.
- Your **iPhone and PC/Mac must be on the same WiFi network**.
- You do not need to be actively using either device.

If the auto-refresh ever fails (e.g., your machine was off for several days):

1. Make sure AltServer is running on your PC/Mac.
2. Connect to the same WiFi network.
3. Open **AltStore** on your iPhone → **My Apps** → swipe left on Todue → **Refresh**, or tap **Refresh All**.

---

## Troubleshooting

**"Could not connect to AltServer"**
- Make sure AltServer is running (check the tray/menu bar icon).
- Make sure your iPhone and PC/Mac are on the same WiFi network.
- Try connecting via USB, which works even without shared WiFi.

**"Maximum number of App IDs reached"**
- Free Apple accounts can only have 10 active App IDs at a time. Go to [developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles → Identifiers, and delete any unused ones.

**AltServer not launching at startup**
- Windows: Re-enable via the tray icon → Launch at Login, or add AltServer manually to the Startup folder (`shell:startup`).
- macOS: System Settings → General → Login Items → add AltServer.

**App expired before refresh**
- If the app expires, just re-install from AltStore (My Apps → +) using the same IPA. Your local app data is preserved as long as you don't delete the app first.
