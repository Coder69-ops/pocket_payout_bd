import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:scratcher/scratcher.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class ScratchCardScreen extends StatefulWidget {
  const ScratchCardScreen({Key? key}) : super(key: key);

  @override
  State<ScratchCardScreen> createState() => _ScratchCardScreenState();
}

class _ScratchCardScreenState extends State<ScratchCardScreen> {
  static const List<int> _rewards = [50, 100, 200, 500, 1000];
  static const int _maxDailyScratches = 5;
  
  RewardedAd? _rewardedAd;
  bool _isLoading = true;
  bool _isScratching = false;
  bool _isRevealed = false;
  int _remainingScratches = _maxDailyScratches;
  late int _currentReward;
  final _scratchKey = GlobalKey<ScratcherState>();

  @override
  void initState() {
    super.initState();
    _loadAd();
    _initializeScratchCount();
    _generateReward();
  }

  Future<void> _initializeScratchCount() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      setState(() {
        _remainingScratches = _maxDailyScratches - user.dailyScratchCount;
        _isLoading = false;
      });
    }
  }

  void _generateReward() {
    final random = Random();
    final roll = random.nextInt(100);
    
    // Probability distribution
    if (roll < 40) {
      _currentReward = _rewards[0]; // 50 points - 40%
    } else if (roll < 70) {
      _currentReward = _rewards[1]; // 100 points - 30%
    } else if (roll < 85) {
      _currentReward = _rewards[2]; // 200 points - 15%
    } else if (roll < 95) {
      _currentReward = _rewards[3]; // 500 points - 10%
    } else {
      _currentReward = _rewards[4]; // 1000 points - 5%
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

  void _startNewCard() {
    setState(() {
      _isRevealed = false;
      _isScratching = false;
    });
    _generateReward();
    if (_scratchKey.currentState != null) {
      _scratchKey.currentState!.reset();
    }
  }

  Future<void> _onScratchComplete() async {
    if (_isRevealed) return;
    
    setState(() {
      _isRevealed = true;
    });

    // Show ad then award points
    if (_rewardedAd == null) {
      _processReward();
    } else {
      _rewardedAd?.show(
        onUserEarnedReward: (ad, reward) => _processReward(),
      );
    }
  }

  Future<void> _processReward() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      await userProvider.updatePoints(
        _currentReward,
        TransactionTypes.earnScratch,
        description: 'Won from Scratch Card',
      );
      
      await userProvider.incrementDailyCounter('scratch');
      
      setState(() {
        _remainingScratches--;
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Congratulations! 🎉'),
            content: Text('You won $_currentReward points!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (_remainingScratches > 0) {
                    _startNewCard();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(_remainingScratches > 0 ? 'Play Again' : 'Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
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
        title: const Text('Scratch Card'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _remainingScratches <= 0
              ? const Center(
                  child: Text('No scratches remaining today. Come back tomorrow!'),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Remaining Scratches: $_remainingScratches',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 300,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Scratcher(
                            key: _scratchKey,
                            brushSize: 30,
                            threshold: 50,
                            color: Colors.grey,
                            onChange: (value) {
                              if (!_isScratching) {
                                setState(() {
                                  _isScratching = true;
                                });
                              }
                            },
                            onThreshold: _onScratchComplete,
                            child: Container(
                              color: Colors.white,
                              child: Center(
                                child: Text(
                                  '$_currentReward\nPOINTS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: _currentReward >= 500
                                        ? Colors.orange
                                        : Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!_isScratching)
                        const Text(
                          'Scratch the card to reveal your prize!',
                          style: TextStyle(fontSize: 16),
                        ),
                    ],
                  ),
                ),
    );
  }
}