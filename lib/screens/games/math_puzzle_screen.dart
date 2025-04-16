import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:confetti/confetti.dart';
import 'package:pocket_payout_bd/services/ad_service.dart';
import 'package:pocket_payout_bd/widgets/custom_button.dart';

class MathPuzzleScreen extends StatefulWidget {
  const MathPuzzleScreen({Key? key}) : super(key: key);

  @override
  State<MathPuzzleScreen> createState() => _MathPuzzleScreenState();
}

class _MathPuzzleScreenState extends State<MathPuzzleScreen> {
  final Random _random = Random();
  late int _num1, _num2, _result;
  late String _operation;
  late int _correctAnswer;
  List<int> _options = [];
  
  int _score = 0;
  int _questionsAnswered = 0;
  int _timeLeft = 30;
  Timer? _timer;
  bool _gameOver = false;
  late ConfettiController _confettiController;
  
  // Ad related variables
  InterstitialAd? _interstitialAd;
  final AdService _adService = AdService();
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _loadInterstitialAd();
    _generateProblem();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _loadInterstitialAd() {
    _adService.loadInterstitialAd(
      onAdLoaded: (ad) {
        _interstitialAd = ad;
        _isAdLoaded = true;
      },
      onAdFailedToLoad: (error) {
        debugPrint('Failed to load interstitial ad: $error');
      },
    );
  }

  void _showInterstitialAd() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          _awardPoints();
          Navigator.pop(context);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _awardPoints();
          Navigator.pop(context);
        },
      );
      _interstitialAd!.show();
    } else {
      _awardPoints();
      Navigator.pop(context);
    }
  }

  void _generateProblem() {
    // Decide the difficulty based on score
    int difficulty = _score ~/ 5 + 1;
    difficulty = difficulty.clamp(1, 3);
    
    // Generate numbers based on difficulty
    int maxNum = 10 * difficulty;
    _num1 = _random.nextInt(maxNum) + 1;
    _num2 = _random.nextInt(maxNum) + 1;
    
    // Choose operation
    List<String> operations = ['+', '-', '×'];
    if (difficulty > 1) operations.add('÷');
    _operation = operations[_random.nextInt(operations.length)];
    
    // Calculate correct answer
    switch (_operation) {
      case '+':
        _correctAnswer = _num1 + _num2;
        break;
      case '-':
        // Ensure no negative results
        if (_num1 < _num2) {
          int temp = _num1;
          _num1 = _num2;
          _num2 = temp;
        }
        _correctAnswer = _num1 - _num2;
        break;
      case '×':
        // For multiplication, use smaller numbers if score is low
        if (difficulty == 1) {
          _num1 = _random.nextInt(5) + 1;
          _num2 = _random.nextInt(5) + 1;
        }
        _correctAnswer = _num1 * _num2;
        break;
      case '÷':
        // Ensure division yields a whole number
        _correctAnswer = _random.nextInt(maxNum ~/ 2) + 1;
        _num1 = _correctAnswer * _num2;
        break;
      default:
        _correctAnswer = _num1 + _num2;
    }
    
    // Generate options
    _generateOptions();
  }
  
  void _generateOptions() {
    _options = [_correctAnswer];
    
    // Generate 3 wrong options
    while (_options.length < 4) {
      // Generate a wrong answer close to the correct one
      int wrongAnswer = _correctAnswer + (_random.nextInt(11) - 5);
      
      // Ensure it's different from correct answer and not already in options
      if (wrongAnswer != _correctAnswer && !_options.contains(wrongAnswer) && wrongAnswer > 0) {
        _options.add(wrongAnswer);
      }
    }
    
    // Shuffle options
    _options.shuffle();
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _endGame();
        }
      });
    });
  }
  
  void _checkAnswer(int selectedAnswer) {
    if (_gameOver) return;
    
    setState(() {
      _questionsAnswered++;
      
      if (selectedAnswer == _correctAnswer) {
        _score++;
      }
      
      if (_questionsAnswered >= 10) {
        _endGame();
      } else {
        _generateProblem();
      }
    });
  }
  
  void _endGame() {
    _timer?.cancel();
    setState(() {
      _gameOver = true;
    });
    
    if (_score >= 5) {
      _confettiController.play();
    }
  }
  
  void _restartGame() {
    setState(() {
      _score = 0;
      _questionsAnswered = 0;
      _timeLeft = 30;
      _gameOver = false;
      _generateProblem();
    });
    _startTimer();
  }

  void _awardPoints() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Award points based on score
    int basePoints = GameConstants.mathPuzzleMinPoints;
    int additionalPoints = (_score * GameConstants.mathPuzzlePointsMultiplier).toInt();
    int totalPoints = basePoints + additionalPoints;
    
    // Apply streak multiplier
    final double streakMultiplier = GameConstants.getStreakMultiplier(userProvider.user?.streakCounter ?? 0);
    final int finalPoints = (totalPoints * streakMultiplier).round();
    
    try {
      // Use updatePoints for consistency with other games
      userProvider.updatePoints(
        finalPoints,
        TransactionTypes.earnMathPuzzle,
        description: 'Completed Math Puzzle Game'
      );
      
      // Update plays counter
      userProvider.updateMathPuzzlePlays();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Earned $finalPoints points!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error awarding points: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating points: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Math Puzzle'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Timer and Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '$_timeLeft s',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Score: $_score',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Problem display
                if (!_gameOver)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 3,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '$_num1 $_operation $_num2 = ?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 40),
                
                // Answer options
                if (!_gameOver)
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      padding: const EdgeInsets.all(8),
                      children: _options.map((option) {
                        return InkWell(
                          onTap: () => _checkAnswer(option),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade300, Colors.blue.shade500],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                option.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                
                // Game over screen
                if (_gameOver)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Game Over!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your Score: $_score / 10',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _score >= 5 ? 'Great job! 🎉' : 'Keep practicing! 💪',
                            style: TextStyle(
                              fontSize: 18,
                              color: _score >= 5 ? Colors.green : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomButton(
                                text: 'Play Again',
                                onPressed: _restartGame,
                                buttonColor: Colors.blue,
                                width: 140,
                              ),
                              const SizedBox(width: 16),
                              CustomButton(
                                text: 'Finish',
                                onPressed: _showInterstitialAd,
                                buttonColor: Colors.green,
                                width: 140,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
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
                Colors.yellow,
              ],
            ),
          ),
        ],
      ),
    );
  }
} 