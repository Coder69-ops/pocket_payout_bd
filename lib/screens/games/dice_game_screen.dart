import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/services/firestore_service.dart';
import 'package:pocket_payout_bd/services/ad_service.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:pocket_payout_bd/widgets/banner_ad_widget.dart';

class DiceGameScreen extends StatefulWidget {
  const DiceGameScreen({Key? key}) : super(key: key);

  @override
  State<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends State<DiceGameScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final AdService _adService = AdService();
  final Random _random = Random();
  
  // Animation controller for dice roll
  late AnimationController _controller;
  
  // Game state variables
  bool _isLoading = false;
  bool _isRolling = false;
  bool _canPlay = true;
  int _remainingRolls = 0;
  int _dailyDiceLimit = 5; // Maximum dice rolls per day
  String? _errorMessage;
  
  // Dice values and points
  int _dice1Value = 1;
  int _dice2Value = 1;
  int _rewardPoints = 0;
  
  // Game tracking
  int _consecutiveRolls = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // When animation completes, award points
        _calculateReward();
      }
    });
    
    _checkRemainingRolls();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  // Check how many dice rolls the user has left for today
  Future<void> _checkRemainingRolls() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      setState(() {
        _remainingRolls = _dailyDiceLimit - user.dailyDiceCount;
        _canPlay = _remainingRolls > 0;
      });
    }
  }
  
  // Roll the dice with ad
  void _rollDiceWithAd() {
    if (!_canPlay) {
      setState(() {
        _errorMessage = 'You\'ve reached your daily dice roll limit. Come back tomorrow!';
      });
      return;
    }
    
    setState(() {
      _errorMessage = null;
    });
    
    // This being the first roll or after a break
    if (_consecutiveRolls == 0) {
      _rollDice();
      return;
    }
    
    // Show interstitial ad every 3 rolls
    if (_consecutiveRolls % 2 == 0 && _adService.isInterstitialAdAvailable) {
      _adService.showInterstitialAd(
        onAdDismissed: () {
          // Roll dice after the ad is dismissed
          _rollDice();
        },
      );
    } else {
      // Just roll the dice without showing an ad
      _rollDice();
    }
  }
  
  // Roll the dice
  void _rollDice() {
    setState(() {
      _isRolling = true;
    });
    
    // Reset the animation controller
    _controller.reset();
    
    // Start the animation
    _controller.forward();
    
    // Animate the dice using timer
    int animationSteps = 10;
    int stepDuration = 50;
    
    for (int i = 0; i < animationSteps; i++) {
      Future.delayed(Duration(milliseconds: i * stepDuration), () {
        if (mounted && _isRolling) {
          setState(() {
            _dice1Value = _random.nextInt(6) + 1;
            _dice2Value = _random.nextInt(6) + 1;
          });
        }
      });
    }
    
    // Final values will be set when the animation completes
    Future.delayed(Duration(milliseconds: _controller.duration!.inMilliseconds), () {
      if (mounted && _isRolling) {
        setState(() {
          _dice1Value = _random.nextInt(6) + 1;
          _dice2Value = _random.nextInt(6) + 1;
          _isRolling = false;
          _consecutiveRolls++; // Increment consecutive rolls count
        });
      }
    });
  }
  
  // Calculate reward based on dice values
  void _calculateReward() {
    int sum = _dice1Value + _dice2Value;
    
    // Determine points based on dice sum
    if (sum == 2) {
      _rewardPoints = 50; // Snake eyes (two 1s)
    } else if (sum == 12) {
      _rewardPoints = 500; // Two 6s (highest)
    } else if (_dice1Value == _dice2Value) {
      _rewardPoints = sum * 25; // Doubles
    } else if (sum == 7 || sum == 11) {
      _rewardPoints = 200; // Lucky numbers
    } else {
      _rewardPoints = sum * 10; // Regular roll
    }
    
    // Award points
    _awardPoints();
  }
  
  // Award points based on dice roll
  Future<void> _awardPoints() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      
      if (user == null) {
        setState(() {
          _errorMessage = 'User data not available';
          _isLoading = false;
        });
        return;
      }
      
      // Update daily dice count
      await userProvider.incrementDailyCounter('dice');
      
      // Award points to the user
      await userProvider.updatePoints(
        _rewardPoints,
        'earn_dice',
        description: 'Earned from Dice Roll (${_dice1Value}+${_dice2Value})',
      );
      
      setState(() {
        _remainingRolls = _dailyDiceLimit - (user.dailyDiceCount + 1);
        _canPlay = _remainingRolls > 0;
        _isLoading = false;
      });
      
      // Show reward dialog
      _showRewardDialog();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error awarding points: $e';
        _isLoading = false;
      });
    }
  }
  
  // Show a dialog with the earned points
  void _showRewardDialog() {
    String message = '';
    IconData icon;
    Color color;
    
    int sum = _dice1Value + _dice2Value;
    
    // Determine message and icon based on roll result
    if (sum == 2) {
      message = 'Snake Eyes! Not bad!';
      icon = Icons.pets;
      color = Colors.red;
    } else if (sum == 12) {
      message = 'Double Sixes! Amazing roll!';
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (_dice1Value == _dice2Value) {
      message = 'Doubles! Nice roll!';
      icon = Icons.stars;
      color = Colors.blue;
    } else if (sum == 7 || sum == 11) {
      message = 'Lucky Number! Great roll!';
      icon = Icons.thumb_up;
      color = Colors.green;
    } else {
      message = 'Good roll!';
      icon = Icons.check_circle;
      color = Colors.purple;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('You Rolled ${_dice1Value + _dice2Value}!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You won $_rewardPoints points!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have $_remainingRolls rolls left today',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          if (_remainingRolls > 0) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _consecutiveRolls = 0; // Reset consecutive rolls when exiting
                });
              },
              child: const Text('Exit Game'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rollDiceWithAd();
              },
              child: const Text('Roll Again'),
            ),
          ] else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
  
  // Build a dice widget
  Widget _buildDice(int value) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double scale = 1.0;
            if (_isRolling) {
              // Create a bouncing effect
              final double value = _controller.value;
              scale = 1.0 + sin(value * pi * 2) * 0.2;
            }
            
            return Transform.scale(
              scale: scale,
              child: _getDiceFace(value),
            );
          },
        ),
      ),
    );
  }
  
  // Get the dice face widget based on value
  Widget _getDiceFace(int value) {
    switch (value) {
      case 1:
        return _buildDiceFace([4]);
      case 2:
        return _buildDiceFace([0, 8]);
      case 3:
        return _buildDiceFace([0, 4, 8]);
      case 4:
        return _buildDiceFace([0, 2, 6, 8]);
      case 5:
        return _buildDiceFace([0, 2, 4, 6, 8]);
      case 6:
        return _buildDiceFace([0, 2, 3, 5, 6, 8]);
      default:
        return _buildDiceFace([4]);
    }
  }
  
  // Build dice face with dots
  Widget _buildDiceFace(List<int> dotPositions) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          if (dotPositions.contains(index)) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                shape: BoxShape.circle,
              ),
            );
          }
          return Container();
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Roll'),
      ),
      body: Column(
        children: [
          // Main content in a scrollable area
          Expanded(
            child: Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Top info card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your Points',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '${userProvider.points}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Rolls Left Today',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '$_remainingRolls',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: _remainingRolls > 0 ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Error message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Loading indicator
                        if (_isLoading) ...[
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Instructions or limit reached message
                        if (!_canPlay) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 50,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Daily Limit Reached',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'You\'ve used all your dice rolls for today. Come back tomorrow for more!',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Go Back'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Roll the dice and win points based on your roll!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Dice display
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDice(_dice1Value),
                              _buildDice(_dice2Value),
                            ],
                          ),
                          const SizedBox(height: 32),
                          
                          // Total display
                          if (_isRolling) ...[
                            const Text(
                              'Rolling...',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Total: ${_dice1Value + _dice2Value}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          
                          // Roll button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: (_isRolling || _isLoading) ? null : _rollDiceWithAd,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.blue,
                              ),
                              icon: const Icon(Icons.casino),
                              label: const Text('ROLL DICE'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Watch a short ad to roll the dice',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Points chart
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Points Chart',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Roll',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Points',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                _buildPointsRow('Snake Eyes (Two 1s)', '50'),
                                _buildPointsRow('Double Sixes', '500'),
                                _buildPointsRow('Any Other Doubles', 'Sum × 25'),
                                _buildPointsRow('Lucky 7 or 11', '200'),
                                _buildPointsRow('Any Other Roll', 'Sum × 10'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Banner ad at the bottom
          const BannerAdWidget(),
        ],
      ),
    );
  }
  
  // Helper method to build points chart rows
  Widget _buildPointsRow(String label, String points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          Expanded(
            flex: 1,
            child: Text(
              points,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}