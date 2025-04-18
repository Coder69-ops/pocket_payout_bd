# Pocket Payout BD

A Flutter-based rewards app that allows users to earn points through engaging mini-games and activities, which can be converted to Bangladesh Taka (BDT).

## App Overview

Pocket Payout BD is a mobile application designed for Bangladesh users to earn rewards through various interactive games and ad engagements. Users can accumulate points and withdraw them as real money once they reach the minimum threshold.

## Features

- **Multiple Mini-Games:**
  - Spin Wheel (up to 10 plays daily)
  - Dice Game (up to 15 plays daily)
  - Math Puzzle (up to 10 plays daily)
  - Memory Game (up to 5 plays daily)
  - Color Match (up to 8 plays daily)
  - Word Game (up to 6 plays daily)

- **Ad-Based Rewards:**
  - Dedicated ad watch section (up to 20 daily)
  - Interstitial ads after game completions
  - Rewarded video ads for bonus points

- **Points System:**
  - Base points for each activity/game
  - Streak multiplier (up to 3x for 7+ day streaks)
  - Conversion rate: 1,000 points = 1 BDT

- **Withdrawal System:**
  - Minimum withdrawal: 20,000 points (20 BDT)
  - User transaction history
  - Multiple withdrawal methods

- **User Features:**
  - Daily login streak tracking
  - Leaderboard
  - Profile management
  - Referral system (5,000 points for referrer, 10,000 for new user)

## Technical Details

- Built with Flutter
- Firebase backend (Authentication, Firestore)
- Google AdMob integration
- Real-time point tracking and transaction history

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Firebase project setup
- AdMob account and ad unit IDs

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/Coder69-ops/pocket_payout_bd.git
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Configure Firebase:
   - Update the `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files
   - Ensure Firestore rules are correctly set up

4. Configure AdMob:
   - Update ad unit IDs in `lib/utils/constants.dart`

5. Run the app:
   - Use the included script for Windows: `run_app.bat`
   - Or standard Flutter command: `flutter run`

## Monetization Model

The app monetizes through Google AdMob with:
- Rewarded video ads
- Interstitial ads
- Banner ads

Users interact with approximately 80+ ads daily when maximizing all activities, providing revenue to support the points-based reward system.

## Firebase Configuration

The app uses Firebase for:
- User authentication
- Storing user data and transaction history
- Tracking points and game plays
- Managing withdrawal requests

## Known Issues

- Some GPU rendering issues on certain devices (use `run_app.bat` with Skia renderer)
- Consider CPM rates in Bangladesh when balancing reward points against ad revenue

## License

Copyright © 2025

## Contact

For support or inquiries, please contact https://www.linkedin.com/in/ovejit-das-826987354/.
