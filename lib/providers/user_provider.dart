import 'package:flutter/foundation.dart';
import 'package:pocket_payout_bd/models/user_model.dart';
import 'package:pocket_payout_bd/services/firestore_service.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  int get points => _user?.pointsBalance ?? 0;
  int get streakCount => _user?.streakCounter ?? 0;
  
  // Initialize user data
  Future<void> initUser(String uid) async {
    // If we already have the user with the same ID and it's signed in, skip reloading
    if (_user != null && _user!.uid == uid && _user!.isSignedIn) {
      debugPrint("UserProvider: User $uid already initialized and signed in, skipping reload");
      return;
    }
    
    setLoading(true);
    try {
      debugPrint("UserProvider: Initializing user $uid from Firestore");
      _user = await _firestoreService.getUserData(uid);
      
      // Update sign-in status to true whenever user data is loaded
      if (_user != null && !_user!.isSignedIn) {
        await _firestoreService.updateSignInStatus(uid, true);
        // Update local model
        _user = _user!.copyWith(isSignedIn: true);
      }
      
      debugPrint("UserProvider: Successfully loaded user data for $uid");
      
      // Check if day changed to reset daily counters and update streak
      await _checkAndUpdateDaily(uid);
      
      notifyListeners();
    } catch (e) {
      debugPrint('UserProvider: Error initializing user: $e');
      // Clear user data on error to ensure a clean state
      _user = null;
      notifyListeners();
      rethrow; // Re-throw to allow wrapper to handle appropriately
    } finally {
      setLoading(false);
    }
  }
  
  // Create new user on signup
  Future<void> createNewUser(
    String uid, {
    String? email,
    String? displayName,
    String? phoneNumber,
    String? referredBy,
  }) async {
    try {
      debugPrint("UserProvider: Creating new user in Firestore for $uid");
      debugPrint("UserProvider: Referral info - referredBy: $referredBy");
      setLoading(true);
      
      final DateTime now = DateTime.now();
      await _firestoreService.createUser(
        UserModel(
          uid: uid,
          email: email,
          displayName: displayName,
          phoneNumber: phoneNumber,
          referredBy: referredBy,
          createdAt: now,
          lastLoginAt: now,
        )
      );
      
      // Double-check if the referredBy field was set correctly
      if (referredBy != null) {
        debugPrint("UserProvider: Verifying referredBy field was set properly");
        try {
          final userData = await _firestoreService.getUserData(uid);
          if (userData.referredBy != referredBy) {
            debugPrint("UserProvider: referredBy field not set correctly, updating directly");
            await _firestoreService.updateUserReferredBy(uid, referredBy);
          } else {
            debugPrint("UserProvider: referredBy field set correctly");
          }
        } catch (e) {
          debugPrint("UserProvider: Error verifying referredBy field: $e");
        }
      }
      
      debugPrint("UserProvider: User created successfully. Loading user data.");
      // Load the newly created user
      await initUser(uid);
      debugPrint("UserProvider: New user initialized successfully");
    } catch (e) {
      debugPrint('UserProvider: Error creating new user: $e');
      // Clear user data on error to ensure a clean state
      _user = null;
      notifyListeners();
      rethrow; // Re-throw for UI to handle
    } finally {
      setLoading(false);
    }
  }
  
  // Update user profile information
  Future<void> updateUserProfile({
    String? displayName, 
    String? phoneNumber,
    String? referredBy,
    String? photoURL,
  }) async {
    if (_user == null) return;
    
    try {
      debugPrint("UserProvider: Updating profile for ${_user!.uid}");
      setLoading(true);
      
      // Create updated user model
      final updatedUser = _user!.copyWith(
        displayName: displayName ?? _user!.displayName,
        phoneNumber: phoneNumber ?? _user!.phoneNumber,
        referredBy: referredBy ?? _user!.referredBy,
        photoURL: photoURL ?? _user!.photoURL,
      );
      
      // Update in Firestore
      await _firestoreService.updateUserProfile(updatedUser);
      
      // Update local model
      _user = updatedUser;
      
      notifyListeners();
      debugPrint("UserProvider: Profile updated successfully");
    } catch (e) {
      debugPrint('UserProvider: Error updating profile: $e');
      rethrow; // Re-throw for UI to handle
    } finally {
      setLoading(false);
    }
  }
  
  // Update user points
  Future<void> updatePoints(int points, String type, {String? description}) async {
    if (_user == null) return;
    
    try {
      // Update user points in Firestore
      await _firestoreService.updateUserPoints(_user!.uid, points, type, description: description);
      
      // Update local user object
      _user = _user!.copyWith(
        pointsBalance: _user!.pointsBalance + points,
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating points: $e');
    }
  }
  
  // Update daily activity counters
  Future<void> incrementDailyCounter(String activity) async {
    if (_user == null) return;
    
    int? newCount;
    switch (activity) {
      case 'spin':
        newCount = _user!.dailySpinCount + 1;
        _user = _user!.copyWith(dailySpinCount: newCount);
        break;
      case 'dice':
        newCount = _user!.dailyDiceCount + 1;
        _user = _user!.copyWith(dailyDiceCount: newCount);
        break;
      case 'ad_watch':
        newCount = _user!.dailyAdWatchCount + 1;
        _user = _user!.copyWith(dailyAdWatchCount: newCount);
        break;
      case 'math_puzzle':
        newCount = _user!.dailyMathPuzzleCount + 1;
        _user = _user!.copyWith(dailyMathPuzzleCount: newCount);
        break;
      case 'memory_game':
        newCount = _user!.dailyMemoryGameCount + 1;
        _user = _user!.copyWith(dailyMemoryGameCount: newCount);
        break;
      case 'color_match':
        newCount = _user!.dailyColorMatchCount + 1;
        _user = _user!.copyWith(dailyColorMatchCount: newCount);
        break;
      case 'word_game':
        newCount = _user!.dailyWordGameCount + 1;
        _user = _user!.copyWith(dailyWordGameCount: newCount);
        break;
    }
    
    if (newCount != null) {
      await _firestoreService.updateDailyCounter(_user!.uid, activity, newCount);
      notifyListeners();
    }
  }
  
  // Update ad earnings
  Future<void> updateAdEarnings(int earningsAmount) async {
    if (_user == null) return;
    
    try {
      // Update in Firestore
      await _firestoreService.updateAdEarnings(_user!.uid, earningsAmount);
      
      // Update local user object
      _user = _user!.copyWith(
        lastAdEarnings: earningsAmount,
        todayAdEarnings: _user!.todayAdEarnings + earningsAmount,
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating ad earnings: $e');
    }
  }
  
  // Check if the day has changed and reset daily counters if needed
  Future<void> _checkAndUpdateDaily(String uid) async {
    if (_user == null) return;
    
    final DateTime now = DateTime.now();
    final DateTime lastActivity = _user!.lastActivityDate;
    
    // Check if last activity was on a different day
    if (lastActivity.day != now.day || 
        lastActivity.month != now.month || 
        lastActivity.year != now.year) {
      
      // Calculate streak
      final difference = now.difference(lastActivity).inDays;
      int newStreak = 0;
      
      // If consecutive day, increment streak, otherwise reset
      if (difference == 1) {
        newStreak = _user!.streakCounter + 1;
      } else {
        newStreak = 1; // Reset streak but count today
      }
      
      // Reset daily counters and update streak/last activity
      await _firestoreService.resetDailyCounters(uid, newStreak, now);
      
      // Update local user model
      _user = _user!.copyWith(
        dailySpinCount: 0,
        dailyDiceCount: 0,
        dailyAdWatchCount: 0, // Reset ad watch count
        todayAdEarnings: 0,  // Reset today's ad earnings
        streakCounter: newStreak,
        lastActivityDate: now,
      );
    }
  }
  
  // Clear user data on sign out
  Future<void> clearUser() async {
    debugPrint('UserProvider: Clearing user data');
    
    // Update sign-in status in Firestore if user exists
    if (_user != null) {
      try {
        // Only update sign-in status if user is currently signed in
        if (_user!.isSignedIn) {
          await _firestoreService.updateSignInStatus(_user!.uid, false);
          debugPrint('UserProvider: Updated sign-in status to false');
        } else {
          debugPrint('UserProvider: User already marked as signed out, skipping update');
        }
      } catch (e) {
        debugPrint('Error updating sign-in status: $e');
        // Continue with logout even if update fails
      }
    }
    
    // Clear local data
    _user = null;
    _isLoading = false;
    
    // Add additional cleanup if needed
    // For example, cancel any active timers or subscriptions
    
    notifyListeners();
    debugPrint('UserProvider: User data cleared successfully');
  }
  
  // Helper method to set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Add points to user's balance
  Future<void> addPoints(int amount) async {
    if (_user == null) return;
    
    try {
      // Update user points in Firestore
      await _firestoreService.updateUserPoints(
        _user!.uid, 
        amount, 
        TransactionTypes.earnMathPuzzle,
        description: 'Earned from Math Puzzle game'
      );
      
      // Update local user object
      _user = _user!.copyWith(
        pointsBalance: _user!.pointsBalance + amount,
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding points: $e');
    }
  }
  
  // Update math puzzle plays counter
  Future<void> updateMathPuzzlePlays() async {
    await incrementDailyCounter('math_puzzle');
  }
}