class GameConstants {
  // Daily limits
  static const int maxDailySpin = 10;
  static const int maxDailyQuiz = 5;
  static const int maxDailyScratch = 8;
  static const int maxDailyDice = 15;
  
  // New game-specific limits
  static const int maxDailyMathPuzzles = 10;
  static const int maxDailyMemoryGames = 5;
  static const int maxDailyColorMatches = 8;
  static const int maxDailyWordGames = 6;
  static const int maxDailyAdWatches = 20;
  
  // Base point rewards (before ad multiplier) - reduced by 70%
  static const Map<String, int> basePoints = {
    'spin': 30,      // Was 100 (0.03 BDT now)
    'quiz': 60,      // Was 200 (0.06 BDT now)
    'scratch': 45,   // Was 150 (0.045 BDT now)
    'dice': 30,      // Was 100 (0.03 BDT now)
    'watch_ad': 15,  // Was 50 (0.015 BDT now)
    'math_puzzle': 45, // Was 150 (0.045 BDT now)
    'memory_game': 60, // Was 200 (0.06 BDT now)
    'color_match': 45, // Was 150 (0.045 BDT now)
    'word_game': 53,   // Was 175 (0.053 BDT now)
  };
  
  // Game-specific point values - reduced by 70%
  static const int mathPuzzleMinPoints = 15; // Was 50
  static const int mathPuzzlePointsMultiplier = 3; // Was 10
  
  // Multipliers - remain the same as they are percentages
  static const double adMultiplier = 2.0;  // Double points when watching ad
  static const double streakMultiplier = 1.5;  // 50% bonus on 7-day streak
  
  // Streak multipliers based on streak count - remain the same
  static const Map<int, double> streakMultipliers = {
    0: 1.0,
    1: 1.1,
    2: 1.2,
    3: 1.5,
    4: 1.8,
    5: 2.0,
    6: 2.5,
    7: 3.0,
  };
  
  // Helper method to get streak multiplier
  static double getStreakMultiplier(int streakCount) {
    if (streakCount >= 7) return 3.0;
    return streakMultipliers[streakCount] ?? 1.0;
  }
  
  // Withdrawal - minimum remains the same for usability
  static const int minWithdrawal = 20000;  // 20 BDT minimum
  static const int pointsToBDT = 1000;     // 1000 points = 1 BDT
  
  // Referral rewards - reduced by 70%
  static const int referrerReward = 150;   // Was 500 (0.15 BDT now)
  static const int referredReward = 90;    // Was 300 (0.09 BDT now)
}

class TransactionTypes {
  static const String earnSpin = 'earn_spin';
  static const String earnQuiz = 'earn_quiz';
  static const String earnScratch = 'earn_scratch';
  static const String earnDice = 'earn_dice';
  static const String earnAd = 'earn_ad';
  static const String earnOffer = 'earn_offer';
  static const String earnReferral = 'earn_referral';
  static const String earnReferralBonus = 'earn_referral_bonus';
  static const String withdraw = 'withdrawal';
  
  // New transaction types for the games
  static const String earnMathPuzzle = 'earn_math_puzzle';
  static const String earnMemoryGame = 'earn_memory_game';
  static const String earnColorMatch = 'earn_color_match';
  static const String earnWordGame = 'earn_word_game';
}

// Add the missing AppConstants class
class AppConstants {
  // Collection names for Firestore
  static const String usersCollection = 'users';
  static const String transactionsCollection = 'transactions';
  static const String withdrawalRequestsCollection = 'withdrawal_requests';
  static const String pendingReferralsCollection = 'pending_referrals';
  static const String questionsCollection = 'questions';
  static const String adminUsersCollection = 'admin_users';
  
  // Ad unit IDs - updated with real ad unit IDs
  static const String appId = 'ca-app-pub-6259536428730275~8639258520'; // Real App ID
  static const String rewardedAdUnitId = 'ca-app-pub-6259536428730275/9592014019'; // Real Rewarded Ad ID
  static const String interstitialAdUnitId = 'ca-app-pub-6259536428730275/8827804673'; // Real Interstitial Ad ID
  static const String bannerAdUnitId = 'ca-app-pub-6259536428730275/4157931927'; // Real Banner ID
  
  // Withdrawal-related constants
  static const int minimumWithdrawalPoints = 20000;
  static const double pointsToTakaRate = 0.001; // 1000 points = 1 BDT
  
  // App configuration
  static const int defaultMaxDailyLimit = 10;
}