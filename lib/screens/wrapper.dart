import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/screens/auth_screen.dart';
import 'package:pocket_payout_bd/screens/home_screen.dart';
import 'package:pocket_payout_bd/services/auth_service.dart';
import 'package:pocket_payout_bd/services/firestore_service.dart';
import 'package:pocket_payout_bd/widgets/loading_animation.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  final AuthService _authService = AuthService();
  
  @override
  Widget build(BuildContext context) {
    // Listen to authentication state changes
    return StreamBuilder<User?>(
      stream: _authService.userChanges,
      builder: (context, snapshot) {
        // Show loading spinner while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        
        // Check if there's an authenticated user
        final User? firebaseUser = snapshot.data;
        
        if (firebaseUser == null) {
          // No authenticated user, show auth screen
          debugPrint("No authenticated user, showing auth screen");
          return const AuthScreen();
        } else {
          // User is authenticated, but may not have a Firestore profile
          debugPrint("User authenticated: ${firebaseUser.uid}");
          return _AuthenticatedUserRouter(firebaseUser: firebaseUser);
        }
      },
    );
  }
}

// Screen to show during loading states
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF04764E), // Dark green
              Color(0xFF068D5D), // Medium green
              Color(0xFF07A36C), // Light green
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoinLoadingAnimation(size: 90),
              SizedBox(height: 24),
              Text(
                'Loading your account...',
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Handles routing for authenticated users
class _AuthenticatedUserRouter extends StatefulWidget {
  final User firebaseUser;
  
  const _AuthenticatedUserRouter({super.key, required this.firebaseUser});
  
  @override
  State<_AuthenticatedUserRouter> createState() => _AuthenticatedUserRouterState();
}

class _AuthenticatedUserRouterState extends State<_AuthenticatedUserRouter> {
  late Future<Widget> _routeFuture;
  bool _isInitialLoad = true;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  
  @override
  void initState() {
    super.initState();
    // Initialize the route future in initState, not during build
    _routeFuture = _determineUserRoute();
  }
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _routeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        } else if (snapshot.hasError) {
          debugPrint("Error determining route: ${snapshot.error}");
          // Error handling - show a screen with retry option
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Error loading profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString().substring(0, 
                      snapshot.error.toString().length > 100 
                          ? 100 
                          : snapshot.error.toString().length),
                    style: const TextStyle(fontSize: 14, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _routeFuture = _determineUserRoute();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      await _authService.signOut();
                    },
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasData) {
          // Show the determined route
          return snapshot.data!;
        } else {
          // Default to home if something went wrong but no error
          return const HomeScreen();
        }
      },
    );
  }
  
  // Determine which screen to show based on user profile existence and completion
  Future<Widget> _determineUserRoute() async {
    // Get the UserProvider without listening to it
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    try {
      // Verify user is still authenticated
      if (_authService.currentUser == null) {
        debugPrint("User no longer authenticated, redirecting to auth screen");
        return const AuthScreen();
      }
      
      // Try to load the user's Firestore data
      debugPrint("Checking if user exists in Firestore: ${widget.firebaseUser.uid}");
      
      // This is where the issue happens - we need to delay any UI updates until after build
      // Use a Future.microtask to ensure we're not in the build phase
      await Future.microtask(() async {
        await userProvider.initUser(widget.firebaseUser.uid);
      });
      
      // Double check authentication state after data load
      if (_authService.currentUser == null) {
        debugPrint("User authentication state changed during data load");
        return const AuthScreen();
      }
      
      // If we get here, user exists in Firestore
      final userData = userProvider.user;
      
      if (userData == null) {
        debugPrint("User data is null after initialization, creating basic profile and sending to home");
        // Create a basic user profile automatically
        await Future.microtask(() async {
          await userProvider.createNewUser(
            widget.firebaseUser.uid,
            email: widget.firebaseUser.email,
            displayName: widget.firebaseUser.displayName ?? "User",
            phoneNumber: widget.firebaseUser.phoneNumber ?? "",
          );
        });
        _isInitialLoad = false;
        return const HomeScreen();
      }
      
      // Check if user is signed in - only update if this is the initial load
      if (userData.isSignedIn == false) {
        debugPrint("User is marked as signed out in database, updating sign-in status");
        // Update sign-in status to true for this new sign-in
        await _firestoreService.updateSignInStatus(widget.firebaseUser.uid, true);
        // Continue to home screen since this is a fresh login
        debugPrint("Sign-in status updated, sending user to home screen");
        _isInitialLoad = false;
        return const HomeScreen();
      }
      
      // Always route to home screen regardless of profile completion status
      debugPrint("Sending user directly to home screen");
      _isInitialLoad = false;
      return const HomeScreen();
    } catch (e) {
      debugPrint("Error in _determineUserRoute: $e");
      
      // First check if user is still authenticated
      if (_authService.currentUser == null) {
        debugPrint("Auth state changed during error handling, redirecting to auth");
        return const AuthScreen();
      }
      
      // Check if the error is because the user doesn't exist in Firestore
      // Also handle permission-denied errors which may occur during referral code validation
      if (e.toString().contains('permission-denied') || 
          e.toString().contains('does not exist') || 
          e.toString().contains('User does not exist')) {
        
        debugPrint("User doesn't exist in Firestore or encountered permission issues, creating basic profile and sending to home");
        // Create a basic user profile and send to home screen
        try {
          // Check if the user already exists in Provider (might have been partially loaded)
          if (userProvider.user != null) {
            debugPrint("User object exists in Provider, proceeding to home screen");
            _isInitialLoad = false;
            return const HomeScreen();
          }
          
          // Otherwise create new user
          await userProvider.createNewUser(
            widget.firebaseUser.uid,
            email: widget.firebaseUser.email,
            displayName: widget.firebaseUser.displayName ?? "User",
            phoneNumber: widget.firebaseUser.phoneNumber ?? "",
          );
          _isInitialLoad = false;
          return const HomeScreen();
        } catch (createError) {
          debugPrint("Error creating basic user profile: $createError");
          // If we still fail to create the user, try one more approach
          if (createError.toString().contains('permission-denied')) {
            debugPrint("Permission error during user creation, forcing navigation to home screen");
            _isInitialLoad = false;
            return const HomeScreen();
          }
          rethrow;
        }
      } else {
        // For unexpected errors, rethrow to be handled by FutureBuilder
        debugPrint("Unexpected error: $e");
        rethrow;
      }
    }
  }
}