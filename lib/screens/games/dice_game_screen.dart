import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/services/firestore_service.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';

class DiceGameScreen extends StatefulWidget {
  const DiceGameScreen({Key? key}) : super(key: key);

  @override
  State<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends State<DiceGameScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final Random _random = Random();
  
  // Animation controller for dice roll
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotationAnimation;
  late ConfettiController _confettiController;
  
  // Game state variables
  bool _isLoading = false;
  bool _isAdLoading = false;
  bool _isRolling = false;
  bool _canPlay = true;
  int _remainingRolls = 0;
  int _dailyDiceLimit = 5; // Maximum dice rolls per day
  String? _errorMessage;
  
  // Dice values and points
  int _dice1Value = 1;
  int _dice2Value = 1;
  int _rewardPoints = 0;
  int _lastWonAmount = 0;
  
  // Ad related variables
  RewardedAd? _rewardedAd;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
          .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
          .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 75,
      ),
    ]).animate(_controller);
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 6 * pi, // Multiple full rotations
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // When animation completes, award points
        _calculateReward();
      }
    });
    
    // Initialize confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _checkRemainingRolls();
    _loadAd();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _rewardedAd?.dispose();
    _confettiController.dispose();
    super.dispose();
  }
  
  // Check how many dice rolls the user has left for today
  Future<void> _checkRemainingRolls() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      setState(() {
        _dailyDiceLimit = user.maxDailyDiceRolls;
        _remainingRolls = _dailyDiceLimit - user.dailyDiceCount;
        _canPlay = _remainingRolls > 0;
      });
    }
  }
  
  // Load a rewarded ad
  void _loadAd() {
    setState(() {
      _isAdLoading = true;
    });
    
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Replace with your actual ad unit ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoading = false;
          });
          
          // Set the callback to earn reward
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadAd(); // Load a new ad for next roll
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadAd();
              setState(() {
                _errorMessage = 'Error showing ad. Please try again.';
              });
            },
          );
        },
        onAdFailedToLoad: (error) {
          setState(() {
            _isAdLoading = false;
            _errorMessage = 'Failed to load ad. Please try again.';
          });
          debugPrint('Rewarded ad failed to load: ${error.message}');
        },
      ),
    );
  }
  
  // Show ad and prepare to roll dice
  void _showAdAndRollDice() {
    if (!_canPlay) {
      setState(() {
        _errorMessage = 'You\'ve reached your daily dice roll limit. Come back tomorrow!';
      });
      return;
    }
    
    if (_rewardedAd == null) {
      setState(() {
        _errorMessage = 'Ad not loaded. Please wait or try again.';
      });
      return;
    }
    
    setState(() {
      _errorMessage = null;
    });
    
    // Show the ad
    _rewardedAd?.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // When user watches the ad completely, roll the dice
        _rollDice();
      },
    );
  }
  
  // Roll the dice
  void _rollDice() {
    setState(() {
      _isRolling = true;
    });
    
    // Reset the animation controller
    _controller.reset();
    
    // Animate the dice
    for (int i = 0; i < 20; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted && _isRolling) {
          setState(() {
            _dice1Value = _random.nextInt(6) + 1;
            _dice2Value = _random.nextInt(6) + 1;
          });
        }
      });
    }
    
    // Start the bounce and rotation animation
    _controller.forward();
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
      
      // Record the amount won for display
      _lastWonAmount = _rewardPoints;
      
      // Play confetti for big wins
      if (_rewardPoints >= 200) {
        _confettiController.play();
      }
      
      // Update daily dice count
      await userProvider.incrementDailyCounter('dice');
      
      // Award points to the user
      await userProvider.updatePoints(
        _rewardPoints,
        'earn_dice',
        description: 'Earned from Dice Roll ($_dice1Value+$_dice2Value)',
      );
      
      setState(() {
        _remainingRolls = _dailyDiceLimit - (user.dailyDiceCount + 1);
        _canPlay = _remainingRolls > 0;
        _isLoading = false;
        _isRolling = false;
      });
      
      // Show reward dialog
      _showRewardDialog();
      
    } catch (e) {
      debugPrint('Error awarding points: $e');
      setState(() {
        _errorMessage = 'Error awarding points: $e';
        _isLoading = false;
        _isRolling = false;
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
        title: Text('You Rolled ${_dice1Value + _dice2Value}!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '+$_rewardPoints points',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You have $_remainingRolls rolls left today',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          if (_remainingRolls > 0) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('EXIT GAME'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAdAndRollDice();
              },
              child: const Text('ROLL AGAIN'),
            ),
          ] else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('DONE'),
            ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Roll'),
        elevation: 0,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          return Stack(
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
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Top info card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.casino,
                                      color: theme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _remainingRolls > 0 
                                    ? Colors.green.withOpacity(0.1) 
                                    : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.casino,
                                      size: 16,
                                      color: _remainingRolls > 0 ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$_remainingRolls / $_dailyDiceLimit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _remainingRolls > 0 ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_lastWonAmount > 0 && !_isRolling) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.paid,
                                color: Colors.green,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Last Win: +$_lastWonAmount points',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // Error message
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
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
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                },
                                color: Colors.red.shade700,
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Loading indicator
                      if (_isLoading && !_isRolling) ...[
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Instructions or limit reached message
                      if (!_canPlay) ...[
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 60,
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
                                const SizedBox(height: 16),
                                const Text(
                                  'You\'ve used all your dice rolls for today. Come back tomorrow for more chances to win!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: const Text('BACK TO GAMES'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Roll the dice and win points based on your roll!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Doubles and special combinations earn bonus points',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Dice display
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _bounceAnimation.value,
                                    child: Transform.rotate(
                                      angle: _rotationAnimation.value,
                                      child: _buildDice(_dice1Value),
                                    ),
                                  );
                                },
                              ),
                              AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _bounceAnimation.value,
                                    child: Transform.rotate(
                                      angle: -_rotationAnimation.value, // Opposite direction
                                      child: _buildDice(_dice2Value),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Total display
                        if (_isRolling) ...[
                          const Text(
                            'Rolling...',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'Total: ${_dice1Value + _dice2Value}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        
                        // Roll button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: (_isAdLoading || _isRolling || _isLoading) ? null : _showAdAndRollDice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            icon: _isAdLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.casino),
                            label: Text(
                              _isRolling ? 'ROLLING...' : 'ROLL DICE',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Watch a short ad to roll the dice',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      
                      // Points chart
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: theme.primaryColor),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Rewards Chart',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _buildPointsRow('Snake Eyes (Two 1s)', '50', Colors.red),
                              _buildPointsRow('Double Sixes', '500', Colors.amber),
                              _buildPointsRow('Any Other Doubles', 'Sum × 25', Colors.blue),
                              _buildPointsRow('Lucky 7 or 11', '200', Colors.green),
                              _buildPointsRow('Any Other Roll', 'Sum × 10', Colors.purple),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
          );
        },
      ),
    );
  }
  
  // Build a dice widget
  Widget _buildDice(int value) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFe53935), Color(0xFFc62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: _getDiceFace(value),
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
        shrinkWrap: true,
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
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          }
          return Container();
        },
      ),
    );
  }
  
  // Helper method to build points chart rows
  Widget _buildPointsRow(String label, String points, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label),
          ),
          Text(
            points,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}