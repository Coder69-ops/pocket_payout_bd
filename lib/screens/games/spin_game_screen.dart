import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';

class SpinGameScreen extends StatefulWidget {
  const SpinGameScreen({Key? key}) : super(key: key);

  @override
  State<SpinGameScreen> createState() => _SpinGameScreenState();
}

class _SpinGameScreenState extends State<SpinGameScreen> {
  static const int _maxDailySpins = 5;
  static const List<SpinReward> _rewards = [
    SpinReward(points: 20, probability: 30),
    SpinReward(points: 40, probability: 25),
    SpinReward(points: 80, probability: 20),
    SpinReward(points: 200, probability: 15),
    SpinReward(points: 400, probability: 9),
    SpinReward(points: 800, probability: 1),
  ];

  RewardedAd? _rewardedAd;
  bool _isLoading = true;
  bool _isSpinning = false;
  int _selectedReward = 0;
  int _remainingSpins = _maxDailySpins;

  @override
  void initState() {
    super.initState();
    _loadAd();
    _initializeSpinCount();
  }

  Future<void> _initializeSpinCount() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      setState(() {
        _remainingSpins = _maxDailySpins - user.dailySpinCount;
        _isLoading = false;
      });
    }
  }

  void _loadAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ad unit ID
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
          break;
        }
      }

      // Update points and spin count
      await userProvider.updatePoints(
        _rewards[_selectedReward].points,
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Congratulations! 🎉'),
            content: Text('You won ${_rewards[_selectedReward].points} points!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
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

  @override
  void dispose() {
    _rewardedAd?.dispose();
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
                    selected: _selectedReward,
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

class SpinReward {
  final int points;
  final int probability;

  const SpinReward({
    required this.points,
    required this.probability,
  });
}