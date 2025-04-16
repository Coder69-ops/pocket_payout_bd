import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:confetti/confetti.dart';

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({Key? key}) : super(key: key);

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  // Ad-related variables
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  
  // Confetti controller for win animation
  late ConfettiController _confettiController;
  
  // Game state variables
  bool _isLoading = true;
  bool _gameStarted = false;
  bool _gameCompleted = false;
  int _remainingGames = 0;
  int _streakCount = 0;
  int _score = 0;
  int _timeLeft = 60; // 60 seconds per game
  int _movesUsed = 0;
  int _pairsFound = 0;
  Timer? _timer;
  
  // Card variables
  List<MemoryCard> _cards = [];
  MemoryCard? _firstFlippedCard;
  bool _canFlip = true;
  
  // List of emoji pairs for cards
  final List<String> _emojis = [
    '🍎', '🍌', '🍇', '🍊', '🍉', '🍓', '🍒', '🥝',
    '🦁', '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐼',
  ];
  
  // Difficulty settings
  final Map<String, Map<String, dynamic>> _difficultySettings = {
    'easy': {
      'pairs': 6,
      'timeLimit': 60,
      'baseScore': 300,
    },
    'medium': {
      'pairs': 8,
      'timeLimit': 75,
      'baseScore': 400,
    },
    'hard': {
      'pairs': 12,
      'timeLimit': 90,
      'baseScore': 450,
    },
  };
  
  String _currentDifficulty = 'medium';
  late int _totalPairs;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadInterstitialAd();
    _initializeGameData();
  }

  Future<void> _initializeGameData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      setState(() {
        _remainingGames = user.remainingMemoryGames;
        _streakCount = user.streakCounter;
        _isLoading = false;
      });
    }
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

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      debugPrint('Interstitial ad not ready');
      return;
    }
    
    _interstitialAd!.show();
    _interstitialAd = null;
  }
  
  void _startGame() {
    if (_remainingGames <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No memory games remaining today. Come back tomorrow!')),
      );
      return;
    }
    
    // Reset game state
    setState(() {
      _gameStarted = true;
      _gameCompleted = false;
      _score = 0;
      _movesUsed = 0;
      _pairsFound = 0;
      _firstFlippedCard = null;
      _canFlip = true;
    });
    
    // Set up game based on difficulty
    _setUpGame();
    
    // Start timer
    _startTimer();
  }
  
  void _setUpGame() {
    final settings = _difficultySettings[_currentDifficulty]!;
    _totalPairs = settings['pairs'] as int;
    _timeLeft = settings['timeLimit'] as int;
    
    // Create a list of card pairs
    List<String> cardEmojis = [];
    List<String> shuffledEmojis = List.from(_emojis)..shuffle();
    
    // Take only the number of pairs we need
    for (int i = 0; i < _totalPairs; i++) {
      cardEmojis.add(shuffledEmojis[i]);
      cardEmojis.add(shuffledEmojis[i]);
    }
    
    // Shuffle the final list
    cardEmojis.shuffle();
    
    // Create memory cards
    _cards = List.generate(
      cardEmojis.length,
      (index) => MemoryCard(
        emoji: cardEmojis[index],
        isFlipped: false,
        isMatched: false,
      ),
    );
  }
  
  void _startTimer() {
    // Cancel existing timer if any
    _timer?.cancel();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          // Time's up
          _endGame(false);
          timer.cancel();
        }
      });
    });
  }
  
  void _flipCard(int index) {
    // Don't allow flipping if: 
    // - player can't flip
    // - card is already flipped
    // - card is already matched
    if (!_canFlip || _cards[index].isFlipped || _cards[index].isMatched) {
      return;
    }
    
    setState(() {
      _cards[index] = _cards[index].copyWith(isFlipped: true);
      
      // If this is the first card flipped
      if (_firstFlippedCard == null) {
        _firstFlippedCard = _cards[index];
      } else {
        // This is the second card
        _movesUsed++;
        
        // Check for a match
        if (_firstFlippedCard!.emoji == _cards[index].emoji) {
          // Match found
          _cards[_cards.indexOf(_firstFlippedCard!)] = _firstFlippedCard!.copyWith(isMatched: true);
          _cards[index] = _cards[index].copyWith(isMatched: true);
          _pairsFound++;
          _firstFlippedCard = null;
          
          // Check if all pairs are found
          if (_pairsFound == _totalPairs) {
            _endGame(true);
          }
        } else {
          // No match, flip back after a delay
          _canFlip = false;
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _cards[_cards.indexOf(_firstFlippedCard!)] = _firstFlippedCard!.copyWith(isFlipped: false);
                _cards[index] = _cards[index].copyWith(isFlipped: false);
                _firstFlippedCard = null;
                _canFlip = true;
              });
            }
          });
        }
      }
    });
  }
  
  void _endGame(bool completed) {
    _timer?.cancel();
    
    setState(() {
      _gameStarted = false;
      _gameCompleted = true;
    });
    
    if (completed) {
      _confettiController.play();
      
      // Calculate score based on difficulty, time left, and moves
      final settings = _difficultySettings[_currentDifficulty]!;
      final baseScore = settings['baseScore'] as int;
      
      // Time bonus: up to 50% of base score
      final timePercentage = _timeLeft / (settings['timeLimit'] as int);
      final timeBonus = (baseScore * 0.5 * timePercentage).round();
      
      // Move efficiency bonus: More efficient = more points
      // Perfect game would be exactly pairs*2 moves
      final idealMoves = _totalPairs * 2;
      final moveEfficiency = max(0, 1 - ((_movesUsed - idealMoves) / (idealMoves * 2)));
      final moveBonus = (baseScore * 0.5 * moveEfficiency).round();
      
      _score = baseScore + timeBonus + moveBonus;
      
      // Award points
      _awardPoints();
    } else {
      // Game timed out, award partial points if they found any pairs
      if (_pairsFound > 0) {
        final settings = _difficultySettings[_currentDifficulty]!;
        final baseScore = settings['baseScore'] as int;
        
        // Award based on percentage of pairs found
        final pairsPercentage = _pairsFound / _totalPairs;
        _score = (baseScore * pairsPercentage).round();
        
        // Award partial points
        _awardPoints();
      }
    }
  }
  
  Future<void> _awardPoints() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Apply streak multiplier to base points
    final int basePoints = _score;
    final double streakMultiplier = GameConstants.getStreakMultiplier(_streakCount);
    final int finalPoints = (basePoints * streakMultiplier).round();
    
    try {
      // Award points to the user
      await userProvider.updatePoints(
        finalPoints,
        TransactionTypes.earnMemoryGame,
        description: 'Completed Memory Game',
      );
      
      // Increment daily counter
      await userProvider.incrementDailyCounter('memory_game');
      
      // Update state with user data from provider
      setState(() {
        _remainingGames = userProvider.user?.remainingMemoryGames ?? 0;
      });
      
      // Play confetti for good wins
      _confettiController.play();
      
      // Show reward dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => _showRewardDialog(finalPoints, basePoints, streakMultiplier),
        );
        
        // Show interstitial ad after dialog is closed
        _showInterstitialAd();
      }
    } catch (e) {
      debugPrint('Error awarding points: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating points: $e')),
        );
      }
    }
  }
  
  Widget _showRewardDialog(int points, int basePoints, double streakMultiplier) {
    return AlertDialog(
      title: const Text('Congratulations!', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 50),
          const SizedBox(height: 16),
          Text(
            'You earned $points points!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          if (streakMultiplier > 1.0) ...[
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
                mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: 16),
          Text(
            'You have $_remainingGames games left today',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            _remainingGames > 0 ? 'PLAY AGAIN' : 'CLOSE',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _interstitialAd?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Game'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildGameContent(),
          
          // Confetti effect
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // straight down
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.teal,
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGameContent() {
    if (_gameStarted) {
      return _buildActiveGame();
    } else if (_gameCompleted) {
      return _buildGameCompleted();
    } else {
      return _buildStartScreen();
    }
  }
  
  Widget _buildStartScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.psychology,
            size: 80,
            color: Colors.teal,
          ),
          const SizedBox(height: 24),
          Text(
            'Memory Challenge',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Match pairs of cards and earn up to ${GameConstants.basePoints['memory_game']} points!',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Difficulty selection
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Difficulty:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildDifficultyButton('easy', 'Easy (6 pairs)'),
                      const SizedBox(width: 8),
                      _buildDifficultyButton('medium', 'Medium (8 pairs)'),
                      const SizedBox(width: 8),
                      _buildDifficultyButton('hard', 'Hard (12 pairs)'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Remaining games info
          Text(
            'You have $_remainingGames games remaining today',
            style: TextStyle(
              fontSize: 16,
              color: _remainingGames > 0 ? Colors.black87 : Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Start button
          ElevatedButton(
            onPressed: _remainingGames > 0 ? _startGame : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'START GAME',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDifficultyButton(String difficulty, String label) {
    final bool isSelected = _currentDifficulty == difficulty;
    
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _currentDifficulty = difficulty;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.teal : Colors.grey.shade200,
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          elevation: isSelected ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  Widget _buildActiveGame() {
    // Calculate size based on number of pairs and screen width
    final double screenWidth = MediaQuery.of(context).size.width;
    final settings = _difficultySettings[_currentDifficulty]!;
    final int pairs = settings['pairs'] as int;
    int crossAxisCount = 4;
    
    if (pairs == 6) {
      crossAxisCount = 3;
    } else if (pairs == 12) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 4;
    }
    
    return Column(
      children: [
        // Game info
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time left
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _timeLeft <= 10 ? Colors.red.shade50 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _timeLeft <= 10 ? Colors.red.shade200 : Colors.teal.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: _timeLeft <= 10 ? Colors.red : Colors.teal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_timeLeft s',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _timeLeft <= 10 ? Colors.red : Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Pairs found
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.find_replace,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_pairsFound / $_totalPairs',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Moves used
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app,
                      size: 16,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_movesUsed',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Memory cards grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                return _buildMemoryCard(index);
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMemoryCard(int index) {
    return GestureDetector(
      onTap: () => _flipCard(index),
      child: FlipCard(
        isFlipped: _cards[index].isFlipped,
        isMatched: _cards[index].isMatched,
        emoji: _cards[index].emoji,
      ),
    );
  }
  
  Widget _buildGameCompleted() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.psychology,
            color: Colors.teal,
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            'Game Completed!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Score: $_score',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Pairs Found: $_pairsFound / $_totalPairs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Moves Used: $_movesUsed',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _remainingGames > 0 ? _startGame : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _remainingGames > 0 ? 'PLAY AGAIN' : 'COME BACK TOMORROW',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Memory card data model
class MemoryCard {
  final String emoji;
  final bool isFlipped;
  final bool isMatched;
  
  const MemoryCard({
    required this.emoji,
    required this.isFlipped,
    required this.isMatched,
  });
  
  MemoryCard copyWith({
    String? emoji,
    bool? isFlipped,
    bool? isMatched,
  }) {
    return MemoryCard(
      emoji: emoji ?? this.emoji,
      isFlipped: isFlipped ?? this.isFlipped,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}

// Flip card widget for the memory game
class FlipCard extends StatelessWidget {
  final bool isFlipped;
  final bool isMatched;
  final String emoji;
  
  const FlipCard({
    Key? key,
    required this.isFlipped,
    required this.isMatched,
    required this.emoji,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final angle = isFlipped ? animation.value * pi : (1 - animation.value) * pi;
            final value = isFlipped ? animation.value : (1 - animation.value);
            
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: value >= 0.5 ? child : _buildCardBack(),
            );
          },
          child: _buildCardFront(),
        );
      },
      child: isFlipped ? _buildCardFront() : _buildCardBack(),
    );
  }
  
  Widget _buildCardFront() {
    return Container(
      key: const ValueKey('front'),
      decoration: BoxDecoration(
        color: isMatched ? Colors.green.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMatched ? Colors.green.shade400 : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isMatched ? Colors.green.withOpacity(0.2) : Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
  
  Widget _buildCardBack() {
    return Container(
      key: const ValueKey('back'),
      decoration: BoxDecoration(
        color: Colors.teal.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.psychology,
          size: 32,
          color: Colors.teal.shade800,
        ),
      ),
    );
  }
} 