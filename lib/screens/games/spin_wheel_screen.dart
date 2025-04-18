import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/widgets/banner_ad_widget.dart';
import 'package:confetti/confetti.dart';
import 'package:rxdart/rxdart.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({Key? key}) : super(key: key);

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen> with SingleTickerProviderStateMixin {
  static const List<int> _rewards = [60, 120, 240, 360, 600, 1200];
  static const List<Color> _wheelColors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];
  
  late AnimationController _spinButtonController;
  late Animation<double> _spinButtonAnimation;
  late final ConfettiController _confettiController;
  
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isLoading = true;
  bool _isSpinning = false;
  bool _isAdLoading = false;
  bool _isInterstitialAdLoading = false;
  int _remainingSpins = 0;
  int _maxDailySpins = 5;
  int _selectedValue = 0;
  int _lastWonAmount = 0;
  int _streakCount = 0;
  late final StreamController<int> _controller = StreamController<int>.broadcast();

  @override
  void initState() {
    super.initState();
    _checkRemainingSpins();
    _loadAd();
    _loadInterstitialAd();
    _controller.add(_selectedValue);
    
    // Initialize animation controller for spin button
    _spinButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _spinButtonAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _spinButtonController, curve: Curves.easeInOut),
    );
    
    // Initialize confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  Future<void> _checkRemainingSpins() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      setState(() {
        _maxDailySpins = user.maxDailySpins;
        _remainingSpins = _maxDailySpins - user.dailySpinCount;
        _streakCount = user.streakCounter;
        _isLoading = false;
      });
    }
  }

  void _loadAd() {
    setState(() {
      _isAdLoading = true;
    });
    
    RewardedAd.load(
      adUnitId: AppConstants.rewardedAdUnitId, // Use constants instead of hardcoded values
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoading = false;
          });
        },
        onAdFailedToLoad: (error) {
          setState(() {
            _isAdLoading = false;
          });
          debugPrint('Failed to load rewarded ad: $error');
        },
      ),
    );
  }

  void _loadInterstitialAd() {
    setState(() {
      _isInterstitialAdLoading = true;
    });
    
    InterstitialAd.load(
      adUnitId: AppConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _interstitialAd = ad;
            _isInterstitialAdLoading = false;
          });
          
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Interstitial ad failed to show: $error');
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdShowedFullScreenContent: (ad) {
              debugPrint('Interstitial ad showed fullscreen content');
            },
          );
        },
        onAdFailedToLoad: (error) {
          setState(() {
            _isInterstitialAdLoading = false;
          });
          debugPrint('Failed to load interstitial ad: $error');
          
          // Retry loading after a delay
          Future.delayed(const Duration(minutes: 1), () {
            if (mounted) {
              _loadInterstitialAd();
            }
          });
        },
      ),
    );
  }

  Future<void> _spin() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _selectedValue = Random().nextInt(_rewards.length);
    });
    _controller.add(_selectedValue);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Wait for animation
      await Future.delayed(const Duration(seconds: 3));
      
      // Get base points
      final basePoints = _rewards[_selectedValue];
      
      // Apply streak multiplier
      final streakMultiplier = GameConstants.getStreakMultiplier(_streakCount);
      final adjustedPoints = (basePoints * streakMultiplier).round();
      
      // Award points
      _lastWonAmount = adjustedPoints;
      await userProvider.updatePoints(
        adjustedPoints,
        'earn_spin',
        description: 'Earned from Spin Wheel',
      );
      
      // Update daily spin count
      await userProvider.incrementDailyCounter('spin');
      
      setState(() {
        _remainingSpins = _maxDailySpins - (userProvider.user?.dailySpinCount ?? 0);
        _isSpinning = false;
      });

      if (mounted) {
        // Play confetti animation
        _confettiController.play();
        
        // Show reward dialog
        await showDialog(
          context: context,
          builder: (context) => _buildRewardDialog(adjustedPoints, basePoints, streakMultiplier),
        );
        
        // Show interstitial ad after spin completes
        _showInterstitialAd();
      }
    } catch (e) {
      setState(() {
        _isSpinning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      debugPrint('Interstitial ad not ready');
      return;
    }
    
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  Future<void> _watchAdForSpin() async {
    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready. Please try again.')),
      );
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        setState(() {
          _remainingSpins++;
        });
      },
    );

    _rewardedAd = null;
    _loadAd();
  }

  Widget _buildRewardDialog(int points, int basePoints, double streakMultiplier) {
    final bool hasStreakBonus = streakMultiplier > 1.0;
    
    return AlertDialog(
      title: const Text('Congratulations! 🎉', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 50),
          const SizedBox(height: 16),
          Text(
            'You won $points points!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Show streak bonus if active
          if (hasStreakBonus) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_streakCount Day Streak: ${streakMultiplier}x',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Base: $basePoints × Streak: ${streakMultiplier}x = $points',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 8),
          Text(
            'You have $_remainingSpins spins left today',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            _remainingSpins > 0 ? 'CONTINUE' : 'CLOSE',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.close();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _spinButtonController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spin & Win'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Main content
                Expanded(
                  child: Stack(
                    children: [
                      // Background gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.primaryColor.withOpacity(0.05),
                              Colors.white,
                            ],
                          ),
                        ),
                      ),
                      
                      // Main content
                      Column(
                        children: [
                          // Top info card
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.rotate_right,
                                        color: theme.primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Remaining Spins',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '$_remainingSpins / $_maxDailySpins',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: _remainingSpins > 0 ? Colors.black : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_lastWonAmount > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.monetization_on,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '+$_lastWonAmount',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Wheel container
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer decoration
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Wheel
                                  FortuneWheel(
                                    selected: _controller.stream,
                                    animateFirst: false,
                                    physics: CircularPanPhysics(
                                      duration: const Duration(seconds: 1, milliseconds: 500),
                                      curve: Curves.decelerate,
                                    ),
                                    onAnimationEnd: () {
                                      setState(() {
                                        _isSpinning = false;
                                      });
                                    },
                                    indicators: const [
                                      FortuneIndicator(
                                        alignment: Alignment.topCenter,
                                        child: TriangleIndicator(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                    styleStrategy: UniformStyleStrategy(
                                      borderColor: Colors.white,
                                      borderWidth: 3,
                                      textAlign: TextAlign.center,
                                      textStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                    items: List.generate(_rewards.length, (index) {
                                      return FortuneItem(
                                        style: FortuneItemStyle(
                                          color: _wheelColors[index],
                                          borderColor: Colors.white,
                                          borderWidth: 2,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 30.0),
                                          child: Text(
                                            '${_rewards[index]}\npts',
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  
                                  // Center decoration
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.rotate_right,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Buttons
                          Container(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                AnimatedBuilder(
                                  animation: _spinButtonController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _remainingSpins > 0 && !_isSpinning ? _spinButtonAnimation.value : 1.0,
                                      child: child,
                                    );
                                  },
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _remainingSpins > 0 && !_isSpinning
                                          ? _spin
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                        elevation: 5,
                                      ),
                                      child: const Text(
                                        'SPIN NOW',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_remainingSpins <= 0) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton.icon(
                                      onPressed: (_rewardedAd != null && !_isAdLoading) ? _watchAdForSpin : null,
                                      icon: _isAdLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.videocam),
                                      label: const Text('Watch Ad for Extra Spin'),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Confetti effect
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirection: pi / 2,
                          maxBlastForce: 5,
                          minBlastForce: 1,
                          emissionFrequency: 0.05,
                          numberOfParticles: 20,
                          gravity: 0.1,
                          shouldLoop: false,
                          colors: const [
                            Colors.green,
                            Colors.blue,
                            Colors.pink,
                            Colors.orange,
                            Colors.purple,
                            Colors.red,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Banner ad at the bottom
                const BannerAdWidget(),
              ],
            ),
    );
  }
}