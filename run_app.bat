@echo off
echo Running Pocket Payout BD with forced Skia renderer...

:: Environment variables to disable Impeller
set FLUTTER_RENDERING_BACKEND=skia
set DISABLE_IMPELLER=1

:: Clean project first to clear any caches
flutter clean

:: Wait for cleanup to complete
echo Waiting for cleanup to complete...
timeout /t 2 /nobreak > nul

:: Get dependencies
flutter pub get

:: Launch with specific flags to disable Impeller and prevent mipmap texture issues
flutter run --dart-define=DISABLE_MIPMAP=true --no-gpu

:: Note: You might also need --no-gpu to completely bypass GPU rendering issues
:: If the app still crashes, try: flutter run --dart-define=DISABLE_MIPMAP=true --no-gpu