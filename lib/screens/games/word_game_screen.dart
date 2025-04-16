import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:confetti/confetti.dart';

class WordGameScreen extends StatefulWidget {
  const WordGameScreen({Key? key}) : super(key: key);

  @override
  State<WordGameScreen> createState() => _WordGameScreenState();
}

class _WordGameScreenState extends State<WordGameScreen> {
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
  int _wordsCompleted = 0;
  Timer? _timer;
  
  // Word game variables
  late Word _currentWord;
  List<String> _scrambledLetters = [];
  List<String> _selectedLetters = [];
  List<String> _availableLetters = [];
  
  // List of available words
  final List<Word> _wordList = [
    // Easy words
    Word(word: 'CAT', hint: 'Pet that purrs'),
    Word(word: 'DOG', hint: 'Man\'s best friend'),
    Word(word: 'SUN', hint: 'Star that gives us light'),
    Word(word: 'MAT', hint: 'You wipe your feet on it'),
    Word(word: 'HAT', hint: 'Worn on the head'),
    // Medium words
    Word(word: 'PHONE', hint: 'Device for calling'),
    Word(word: 'BENCH', hint: 'You sit on it'),
    Word(word: 'CLEAN', hint: 'Not dirty'),
    Word(word: 'APPLE', hint: 'Fruit that keeps doctors away'),
    Word(word: 'WATER', hint: 'You drink it'),
    // Hard words
    Word(word: 'BICYCLE', hint: 'Two-wheel vehicle'),
    Word(word: 'COMPUTER', hint: 'Electronic device for work'),
    Word(word: 'ELEPHANT', hint: 'Large animal with trunk'),
    Word(word: 'UMBRELLA', hint: 'Keeps you dry in rain'),
    Word(word: 'SANDWICH', hint: 'Food between bread'),
  ];
  
  // Difficulty settings
  final Map<String, Map<String, dynamic>> _difficultySettings = {
    'easy': {
      'timeLimit': 60,
      'targetScore': 3,
      'wordLength': 3, // Short words
    },
    'medium': {
      'timeLimit': 90,
      'targetScore': 5,
      'wordLength': 5, // Medium words
    },
    'hard': {
      'timeLimit': 120,
      'targetScore': 5,
      'wordLength': 7, // Long words
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
        _remainingGames = user.remainingWordGames;
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
        const SnackBar(content: Text('No more word games remaining today. Come back tomorrow!')),
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
      _wordsCompleted = 0;
      _selectedLetters = [];
    });
    
    // Start first word
    _generateNewWord();
    
    // Start timer
    _startTimer();
  }
  
  void _generateNewWord() {
    final settings = _difficultySettings[_currentDifficulty]!;
    final int targetLength = settings['wordLength'] as int;
    
    // Filter words by difficulty level
    final List<Word> filteredWords = _wordList.where((word) {
      if (_currentDifficulty == 'easy') return word.word.length <= 3;
      if (_currentDifficulty == 'medium') return word.word.length >= 4 && word.word.length <= 5;
      return word.word.length > 5; // hard
    }).toList();
    
    // Pick a random word
    _currentWord = filteredWords[Random().nextInt(filteredWords.length)];
    
    // Scramble the letters
    _scrambledLetters = _currentWord.word.split('')..shuffle();
    _availableLetters = List.from(_scrambledLetters);
    _selectedLetters = [];
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
  
  void _selectLetter(int index) {
    if (index < 0 || index >= _availableLetters.length) return;
    
    setState(() {
      final letter = _availableLetters[index];
      _selectedLetters.add(letter);
      _availableLetters.removeAt(index);
      
      // Check if word is complete
      if (_selectedLetters.join() == _currentWord.word) {
        _handleCorrectWord();
      }
    });
  }
  
  void _removeLetter(int index) {
    if (index < 0 || index >= _selectedLetters.length) return;
    
    setState(() {
      final letter = _selectedLetters[index];
      _availableLetters.add(letter);
      _selectedLetters.removeAt(index);
    });
  }
  
  void _handleCorrectWord() {
    // Increment score
    _score++;
    _wordsCompleted++;
    
    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Correct! "${_currentWord.word}" solved!',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Check if target score reached
    if (_score >= _targetScore) {
      _endGame();
      return;
    }
    
    // Generate new word after a short delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _generateNewWord();
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
    
    // Calculate final score
    int finalScore = 0;
    
    // Base points for each completed word
    finalScore = _wordsCompleted * 80;
    
    // Bonus for completing target
    if (_score >= _targetScore) {
      // Difficulty bonus
      switch (_currentDifficulty) {
        case 'easy':
          finalScore += 50;
          break;
        case 'medium':
          finalScore += 150;
          break;
        case 'hard':
          finalScore += 250;
          break;
      }
      
      // Time bonus (if completed before time's up)
      if (_timeLeft > 0) {
        final settings = _difficultySettings[_currentDifficulty]!;
        final int maxTime = settings['timeLimit'] as int;
        final double timePercentage = _timeLeft / maxTime;
        final int timeBonus = (100 * timePercentage).round();
        finalScore += timeBonus;
      }
    }
    
    // Award points
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
        TransactionTypes.earnWordGame,
        description: 'Completed Word Game',
      );
      
      // Increment daily counter
      await userProvider.incrementDailyCounter('word_game');
      
      // Update state with user data from provider
      setState(() {
        _remainingGames = userProvider.user?.remainingWordGames ?? 0;
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
        title: const Text('Word Puzzle Game'),
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
            Icons.text_fields,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            'Word Puzzle Challenge',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Unscramble letters to form words and earn up to ${GameConstants.basePoints['word_game']} points!',
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
                    '1. Arrange the scrambled letters to form a word',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '2. Use the hint to guide you',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '3. Complete as many words as you can before time runs out',
                    style: TextStyle(fontSize: 14),
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
                      _buildDifficultyButton('easy', 'Easy (3-letter)'),
                      const SizedBox(width: 8),
                      _buildDifficultyButton('medium', 'Medium (4-5 letter)'),
                      const SizedBox(width: 8),
                      _buildDifficultyButton('hard', 'Hard (6+ letter)'),
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
              backgroundColor: Colors.green,
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
          backgroundColor: isSelected ? Colors.green : Colors.grey.shade200,
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
    return Padding(
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_score/$_targetScore',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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
          
          const SizedBox(height: 24),
          
          // Hint
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              children: [
                const Text(
                  'Hint:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentWord.hint,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Selected letters area
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_selectedLetters.length, (index) {
                return _buildLetterTile(_selectedLetters[index], true, index);
              }),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Available letters
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_availableLetters.length, (index) {
              return _buildLetterTile(_availableLetters[index], false, index);
            }),
          ),
          
          const Spacer(),
          
          // Skip button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _generateNewWord();
              });
            },
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip this word'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLetterTile(String letter, bool isSelected, int index) {
    return GestureDetector(
      onTap: () {
        if (isSelected) {
          _removeLetter(index);
        } else {
          _selectLetter(index);
        }
      },
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green.shade300 : Colors.blue.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.green.shade700 : Colors.blue.shade700,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildGameCompleted() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _score >= _targetScore ? Icons.check_circle : Icons.access_time,
            color: _score >= _targetScore ? Colors.green : Colors.red,
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            _score >= _targetScore ? 'Challenge Completed!' : 'Time\'s Up!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Words Solved: $_wordsCompleted',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Score: $_score/$_targetScore',
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
              backgroundColor: Colors.green,
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

// Word model for the game
class Word {
  final String word;
  final String hint;
  
  const Word({
    required this.word,
    required this.hint,
  });
} 