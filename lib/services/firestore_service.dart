import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pocket_payout_bd/models/user_model.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  CollectionReference get _usersCollection => _firestore.collection(AppConstants.usersCollection);
  CollectionReference get _transactionsCollection => _firestore.collection(AppConstants.transactionsCollection);
  CollectionReference get _withdrawalRequestsCollection => _firestore.collection(AppConstants.withdrawalRequestsCollection);
  
  // Create a new user
  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }
  
  // Get user data
  Future<UserModel> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(uid).get();
      
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      } else {
        throw Exception('User does not exist');
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
      rethrow;
    }
  }
  
  // Update user points and log transaction
  Future<void> updateUserPoints(String uid, int points, String type, {String? description}) async {
    try {
      debugPrint('FirestoreService: Updating points for user $uid: $points points, type: $type');
      
      // Use a transaction to ensure both operations succeed or fail together
      await _firestore.runTransaction((transaction) async {
        // Get current user data to verify the update
        DocumentSnapshot userDoc = await transaction.get(_usersCollection.doc(uid));
        
        if (!userDoc.exists) {
          throw Exception('User does not exist');
        }
        
        // Update user's points in Firestore
        transaction.update(
          _usersCollection.doc(uid), 
          {
            'pointsBalance': FieldValue.increment(points),
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          }
        );
        
        // Log the transaction
        transaction.set(
          _transactionsCollection.doc(),
          {
            'userId': uid,
            'type': type,
            'points': points,
            'description': description,
            'timestamp': FieldValue.serverTimestamp(),
          },
        );
      });
      
      debugPrint('FirestoreService: Successfully updated points for user $uid');
    } catch (e) {
      debugPrint('Error updating points: $e');
      rethrow;
    }
  }
  
  // Update daily counter for a specific activity
  Future<void> updateDailyCounter(String uid, String activity, int count) async {
    try {
      String field;
      switch (activity) {
        case 'spin':
          field = 'dailySpinCount';
          break;
        case 'quiz':
          field = 'dailyQuizCount';
          break;
        case 'scratch':
          field = 'dailyScratchCount';
          break;
        case 'dice':
          field = 'dailyDiceCount';
          break;
        case 'ad_watch':
          field = 'dailyAdWatchCount';
          break;
        case 'math_puzzle':
          field = 'dailyMathPuzzleCount';
          break;
        case 'memory_game':
          field = 'dailyMemoryGameCount';
          break;
        case 'color_match':
          field = 'dailyColorMatchCount';
          break;
        case 'word_game':
          field = 'dailyWordGameCount';
          break;
        default:
          throw ArgumentError('Invalid activity type: $activity');
      }
      
      debugPrint('FirestoreService: Updating $field to $count for user $uid');
      await _usersCollection.doc(uid).update({
        field: count,
        'lastActivityDate': FieldValue.serverTimestamp(),
      });
      debugPrint('FirestoreService: Successfully updated $field');
    } catch (e) {
      debugPrint('Error updating daily counter for $activity: $e');
      rethrow;
    }
  }
  
  // Reset all daily counters
  Future<void> resetDailyCounters(String uid, int newStreak, DateTime now) async {
    try {
      await _usersCollection.doc(uid).update({
        'dailySpinCount': 0,
        'dailyQuizCount': 0,
        'dailyDiceCount': 0,
        'dailyAdWatchCount': 0,
        'dailyMathPuzzleCount': 0,
        'dailyMemoryGameCount': 0,
        'dailyColorMatchCount': 0,
        'dailyWordGameCount': 0,
        'todayAdEarnings': 0,
        'streakCounter': newStreak,
        'lastActivityDate': Timestamp.fromDate(now),
      });
      debugPrint('FirestoreService: Successfully reset daily counters for user $uid');
    } catch (e) {
      debugPrint('Error resetting daily counters: $e');
      rethrow;
    }
  }
  
  // Process a withdrawal request
  Future<void> requestWithdrawal({
    required String userId,
    required int points,
    required double amount,
    required String method,
    required String accountNumber,
  }) async {
    try {
      // Validate minimum withdrawal amount
      if (points < AppConstants.minimumWithdrawalPoints) {
        throw Exception('Minimum withdrawal is ${AppConstants.minimumWithdrawalPoints} points (${AppConstants.minimumWithdrawalPoints * AppConstants.pointsToTakaRate} BDT)');
      }
      
      // Use a transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        // First, check if user has enough points
        DocumentSnapshot userDoc = await transaction.get(_usersCollection.doc(userId));
        
        if (!userDoc.exists) {
          throw Exception('User does not exist');
        }
        
        final userData = userDoc.data() as Map<String, dynamic>;
        final int currentPoints = userData['pointsBalance'] ?? 0;
        
        if (currentPoints < points) {
          throw Exception('Insufficient points balance');
        }
        
        // 1. Deduct points from user
        transaction.update(
          _usersCollection.doc(userId),
          {'pointsBalance': FieldValue.increment(-points)}
        );
        
        // 2. Create withdrawal request
        transaction.set(
          _withdrawalRequestsCollection.doc(),
          WithdrawalRequestModel(
            id: '', // Will be set by Firestore
            userId: userId,
            points: points,
            amount: amount,
            method: method,
            accountNumber: accountNumber,
            status: 'pending',
          ).toMap(),
        );
        
        // 3. Log the transaction
        transaction.set(
          _transactionsCollection.doc(),
          TransactionModel(
            id: '', // Will be set by Firestore
            userId: userId,
            type: 'withdrawal_request',
            points: -points, // Negative because points are deducted
            description: 'Withdrawal request for $amount BDT via $method',
          ).toMap(),
        );
      });
    } catch (e) {
      debugPrint('Error processing withdrawal request: $e');
      rethrow;
    }
  }
  
  // Get user's transaction history
  Future<List<TransactionModel>> getUserTransactions(String userId, {int limit = 10}) async {
    try {
      QuerySnapshot snapshot = await _transactionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => 
        TransactionModel.fromMap(
          doc.data() as Map<String, dynamic>, 
          doc.id
        )
      ).toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      rethrow;
    }
  }
  
  // Get user's withdrawal requests
  Future<List<WithdrawalRequestModel>> getUserWithdrawals(String userId, {int limit = 10}) async {
    try {
      QuerySnapshot snapshot = await _withdrawalRequestsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('requestDate', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => 
        WithdrawalRequestModel.fromMap(
          doc.data() as Map<String, dynamic>, 
          doc.id
        )
      ).toList();
    } catch (e) {
      debugPrint('Error getting withdrawal requests: $e');
      rethrow;
    }
  }
  
  // Check if a referral code exists and return the referrer's UID
  Future<String?> checkReferralCode(String referralCode) async {
    try {
      debugPrint('FirestoreService: Checking referral code: $referralCode');
      
      try {
        // First attempt - direct query with the updated security rules
        QuerySnapshot snapshot = await _usersCollection
            .where('referralCode', isEqualTo: referralCode)
            .limit(1)
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          String referrerId = snapshot.docs.first.id;
          debugPrint('FirestoreService: Referral code found, referrer ID: $referrerId');
          return referrerId;
        } else {
          debugPrint('FirestoreService: Referral code not found in Firestore');
          return null;
        }
      } catch (e) {
        // If the first approach fails with permission error, try using the fallback system
        debugPrint('FirestoreService: Error in primary referral check: $e');
        
        try {
          // Save the referral code to pending_referrals collection 
          // This collection has more permissive security rules
          await savePendingReferral(
            FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user', 
            referralCode
          );
          debugPrint('FirestoreService: Saved to pending referrals for later processing');
        } catch (savingError) {
          debugPrint('FirestoreService: Error saving pending referral: $savingError');
        }
        
        // Return null to indicate referral processing will happen later
        return null;
      }
    } catch (e) {
      debugPrint('FirestoreService: Unhandled error in checkReferralCode: $e');
      // Return null instead of rethrowing to prevent app crashes
      return null;
    }
  }
  
  // Update user profile information
  Future<void> updateUserProfile(UserModel user) async {
    try {
      debugPrint('FirestoreService: Updating profile for user ${user.uid}');
      
      await _usersCollection.doc(user.uid).update({
        'displayName': user.displayName,
        'phoneNumber': user.phoneNumber,
        'referredBy': user.referredBy,
        'photoURL': user.photoURL,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('FirestoreService: Profile updated successfully for ${user.uid}');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
  
  // Update ad earnings
  Future<void> updateAdEarnings(String uid, int earningsAmount) async {
    try {
      await _usersCollection.doc(uid).update({
        'lastAdEarnings': earningsAmount,
        'todayAdEarnings': FieldValue.increment(earningsAmount),
        'lastActivityDate': FieldValue.serverTimestamp(),
      });
      debugPrint('FirestoreService: Successfully updated ad earnings for user $uid: amount $earningsAmount');
    } catch (e) {
      debugPrint('Error updating ad earnings: $e');
      rethrow;
    }
  }
  
  // Track new referral by adding the new user to referrer's referredUsers array
  Future<void> addReferredUser(String referrerUid, String newUserUid, String newUserName) async {
    try {
      // Get current timestamp
      final timestamp = DateTime.now();
      
      // Add the new user to referrer's referredUsers array with timestamp and name
      await _usersCollection.doc(referrerUid).update({
        'referredUsers': FieldValue.arrayUnion([{
          'uid': newUserUid,
          'name': newUserName ?? 'User', 
          'timestamp': timestamp,
        }]),
      });
      
      debugPrint('FirestoreService: Successfully added user $newUserUid to $referrerUid referrals');
    } catch (e) {
      debugPrint('Error tracking referral: $e');
      rethrow;
    }
  }
  
  // Get referrer information
  Future<Map<String, dynamic>?> getReferrerInfo(String referrerUid) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(referrerUid).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'uid': doc.id,
          'displayName': data['displayName'] ?? 'User',
          'photoURL': data['photoURL'],
          'referralCode': data['referralCode'],
        };
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting referrer info: $e');
      rethrow;
    }
  }
  
  // Update referrer info for a user
  Future<void> updateReferrerInfo(String uid, Map<String, dynamic>? referrerInfo) async {
    try {
      if (referrerInfo == null) {
        return;
      }
      
      await _usersCollection.doc(uid).update({
        'referrerInfo': referrerInfo,
      });
      
      debugPrint('FirestoreService: Successfully updated referrer info for user $uid');
    } catch (e) {
      debugPrint('Error updating referrer info: $e');
      rethrow;
    }
  }
  
  // Process referral bonuses when a new user signs up with a referral code
  Future<void> processReferralBonus(String newUserUid, String referrerUid) async {
    try {
      debugPrint('FirestoreService: Processing referral bonus for referrer $referrerUid and new user $newUserUid');
      
      // Referral rewards from constants
      final int referrerPoints = GameConstants.referrerReward;  // 5000 points (5 BDT)
      final int newUserPoints = GameConstants.referredReward;   // 10000 points (10 BDT)
      
      // Use transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        // Award points to referrer
        transaction.update(
          _usersCollection.doc(referrerUid),
          {'pointsBalance': FieldValue.increment(referrerPoints)}
        );
        
        // Award points to new user
        transaction.update(
          _usersCollection.doc(newUserUid),
          {'pointsBalance': FieldValue.increment(newUserPoints)}
        );
        
        // Record transaction for referrer
        transaction.set(
          _transactionsCollection.doc(),
          {
            'userId': referrerUid,
            'type': TransactionTypes.earnReferral,
            'points': referrerPoints,
            'description': 'Bonus for referring a new user',
            'timestamp': FieldValue.serverTimestamp(),
          }
        );
        
        // Record transaction for new user
        transaction.set(
          _transactionsCollection.doc(),
          {
            'userId': newUserUid,
            'type': TransactionTypes.earnReferralBonus,
            'points': newUserPoints,
            'description': 'Bonus for registering with a referral code',
            'timestamp': FieldValue.serverTimestamp(),
          }
        );
      });
      
      debugPrint('FirestoreService: Successfully processed referral bonuses');
    } catch (e) {
      debugPrint('Error processing referral bonus: $e');
      rethrow;
    }
  }
  
  // Update user sign-in status
  Future<void> updateSignInStatus(String uid, bool isSignedIn) async {
    try {
      debugPrint('FirestoreService: Updating sign-in status for user $uid to $isSignedIn');
      
      await _usersCollection.doc(uid).update({
        'isSignedIn': isSignedIn,
        'lastLoginAt': isSignedIn ? FieldValue.serverTimestamp() : null,
      });
      
      debugPrint('FirestoreService: Sign-in status updated successfully');
    } catch (e) {
      debugPrint('Error updating sign-in status: $e');
      rethrow;
    }
  }

  // Update user's referredBy field directly
  Future<void> updateUserReferredBy(String uid, String referrerUid) async {
    try {
      debugPrint('FirestoreService: Updating referredBy for user $uid to $referrerUid');
      
      // Update the referredBy field
      await _usersCollection.doc(uid).update({
        'referredBy': referrerUid,
      });
      
      // Verify the update was successful
      DocumentSnapshot doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final String? storedReferrer = data['referredBy'];
        
        if (storedReferrer == referrerUid) {
          debugPrint('FirestoreService: Successfully updated referredBy field');
        } else {
          debugPrint('FirestoreService: Failed to update referredBy field, current value: $storedReferrer');
          // If update didn't take effect, try one more time
          await _usersCollection.doc(uid).update({
            'referredBy': referrerUid,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating referredBy: $e');
      rethrow;
    }
  }
  
  // Save a pending referral code for later admin verification
  Future<void> savePendingReferral(String userId, String referralCode) async {
    try {
      debugPrint('FirestoreService: Saving pending referral for $userId: $referralCode');
      
      // Create a separate collection for pending referrals that has more permissive security rules
      await _firestore.collection('pending_referrals').add({
        'userId': userId,
        'referralCode': referralCode,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'notes': 'Saved due to permission error during registration',
      });
      
      debugPrint('FirestoreService: Successfully saved pending referral');
    } catch (e) {
      debugPrint('Error saving pending referral: $e');
      // Don't rethrow - this is a fallback method so we want to continue even if it fails
      // Just log the error and continue
    }
  }
}