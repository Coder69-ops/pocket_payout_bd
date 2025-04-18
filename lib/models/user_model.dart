import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class UserModel {
  final String uid;
  final String? phoneNumber;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final int pointsBalance;
  final int dailySpinCount;
  final int dailyQuizCount;
  final int dailyScratchCount;
  final int dailyDiceCount;
  final int streakCounter;
  final DateTime lastActivityDate;
  final DateTime lastLoginAt;
  final String referralCode;
  final String? referredBy;
  final int totalEarned;
  final int totalWithdrawn;
  final int maxDailySpins;
  final int maxDailyQuizzes;
  final int maxDailyScratches;
  final int maxDailyDiceRolls;
  
  // New fields for additional games
  final int dailyMathPuzzleCount;
  final int dailyMemoryGameCount;
  final int dailyColorMatchCount;
  final int dailyWordGameCount;
  final int dailyAdWatchCount;
  
  final int maxDailyMathPuzzles;
  final int maxDailyMemoryGames;
  final int maxDailyColorMatches;
  final int maxDailyWordGames;
  final int maxDailyAdWatches;
  
  final int lastAdEarnings;
  final int todayAdEarnings;
  
  final DateTime createdAt;
  final Map<String, dynamic> referrerInfo;
  final List<Map<String, dynamic>> referredUsers;
  
  final bool isSignedIn;
  
  // Computed getters for remaining plays
  int get remainingSpins => maxDailySpins - dailySpinCount;
  int get remainingQuizzes => maxDailyQuizzes - dailyQuizCount;
  int get remainingScratches => maxDailyScratches - dailyScratchCount;
  int get remainingDiceRolls => maxDailyDiceRolls - dailyDiceCount;
  int get remainingMathPuzzles => maxDailyMathPuzzles - dailyMathPuzzleCount;
  int get remainingMemoryGames => maxDailyMemoryGames - dailyMemoryGameCount;
  int get remainingColorMatches => maxDailyColorMatches - dailyColorMatchCount;
  int get remainingWordGames => maxDailyWordGames - dailyWordGameCount;
  int get remainingAdWatches => maxDailyAdWatches - dailyAdWatchCount;
  
  // Alias for pointsBalance to match some code references
  int get points => pointsBalance;

  UserModel({
    required this.uid,
    this.phoneNumber,
    this.displayName,
    this.email,
    this.photoURL,
    this.pointsBalance = 0,
    this.dailySpinCount = 0,
    this.dailyQuizCount = 0,
    this.dailyScratchCount = 0,
    this.dailyDiceCount = 0,
    this.streakCounter = 0,
    DateTime? lastActivityDate,
    DateTime? lastLoginAt,
    String? referralCode,
    this.referredBy,
    this.totalEarned = 0,
    this.totalWithdrawn = 0,
    this.maxDailySpins = 10,
    this.maxDailyQuizzes = 5,
    this.maxDailyScratches = 3,
    this.maxDailyDiceRolls = 5,
    this.dailyMathPuzzleCount = 0,
    this.dailyMemoryGameCount = 0,
    this.dailyColorMatchCount = 0,
    this.dailyWordGameCount = 0,
    this.dailyAdWatchCount = 0,
    this.maxDailyMathPuzzles = 10,
    this.maxDailyMemoryGames = 5,
    this.maxDailyColorMatches = 8,
    this.maxDailyWordGames = 6,
    this.maxDailyAdWatches = 20,
    this.lastAdEarnings = 0,
    this.todayAdEarnings = 0,
    DateTime? createdAt,
    this.referrerInfo = const {},
    this.referredUsers = const [],
    this.isSignedIn = false,
  }) : 
    this.lastActivityDate = lastActivityDate ?? DateTime.now(),
    this.lastLoginAt = lastLoginAt ?? DateTime.now(),
    this.createdAt = createdAt ?? DateTime.now(),
    this.referralCode = referralCode ?? _generateReferralCode(uid);

  // Factory constructor to create a UserModel from a map
  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      phoneNumber: data['phoneNumber'],
      displayName: data['displayName'],
      email: data['email'],
      photoURL: data['photoURL'],
      pointsBalance: data['pointsBalance'] ?? 0,
      dailySpinCount: data['dailySpinCount'] ?? 0,
      dailyQuizCount: data['dailyQuizCount'] ?? 0,
      dailyScratchCount: data['dailyScratchCount'] ?? 0,
      dailyDiceCount: data['dailyDiceCount'] ?? 0,
      streakCounter: data['streakCounter'] ?? 0,
      lastActivityDate: data['lastActivityDate'] != null 
        ? (data['lastActivityDate'] as Timestamp).toDate() 
        : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] != null 
        ? (data['lastLoginAt'] as Timestamp).toDate() 
        : DateTime.now(),
      referralCode: data['referralCode'] ?? _generateReferralCode(uid),
      referredBy: data['referredBy'],
      totalEarned: data['totalEarned'] ?? 0,
      totalWithdrawn: data['totalWithdrawn'] ?? 0,
      maxDailySpins: data['maxDailySpins'] ?? 10,
      maxDailyQuizzes: data['maxDailyQuizzes'] ?? 5,
      maxDailyScratches: data['maxDailyScratches'] ?? 3,
      maxDailyDiceRolls: data['maxDailyDiceRolls'] ?? 5,
      dailyMathPuzzleCount: data['dailyMathPuzzleCount'] ?? 0,
      dailyMemoryGameCount: data['dailyMemoryGameCount'] ?? 0,
      dailyColorMatchCount: data['dailyColorMatchCount'] ?? 0,
      dailyWordGameCount: data['dailyWordGameCount'] ?? 0,
      dailyAdWatchCount: data['dailyAdWatchCount'] ?? 0,
      maxDailyMathPuzzles: data['maxDailyMathPuzzles'] ?? 10,
      maxDailyMemoryGames: data['maxDailyMemoryGames'] ?? 5,
      maxDailyColorMatches: data['maxDailyColorMatches'] ?? 8,
      maxDailyWordGames: data['maxDailyWordGames'] ?? 6,
      maxDailyAdWatches: data['maxDailyAdWatches'] ?? 20,
      lastAdEarnings: data['lastAdEarnings'] ?? 0,
      todayAdEarnings: data['todayAdEarnings'] ?? 0,
      createdAt: data['createdAt'] != null 
        ? (data['createdAt'] as Timestamp).toDate() 
        : DateTime.now(),
      referrerInfo: data['referrerInfo'] != null 
        ? Map<String, dynamic>.from(data['referrerInfo']) 
        : {},
      referredUsers: data['referredUsers'] != null 
        ? List<Map<String, dynamic>>.from(data['referredUsers'].map((r) => Map<String, dynamic>.from(r))) 
        : [],
      isSignedIn: data['isSignedIn'] ?? false,
    );
  }

  // Convert UserModel to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'pointsBalance': pointsBalance,
      'dailySpinCount': dailySpinCount,
      'dailyQuizCount': dailyQuizCount,
      'dailyScratchCount': dailyScratchCount,
      'dailyDiceCount': dailyDiceCount,
      'streakCounter': streakCounter,
      'lastActivityDate': Timestamp.fromDate(lastActivityDate),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'referralCode': referralCode,
      'referredBy': referredBy,
      'totalEarned': totalEarned,
      'totalWithdrawn': totalWithdrawn,
      'maxDailySpins': maxDailySpins,
      'maxDailyQuizzes': maxDailyQuizzes,
      'maxDailyScratches': maxDailyScratches,
      'maxDailyDiceRolls': maxDailyDiceRolls,
      'dailyMathPuzzleCount': dailyMathPuzzleCount,
      'dailyMemoryGameCount': dailyMemoryGameCount,
      'dailyColorMatchCount': dailyColorMatchCount,
      'dailyWordGameCount': dailyWordGameCount,
      'dailyAdWatchCount': dailyAdWatchCount,
      'maxDailyMathPuzzles': maxDailyMathPuzzles,
      'maxDailyMemoryGames': maxDailyMemoryGames,
      'maxDailyColorMatches': maxDailyColorMatches,
      'maxDailyWordGames': maxDailyWordGames,
      'maxDailyAdWatches': maxDailyAdWatches,
      'lastAdEarnings': lastAdEarnings,
      'todayAdEarnings': todayAdEarnings,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt) : null,
      'referrerInfo': referrerInfo,
      'referredUsers': referredUsers,
      'isSignedIn': isSignedIn,
    };
  }

  // Generate a simple referral code from UID
  static String _generateReferralCode(String uid) {
    // Take first 6 characters of uid and append random 2 digits
    String prefix = uid.substring(0, math.min(6, uid.length));
    int random = DateTime.now().millisecondsSinceEpoch % 100;
    return '${prefix}${random.toString().padLeft(2, '0')}';
  }

  // Create a copy of this UserModel with modified fields
  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? email,
    String? photoURL,
    int? pointsBalance,
    int? dailySpinCount,
    int? dailyQuizCount,
    int? dailyScratchCount,
    int? dailyDiceCount,
    int? streakCounter,
    DateTime? lastActivityDate,
    DateTime? lastLoginAt,
    String? referralCode,
    String? referredBy,
    int? totalEarned,
    int? totalWithdrawn,
    int? maxDailySpins,
    int? maxDailyQuizzes,
    int? maxDailyScratches,
    int? maxDailyDiceRolls,
    int? dailyMathPuzzleCount,
    int? dailyMemoryGameCount,
    int? dailyColorMatchCount,
    int? dailyWordGameCount,
    int? dailyAdWatchCount,
    int? maxDailyMathPuzzles,
    int? maxDailyMemoryGames,
    int? maxDailyColorMatches,
    int? maxDailyWordGames,
    int? maxDailyAdWatches,
    int? lastAdEarnings,
    int? todayAdEarnings,
    DateTime? createdAt,
    Map<String, dynamic>? referrerInfo,
    List<Map<String, dynamic>>? referredUsers,
    bool? isSignedIn,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      dailySpinCount: dailySpinCount ?? this.dailySpinCount,
      dailyQuizCount: dailyQuizCount ?? this.dailyQuizCount,
      dailyScratchCount: dailyScratchCount ?? this.dailyScratchCount,
      dailyDiceCount: dailyDiceCount ?? this.dailyDiceCount,
      streakCounter: streakCounter ?? this.streakCounter,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      totalEarned: totalEarned ?? this.totalEarned,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      maxDailySpins: maxDailySpins ?? this.maxDailySpins,
      maxDailyQuizzes: maxDailyQuizzes ?? this.maxDailyQuizzes,
      maxDailyScratches: maxDailyScratches ?? this.maxDailyScratches,
      maxDailyDiceRolls: maxDailyDiceRolls ?? this.maxDailyDiceRolls,
      dailyMathPuzzleCount: dailyMathPuzzleCount ?? this.dailyMathPuzzleCount,
      dailyMemoryGameCount: dailyMemoryGameCount ?? this.dailyMemoryGameCount,
      dailyColorMatchCount: dailyColorMatchCount ?? this.dailyColorMatchCount,
      dailyWordGameCount: dailyWordGameCount ?? this.dailyWordGameCount,
      dailyAdWatchCount: dailyAdWatchCount ?? this.dailyAdWatchCount,
      maxDailyMathPuzzles: maxDailyMathPuzzles ?? this.maxDailyMathPuzzles,
      maxDailyMemoryGames: maxDailyMemoryGames ?? this.maxDailyMemoryGames,
      maxDailyColorMatches: maxDailyColorMatches ?? this.maxDailyColorMatches,
      maxDailyWordGames: maxDailyWordGames ?? this.maxDailyWordGames,
      maxDailyAdWatches: maxDailyAdWatches ?? this.maxDailyAdWatches,
      lastAdEarnings: lastAdEarnings ?? this.lastAdEarnings,
      todayAdEarnings: todayAdEarnings ?? this.todayAdEarnings,
      createdAt: createdAt ?? this.createdAt,
      referrerInfo: referrerInfo ?? this.referrerInfo,
      referredUsers: referredUsers ?? this.referredUsers,
      isSignedIn: isSignedIn ?? this.isSignedIn,
    );
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
  }) : this.timestamp = timestamp ?? DateTime.now();
  
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
  }) : this.requestDate = requestDate ?? DateTime.now();
  
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

// Simple question model for quiz game
class QuestionModel {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final int points;
  
  QuestionModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.points = 100,
  });
  
  factory QuestionModel.fromMap(Map<String, dynamic> data, String id) {
    return QuestionModel(
      id: id,
      question: data['question'],
      options: List<String>.from(data['options']),
      correctOptionIndex: data['correctOptionIndex'],
      points: data['points'] ?? 100,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'points': points,
    };
  }
}