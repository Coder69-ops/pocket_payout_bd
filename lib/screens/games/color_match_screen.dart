import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:confetti/confetti.dart';

class ColorMatchScreen extends StatefulWidget {
  const ColorMatchScreen({Key? key}) : super(key: key);

  @override
  State<ColorMatchScreen> createState() => _ColorMatchScreenState();
}

class _ColorMatchScreenState extends State<ColorMatchScreen> {
  // Ad-related variables
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  
  // Confetti controller for win animation
  late ConfettiController _confettiController;
  
  // Game state variables
  bool _isLoading = true;
  bool _gameStarted = false;
  bool _gameCompleted = false;
  bool _isCorrect = false;
  int _remainingGames = 0;
  int _streakCount = 0;
  int _score = 0;
  int _timeLeft = 60; // 60 seconds per game
  int _correctAnswers = 0;
  int _totalAnswers = 0;
  Timer? _timer;
  
  // Color matching variables
  late ColorMatch _currentMatch;
  late List<String> _options;
  String? _selectedOption;
  
  // Define colors for the game
  final List<ColorInfo> _colors = [
    ColorInfo(name: 'Red', color: Colors.red),
    ColorInfo(name: 'Blue', color: Colors.blue),
    ColorInfo(name: 'Green', color: Colors.green),
    ColorInfo(name: 'Yellow', color: Colors.yellow),
    ColorInfo(name: 'Purple', color: Colors.purple),
    ColorInfo(name: 'Orange', color: Colors.orange),
    ColorInfo(name: 'Pink', color: Colors.pink),
    ColorInfo(name: 'Teal', color: Colors.teal),
    ColorInfo(name: 'Brown', color: Colors.brown),
    ColorInfo(name: 'Grey', color: Colors.grey),
  ];
  
  // Difficulty settings
  final Map<String, Map<String, dynamic>> _difficultySettings = {
    'easy': {
      'timeLimit': 60,
      'targetScore': 10,
      'optionsCount': 3,
    },
    'medium': {
      'timeLimit': 45,
      'targetScore': 15,
      'optionsCount': 4,
    },
    'hard': {
      'timeLimit': 30,
      'targetScore': 20,
      'optionsCount': 5,
    },
  };
  
  String _currentDifficulty = 'medium';
  int _targetScore = 0;

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
        _remainingGames = user.remainingColorMatches;
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
        const SnackBar(content: Text('No more color matching games remaining today. Come back tomorrow!')),
      );
      return;
    }
    
    // Set up game based on difficulty
    final settings = _difficultySettings[_currentDifficulty]!;
    _timeLeft = settings['timeLimit'] as int;
    _targetScore = settings['targetScore'] as int;
    
    // Reset game state
    setState(() {
      _gameStarted = true;
      _gameCompleted = false;
      _score = 0;
      _correctAnswers = 0;
      _totalAnswers = 0;
      _selectedOption = null;
    });
    
    // Generate first color match
    _generateColorMatch();
    
    // Start timer
    _startTimer();
  }
  
  void _generateColorMatch() {
    final Random random = Random();
    final settings = _difficultySettings[_currentDifficulty]!;
    final int optionsCount = settings['optionsCount'] as int;
    
    // Pick a random color for the display
    final ColorInfo displayColor = _colors[random.nextInt(_colors.length)];
    
    // Decide randomly if this will be a matching pair or not
    final bool isMatching = random.nextBool();
    
    // If matching, use the same color name, otherwise pick a different one
    final String displayText = isMatching 
        ? displayColor.name 
        : _getRandomDifferentColorName(displayColor.name);
    
    // Set current match
    _currentMatch = ColorMatch(
      displayText: displayText,
      displayColor: displayColor.color,
      correctOption: displayColor.name,
    );
    
    // Generate options (including the correct one)
    List<String> allOptions = List.from(_colors.map((c) => c.name));
    allOptions.shuffle();
    
    // Ensure correct option is included
    if (!allOptions.sublist(0, optionsCount).contains(displayColor.name)) {
      allOptions = List.from(allOptions);
      allOptions.remove(displayColor.name);
      allOptions.insert(random.nextInt(optionsCount), displayColor.name);
    }
    
    _options = allOptions.sublist(0, optionsCount);
  }
  
  String _getRandomDifferentColorName(String excludeName) {
    final List<String> otherColors = _colors
        .where((c) => c.name != excludeName)
        .map((c) => c.name)
        .toList();
    return otherColors[Random().nextInt(otherColors.length)];
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
          _endGame();
          timer.cancel();
        }
      });
    });
  }
  
  void _checkAnswer(String selectedOption) {
    // Check if the selected color name matches the displayed color
    final bool isCorrect = selectedOption == _currentMatch.correctOption;
    
    setState(() {
      _selectedOption = selectedOption;
      _isCorrect = isCorrect;
      _totalAnswers++;
      
      if (isCorrect) {
        _score++;
        _correctAnswers++;
      }
    });
    
    // Check if target score reached
    if (_score >= _targetScore) {
      _endGame();
      return;
    }
    
    // Short delay to show feedback before next question
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _selectedOption = null;
        });
        _generateColorMatch();
      }
    });
  }
  
  void _endGame() {
    _timer?.cancel();
    
    setState(() {
      _gameStarted = false;
      _gameCompleted = true;
    });
    
    // Play confetti if score is good
    if (_score >= _targetScore) {
      _confettiController.play();
    }
    
    // Calculate final score (base + time bonus if applicable)
    int finalScore = 0;
    
    // Base score based on correct answers
    finalScore = min(300, _correctAnswers * 15);
    
    // Bonus for reaching target
    if (_score >= _targetScore) {
      // Extra bonus based on difficulty
      int difficultyBonus = 0;
      switch (_currentDifficulty) {
        case 'easy':
          difficultyBonus = 50;
          break;
        case 'medium':
          difficultyBonus = 100;
          break;
        case 'hard':
          difficultyBonus = 200;
          break;
      }
      
      // Time bonus
      final settings = _difficultySettings[_currentDifficulty]!;
      final int maxTime = settings['timeLimit'] as int;
      
      if (_timeLeft > 0) {
        final double timePercentage = _timeLeft / maxTime;
        final int timeBonus = (100 * timePercentage).round();
        finalScore += difficultyBonus + timeBonus;
      } else {
        finalScore += difficultyBonus;
      }
    }
    
    // Award points if earned any
    if (finalScore > 0) {
      _awardPoints(finalScore);
    }
  }
  
  Future<void> _awardPoints(int basePoints) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Apply streak multiplier to base points
    final double streakMultiplier = GameConstants.getStreakMultiplier(_streakCount);
    final int finalPoints = (basePoints * streakMultiplier).round();
    
    try {
      // Award points to the user
      await userProvider.updatePoints(
        finalPoints,
        TransactionTypes.earnColorMatch,
        description: 'Completed Color Match Game',
      );
      
      // Increment daily counter
      await userProvider.incrementDailyCounter('color_match');
      
      // Update state with user data from provider
      setState(() {
        _remainingGames = userProvider.user?.remainingColorMatches ?? 0;
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
        title: const Text('Color Match Game'),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.palette,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 24),
            Text(
              'Color Match Challenge',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Match the color to its name and earn up to ${GameConstants.basePoints['color_match']} points!',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Game instructions
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to Play:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. A color name will appear in a colored text',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '2. Select the color name that matches the COLOR of the text (not what it says)',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '3. Be quick! Time is limited',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    // Example
                    const Text(
                      'Example:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'RED',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Correct answer: BLUE (the color of the text)',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
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
                        _buildDifficultyButton('easy', 'Easy'),
                        const SizedBox(width: 8),
                        _buildDifficultyButton('medium', 'Medium'),
                        const SizedBox(width: 8),
                        _buildDifficultyButton('hard', 'Hard'),
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
                backgroundColor: Colors.amber,
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
      ),
    );
  }
  
  Widget _buildDifficultyButton(String difficulty, String label) {
    final bool isSelected = _currentDifficulty == difficulty;
    
    String timeText;
    switch (difficulty) {
      case 'easy':
        timeText = '60s';
        break;
      case 'medium':
        timeText = '45s';
        break;
      case 'hard':
        timeText = '30s';
        break;
      default:
        timeText = '';
    }
    
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _currentDifficulty = difficulty;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.amber : Colors.grey.shade200,
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          elevation: isSelected ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              timeText,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActiveGame() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Game info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 18,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_score/$_targetScore',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _timeLeft <= 10 ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _timeLeft <= 10 ? Colors.red.shade200 : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 18,
                        color: _timeLeft <= 10 ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_timeLeft s',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _timeLeft <= 10 ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Main game area
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Color text
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _currentMatch.displayText,
                        style: TextStyle(
                          color: _currentMatch.displayColor,
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Instructions
                    const Text(
                      'What COLOR is the text? (not what it says)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Color options
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: _options.map((option) {
                            final bool isSelected = _selectedOption == option;
                            final bool isCorrect = option == _currentMatch.correctOption;
                            
                            Color buttonColor = Colors.grey.shade200;
                            Color textColor = Colors.black;
                            
                            if (isSelected) {
                              buttonColor = _isCorrect ? Colors.green.shade100 : Colors.red.shade100;
                              textColor = _isCorrect ? Colors.green.shade800 : Colors.red.shade800;
                            }
                            
                            return GestureDetector(
                              onTap: _selectedOption == null ? () => _checkAnswer(option) : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: buttonColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected
                                        ? (_isCorrect ? Colors.green : Colors.red)
                                        : Colors.grey.shade400,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGameCompleted() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _score >= _targetScore ? Icons.check_circle : Icons.access_time,
              color: _score >= _targetScore ? Colors.green : Colors.amber,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              _score >= _targetScore ? 'Challenge Completed!' : 'Time\'s Up!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Score: $_score/$_targetScore',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Correct Answers: $_correctAnswers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Total Questions: $_totalAnswers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_score >= _targetScore) ...[
              const SizedBox(height: 16),
              Text(
                'Time Left: $_timeLeft seconds',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _remainingGames > 0 ? _startGame : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _remainingGames > 0 ? 'PLAY AGAIN' : 'COME BACK TOMORROW',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Color info model
class ColorInfo {
  final String name;
  final Color color;
  
  const ColorInfo({
    required this.name,
    required this.color,
  });
}

// Color match model
class ColorMatch {
  final String displayText;
  final Color displayColor;
  final String correctOption;
  
  const ColorMatch({
    required this.displayText,
    required this.displayColor,
    required this.correctOption,
  });
} 