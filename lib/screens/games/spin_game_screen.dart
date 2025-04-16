import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/models/spin_reward.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class SpinGameScreen extends StatefulWidget {
  const SpinGameScreen({Key? key}) : super(key: key);

  @override
  State<SpinGameScreen> createState() => _SpinGameScreenState();
}

class _SpinGameScreenState extends State<SpinGameScreen> {
  static const List<SpinReward> _rewards = [
    SpinReward(points: 150, probability: 30),
    SpinReward(points: 300, probability: 25),
    SpinReward(points: 600, probability: 20),
    SpinReward(points: 1500, probability: 15),
    SpinReward(points: 3000, probability: 9),
    SpinReward(points: 6000, probability: 1),
  ];

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isLoading = true;
  bool _isSpinning = false;
  int _selectedReward = 0;
  int _streakCount = 0;
  late final StreamController<int> _controller = StreamController<int>.broadcast();
  int _remainingSpins = AppConstants.maxDailySpins;

  @override
  void initState() {
    super.initState();
    _loadAd();
    _loadInterstitialAd();
    _initializeSpinCount();
    _controller.add(_selectedReward);
  }

  Future<void> _initializeSpinCount() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      setState(() {
        _remainingSpins = AppConstants.maxDailySpins - user.dailySpinCount;
        _streakCount = user.streakCounter;
        _isLoading = false;
      });
    }
  }

  void _loadAd() {
    RewardedAd.load(
      adUnitId: AppConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
          });
          
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Failed to load rewarded ad: ${error.message}');
        },
      ),
    );
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AppConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          
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
          debugPrint('Failed to load interstitial ad: ${error.message}');
          
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
    if (_remainingSpins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No spins remaining today. Come back tomorrow!')),
      );
      return;
    }

    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready. Please try again.')),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
    });

    // Show rewarded ad
    _rewardedAd?.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _processSpinReward();
      },
    );
  }

  Future<void> _processSpinReward() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final Random random = Random();
      int totalProbability = _rewards.fold(0, (sum, reward) => sum + reward.probability);
      int randomValue = random.nextInt(totalProbability);
      
      int cumulativeProbability = 0;
      for (int i = 0; i < _rewards.length; i++) {
        cumulativeProbability += _rewards[i].probability;
        if (randomValue < cumulativeProbability) {
          setState(() {
            _selectedReward = i;
          });
          _controller.add(i);
          break;
        }
      }

      // Get base points
      final int basePoints = _rewards[_selectedReward].points;
      
      // Apply streak multiplier
      final double streakMultiplier = GameConstants.getStreakMultiplier(_streakCount);
      final int finalPoints = (basePoints * streakMultiplier).round();

      // Update points and spin count
      await userProvider.updatePoints(
        finalPoints,
        'earn_spin',
        description: 'Won from Spin & Win game',
      );
      
      await userProvider.incrementDailyCounter('spin');
      
      setState(() {
        _remainingSpins--;
        _isSpinning = false;
      });

      // Show reward dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => _buildRewardDialog(finalPoints, basePoints, streakMultiplier),
        );
        
        // Show interstitial ad after dialog is closed
        _showInterstitialAd();
      }
    } catch (e) {
      setState(() {
        _isSpinning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
  
  Widget _buildRewardDialog(int finalPoints, int basePoints, double streakMultiplier) {
    final bool hasStreakBonus = streakMultiplier > 1.0;
    
    return AlertDialog(
      title: const Text('Congratulations! 🎉'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You won $finalPoints points!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          
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
              'Base: $basePoints × Streak: ${streakMultiplier}x = $finalPoints',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 8),
          Text(
            'Remaining spins today: $_remainingSpins',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      debugPrint('Interstitial ad not ready');
      return;
    }
    
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  @override
  void dispose() {
    _controller.close();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spin & Win'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Spin the wheel to win points!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Remaining Spins Today: $_remainingSpins',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: FortuneWheel(
                    selected: _controller.stream,
                    animateFirst: false,
                    physics: CircularPanPhysics(
                      duration: const Duration(seconds: 1),
                      curve: Curves.decelerate,
                    ),
                    onFling: () {
                      if (!_isSpinning && _remainingSpins > 0) {
                        _spin();
                      }
                    },
                    indicators: const [
                      FortuneIndicator(
                        alignment: Alignment.topCenter,
                        child: TriangleIndicator(),
                      ),
                    ],
                    items: _rewards.map((reward) {
                      return FortuneItem(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '${reward.points}\nPoints',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        style: FortuneItemStyle(
                          color: reward.points >= 1000 
                              ? Colors.orange 
                              : Colors.blue.shade200,
                          borderWidth: 3,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSpinning || _remainingSpins <= 0 ? null : _spin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text(_isSpinning ? 'Spinning...' : 'SPIN!'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}