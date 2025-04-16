import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class UserModel {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoURL;
  final int pointsBalance;
  final int dailySpinCount;
  final int dailyDiceCount;
  final int dailyAdWatchCount;
  final int dailyMathPuzzleCount;
  final int dailyMemoryGameCount;
  final int dailyColorMatchCount;
  final int dailyWordGameCount;
  final int todayAdEarnings;
  final int lastAdEarnings;
  final int streakCounter;
  final DateTime lastActivityDate;
  final String referralCode;
  final String? referredBy;
  final int totalEarned;
  final int totalWithdrawn;
  final int maxDailySpins;
  final int maxDailyDiceRolls;
  final int maxDailyAdWatches;
  final int maxDailyMathPuzzles;
  final int maxDailyMemoryGames;
  final int maxDailyColorMatches;
  final int maxDailyWordGames;
  final int dailyRewardLastClaimed;
  final List<Map<String, dynamic>> referredUsers;
  final Map<String, dynamic> referrerInfo;
  final Map<String, dynamic> achievements;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isSignedIn;

  UserModel({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.photoURL,
    this.pointsBalance = 0,
    this.dailySpinCount = 0,
    this.dailyDiceCount = 0,
    this.dailyAdWatchCount = 0,
    this.dailyMathPuzzleCount = 0,
    this.dailyMemoryGameCount = 0,
    this.dailyColorMatchCount = 0,
    this.dailyWordGameCount = 0,
    this.todayAdEarnings = 0,
    this.lastAdEarnings = 0,
    this.streakCounter = 0,
    DateTime? lastActivityDate,
    String? referralCode,
    this.referredBy,
    this.totalEarned = 0,
    this.totalWithdrawn = 0,
    this.maxDailySpins = 10,
    this.maxDailyDiceRolls = 5,
    this.maxDailyAdWatches = 20,
    this.maxDailyMathPuzzles = 10,
    this.maxDailyMemoryGames = 5,
    this.maxDailyColorMatches = 8,
    this.maxDailyWordGames = 6,
    this.dailyRewardLastClaimed = 0,
    this.referredUsers = const [],
    this.referrerInfo = const {},
    this.achievements = const {},
    required this.createdAt,
    required this.lastLoginAt,
    this.isSignedIn = true,
  }) : 
    lastActivityDate = lastActivityDate ?? DateTime.now(),
    referralCode = referralCode ?? _generateReferralCode(uid);

  // Factory constructor to create a UserModel from a map
  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      pointsBalance: data['pointsBalance'] ?? 0,
      dailySpinCount: data['dailySpinCount'] ?? 0,
      dailyDiceCount: data['dailyDiceCount'] ?? 0,
      dailyAdWatchCount: data['dailyAdWatchCount'] ?? 0,
      dailyMathPuzzleCount: data['dailyMathPuzzleCount'] ?? 0,
      dailyMemoryGameCount: data['dailyMemoryGameCount'] ?? 0,
      dailyColorMatchCount: data['dailyColorMatchCount'] ?? 0,
      dailyWordGameCount: data['dailyWordGameCount'] ?? 0,
      todayAdEarnings: data['todayAdEarnings'] ?? 0, 
      lastAdEarnings: data['lastAdEarnings'] ?? 0,
      streakCounter: data['streakCounter'] ?? 0,
      lastActivityDate: data['lastActivityDate'] != null 
        ? (data['lastActivityDate'] as Timestamp).toDate() 
        : DateTime.now(),
      referralCode: data['referralCode'] ?? _generateReferralCode(uid),
      referredBy: data['referredBy'],
      totalEarned: data['totalEarned'] ?? 0,
      totalWithdrawn: data['totalWithdrawn'] ?? 0,
      maxDailySpins: data['maxDailySpins'] ?? 10,
      maxDailyDiceRolls: data['maxDailyDiceRolls'] ?? 5,
      maxDailyAdWatches: data['maxDailyAdWatches'] ?? 20,
      maxDailyMathPuzzles: data['maxDailyMathPuzzles'] ?? 10,
      maxDailyMemoryGames: data['maxDailyMemoryGames'] ?? 5,
      maxDailyColorMatches: data['maxDailyColorMatches'] ?? 8,
      maxDailyWordGames: data['maxDailyWordGames'] ?? 6,
      dailyRewardLastClaimed: data['dailyRewardLastClaimed'] ?? 0,
      referredUsers: data['referredUsers'] != null
        ? List<Map<String, dynamic>>.from(data['referredUsers'])
        : [],
      referrerInfo: data['referrerInfo'] ?? {},
      achievements: data['achievements'] ?? {},
      createdAt: data['createdAt'] != null 
        ? (data['createdAt'] as Timestamp).toDate() 
        : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] != null 
        ? (data['lastLoginAt'] as Timestamp).toDate() 
        : DateTime.now(),
      isSignedIn: data['isSignedIn'] ?? true,
    );
  }

  // Convert UserModel to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoURL': photoURL,
      'pointsBalance': pointsBalance,
      'dailySpinCount': dailySpinCount,
      'dailyDiceCount': dailyDiceCount,
      'dailyAdWatchCount': dailyAdWatchCount,
      'dailyMathPuzzleCount': dailyMathPuzzleCount,
      'dailyMemoryGameCount': dailyMemoryGameCount,
      'dailyColorMatchCount': dailyColorMatchCount,
      'dailyWordGameCount': dailyWordGameCount,
      'todayAdEarnings': todayAdEarnings,
      'lastAdEarnings': lastAdEarnings,
      'streakCounter': streakCounter,
      'lastActivityDate': Timestamp.fromDate(lastActivityDate),
      'referralCode': referralCode,
      'referredBy': referredBy,
      'totalEarned': totalEarned,
      'totalWithdrawn': totalWithdrawn,
      'maxDailySpins': maxDailySpins,
      'maxDailyDiceRolls': maxDailyDiceRolls,
      'maxDailyAdWatches': maxDailyAdWatches,
      'maxDailyMathPuzzles': maxDailyMathPuzzles,
      'maxDailyMemoryGames': maxDailyMemoryGames,
      'maxDailyColorMatches': maxDailyColorMatches,
      'maxDailyWordGames': maxDailyWordGames,
      'dailyRewardLastClaimed': dailyRewardLastClaimed,
      'referredUsers': referredUsers,
      'referrerInfo': referrerInfo,
      'achievements': achievements,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isSignedIn': isSignedIn,
    };
  }

  // Generate a simple referral code from UID
  static String _generateReferralCode(String uid) {
    // Take first 6 characters of uid and append random 2 digits
    String prefix = uid.substring(0, math.min(6, uid.length));
    int random = DateTime.now().millisecondsSinceEpoch % 100;
    return '$prefix${random.toString().padLeft(2, '0')}';
  }

  // Create a copy of this UserModel with modified fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoURL,
    int? pointsBalance,
    int? dailySpinCount,
    int? dailyDiceCount,
    int? dailyAdWatchCount,
    int? dailyMathPuzzleCount,
    int? dailyMemoryGameCount,
    int? dailyColorMatchCount,
    int? dailyWordGameCount,
    int? todayAdEarnings,
    int? lastAdEarnings,
    int? streakCounter,
    DateTime? lastActivityDate,
    String? referralCode,
    String? referredBy,
    int? totalEarned,
    int? totalWithdrawn,
    int? maxDailySpins,
    int? maxDailyDiceRolls,
    int? maxDailyAdWatches,
    int? maxDailyMathPuzzles,
    int? maxDailyMemoryGames,
    int? maxDailyColorMatches,
    int? maxDailyWordGames,
    int? dailyRewardLastClaimed,
    List<Map<String, dynamic>>? referredUsers,
    Map<String, dynamic>? referrerInfo,
    Map<String, dynamic>? achievements,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isSignedIn,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      dailySpinCount: dailySpinCount ?? this.dailySpinCount,
      dailyDiceCount: dailyDiceCount ?? this.dailyDiceCount,
      dailyAdWatchCount: dailyAdWatchCount ?? this.dailyAdWatchCount,
      dailyMathPuzzleCount: dailyMathPuzzleCount ?? this.dailyMathPuzzleCount,
      dailyMemoryGameCount: dailyMemoryGameCount ?? this.dailyMemoryGameCount,
      dailyColorMatchCount: dailyColorMatchCount ?? this.dailyColorMatchCount,
      dailyWordGameCount: dailyWordGameCount ?? this.dailyWordGameCount,
      todayAdEarnings: todayAdEarnings ?? this.todayAdEarnings,
      lastAdEarnings: lastAdEarnings ?? this.lastAdEarnings,
      streakCounter: streakCounter ?? this.streakCounter,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      totalEarned: totalEarned ?? this.totalEarned,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      maxDailySpins: maxDailySpins ?? this.maxDailySpins,
      maxDailyDiceRolls: maxDailyDiceRolls ?? this.maxDailyDiceRolls,
      maxDailyAdWatches: maxDailyAdWatches ?? this.maxDailyAdWatches,
      maxDailyMathPuzzles: maxDailyMathPuzzles ?? this.maxDailyMathPuzzles,
      maxDailyMemoryGames: maxDailyMemoryGames ?? this.maxDailyMemoryGames,
      maxDailyColorMatches: maxDailyColorMatches ?? this.maxDailyColorMatches,
      maxDailyWordGames: maxDailyWordGames ?? this.maxDailyWordGames,
      dailyRewardLastClaimed: dailyRewardLastClaimed ?? this.dailyRewardLastClaimed,
      referredUsers: referredUsers ?? this.referredUsers,
      referrerInfo: referrerInfo ?? this.referrerInfo,
      achievements: achievements ?? this.achievements,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isSignedIn: isSignedIn ?? this.isSignedIn,
    );
  }

  // Getters
  int get points => pointsBalance; // Alias for pointsBalance
  int get remainingAdWatches => maxDailyAdWatches - dailyAdWatchCount;
  int get remainingMathPuzzles => maxDailyMathPuzzles - dailyMathPuzzleCount;
  int get remainingMemoryGames => maxDailyMemoryGames - dailyMemoryGameCount;
  int get remainingColorMatches => maxDailyColorMatches - dailyColorMatchCount;
  int get remainingWordGames => maxDailyWordGames - dailyWordGameCount;

  // Check if the user profile is complete with all required data
  bool get isProfileComplete {
    // Since we no longer have profile completion, consider any authenticated user's profile complete
    return true;
    
    // Old implementation:
    // // Check for essential user profile data
    // final bool hasBasicInfo = 
    //     displayName != null && 
    //     displayName!.isNotEmpty && 
    //     phoneNumber != null && 
    //     phoneNumber!.isNotEmpty;
    // 
    // // Check for contact information
    // final bool hasContactInfo = 
    //     email != null && 
    //     email!.isNotEmpty;
    // 
    // // Check for app-specific required data
    // final bool hasAppData = 
    //     referralCode.isNotEmpty;
    // 
    // return hasBasicInfo && hasContactInfo && hasAppData;
  }
}

// Transaction model for logging point changes
class TransactionModel {
  final String id;
  final String userId;
  final String type; // 'earn_spin', 'earn_offer_complete', 'withdrawal_request', etc.
  final int points;
  final String? description;
  final DateTime timestamp;
  
  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.points,
    this.description,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  factory TransactionModel.fromMap(Map<String, dynamic> data, String id) {
    return TransactionModel(
      id: id,
      userId: data['userId'],
      type: data['type'],
      points: data['points'],
      description: data['description'],
      timestamp: data['timestamp'] != null 
        ? (data['timestamp'] as Timestamp).toDate() 
        : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'points': points,
      'description': description,
      'timestamp': timestamp,
    };
  }
}

// Withdrawal request model
class WithdrawalRequestModel {
  final String id;
  final String userId;
  final int points;
  final double amount; // in BDT
  final String method; // 'bkash' or 'mobile_recharge'
  final String accountNumber; // Phone number or bKash account
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime requestDate;
  final DateTime? processedDate;
  
  WithdrawalRequestModel({
    required this.id,
    required this.userId,
    required this.points,
    required this.amount,
    required this.method,
    required this.accountNumber,
    required this.status,
    DateTime? requestDate,
    this.processedDate,
  }) : requestDate = requestDate ?? DateTime.now();
  
  factory WithdrawalRequestModel.fromMap(Map<String, dynamic> data, String id) {
    return WithdrawalRequestModel(
      id: id,
      userId: data['userId'],
      points: data['points'],
      amount: data['amount'],
      method: data['method'],
      accountNumber: data['accountNumber'],
      status: data['status'],
      requestDate: data['requestDate'] != null 
        ? (data['requestDate'] as Timestamp).toDate() 
        : DateTime.now(),
      processedDate: data['processedDate'] != null 
        ? (data['processedDate'] as Timestamp).toDate() 
        : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'points': points,
      'amount': amount,
      'method': method,
      'accountNumber': accountNumber,
      'status': status,
      'requestDate': requestDate,
      'processedDate': processedDate,
    };
  }
}