# Daily Rabbit Confirmation

Daily crypto affirmations + embedded Jupiter Terminal swap (WebView).

## Features

- **Splash**: Pulsating rabbit logo, personalized greeting, streak count (2s then main).
- **Main**: Header (Settings, Connect/Address, Premium), affirmation section (swipe up for next, favorite/share), Jupiter Terminal WebView (SOL ↔ USDC, dark theme).
- **Settings**: Name, 4 gradient themes (Midnight Blue, Sunrise, Lavender, Forest Calm), haptic toggle, filter All/Favorites, favorites list (share/delete), wallet info, Error logs link.
- **Error Logs**: List of errors with timestamps; Copy all / Clear all.

## Tech Stack

- Flutter with **Provider** for state (theme, wallet, streak, settings, affirmations).
- **google_fonts** (Poppins), **webview_flutter** (Jupiter), **shared_preferences**, **share_plus**, **lottie**, **flutter_svg**.

## Run

```bash
cd "C:\Daily Rabbit Confirmation"
flutter pub get
flutter run
```

## Android

- Package: `com.dailyrabbit.confirmation`
- minSdk: 23, targetSdk: 34
- Permissions: INTERNET, VIBRATE

## Structure

- `lib/models/` — Affirmation, StreakManager, AppTheme (WalletState in providers).
- `lib/providers/` — ThemeNotifier, WalletState, SettingsNotifier.
- `lib/services/` — StorageService, AffirmationService, ErrorLogger.
- `lib/screens/` — Splash, Main, Settings, Error Logs.
- `lib/widgets/` — AffirmationSection, JupiterWebView.
- `assets/affirmations.json` — 20 crypto/Solana affirmations.
