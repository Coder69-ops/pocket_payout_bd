class GameConstants {
  // Daily limits
  static const int maxDailySpin = 10;
  static const int maxDailyScratch = 8;
  static const int maxDailyDice = 15;
  static const int maxDailyMathPuzzle = 10;
  static const int maxDailyMemoryGame = 5;
  static const int maxDailyColorMatch = 8;
  static const int maxDailyWordGame = 6;
  
  // Base point rewards (before ad multiplier)
  static const Map<String, int> basePoints = {
    'spin': 300,     // 0.3 BDT (3x increase)
    'scratch': 400,  // 0.4 BDT (2.67x increase)
    'dice': 250,     // 0.25 BDT (2.5x increase)
    'watch_ad': 150,  // 0.15 BDT for direct ad watch (3x increase)
    'math_puzzle': 350, // 0.35 BDT for math puzzles
    'memory_game': 450, // 0.45 BDT for memory game
    'color_match': 300, // 0.3 BDT for color matching
    'word_game': 400,   // 0.4 BDT for word games
  };
  
  // Math puzzle specific constants
  static const int mathPuzzleMinPoints = 300;
  static const int mathPuzzlePointsMultiplier = 30;
  
  // Multipliers
  static const double adMultiplier = 2.0;  // Double points when watching ad
  static const Map<int, double> streakMultipliers = {
    1: 1.0,    // Day 1: No bonus
    2: 1.2,    // Day 2: 20% bonus
    3: 1.5,    // Day 3: 50% bonus
    4: 1.8,    // Day 4: 80% bonus
    5: 2.0,    // Day 5: 2x bonus
    6: 2.5,    // Day 6: 2.5x bonus
    7: 3.0,    // Day 7+: 3x bonus
  };
  // Legacy streak multiplier maintained for backward compatibility
  static const double streakMultiplier = 3.0;  // Updated to 3x bonus (was 1.5x)
  
  // Withdrawal
  static const int minWithdrawal = 20000;  // 20 BDT minimum
  static const int pointsToBDT = 1000;     // 1000 points = 1 BDT
  
  // Referral rewards
  static const int referrerReward = 5000;   // 5 BDT for referrer
  static const int referredReward = 10000;   // 10 BDT for new user
  
  // Get streak multiplier based on streak count
  static double getStreakMultiplier(int streakCount) {
    if (streakCount >= 7) return streakMultipliers[7]!;
    return streakMultipliers[streakCount] ?? 1.0;
  }
}

class TransactionTypes {
  static const String earnSpin = 'earn_spin';
  static const String earnScratch = 'earn_scratch';
  static const String earnDice = 'earn_dice';
  static const String earnAd = 'earn_ad';
  static const String earnOffer = 'earn_offer';
  static const String earnReferral = 'earn_referral';
  static const String earnReferralBonus = 'earn_referral_bonus';
  static const String earnMathPuzzle = 'earn_math_puzzle';
  static const String earnMemoryGame = 'earn_memory_game';
  static const String earnColorMatch = 'earn_color_match';
  static const String earnWordGame = 'earn_word_game';
  static const String withdraw = 'withdrawal';
}

class AppConstants {
  // Firebase collection names
  static const String usersCollection = 'users';
  static const String transactionsCollection = 'transactions';
  static const String withdrawalRequestsCollection = 'withdrawal_requests';
  
  // Test ad unit IDs for development
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  
  // Production ad unit IDs
  static const String prodRewardedAdUnitId = 'ca-app-pub-6259536428730275/5347108323';
  static const String prodInterstitialAdUnitId = 'ca-app-pub-6259536428730275/9094781645';
  static const String prodBannerAdUnitId = 'ca-app-pub-6259536428730275/2581404307';
  
  static String get rewardedAdUnitId {
    // Use test ads for debug builds, real ads for release
    bool isDebug = true;
    assert(() {
      isDebug = true;
      return true;
    }());
    
    return isDebug ? testRewardedAdUnitId : prodRewardedAdUnitId;
  }
  
  static String get interstitialAdUnitId {
    bool isDebug = true;
    assert(() {
      isDebug = true;
      return true;
    }());
    
    return isDebug ? testInterstitialAdUnitId : prodInterstitialAdUnitId;
  }
  
  static String get bannerAdUnitId {
    bool isDebug = true;
    assert(() {
      isDebug = true;
      return true;
    }());
    
    return isDebug ? testBannerAdUnitId : prodBannerAdUnitId;
  }
  
  // Game constants
  static const int maxDailySpins = 5;
  static const int maxDailyScratchCards = 3;
  static const int maxDailyDiceRolls = 5;
  
  // Withdrawal constants
  static const int minimumWithdrawalPoints = 20000; // 20,000 points = 20 BDT
  static const double pointsToTakaRate = 0.001; // 1000 points = 1 BDT
}