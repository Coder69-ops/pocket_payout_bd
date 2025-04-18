import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/services/firestore_service.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class QuizGameScreen extends StatefulWidget {
  const QuizGameScreen({Key? key}) : super(key: key);

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  final _firestoreService = FirestoreService();
  RewardedAd? _rewardedAd;
  bool _isLoading = true;
  bool _isPlaying = false;
  List<QuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  int _remainingQuizzes = 5;

  @override
  void initState() {
    super.initState();
    _loadAd();
    _initializeQuizCount();
    _loadQuestions();
  }

  Future<void> _initializeQuizCount() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      setState(() {
        _remainingQuizzes = 5 - user.dailyQuizCount;
      });
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _firestoreService.getQuizQuestions(limit: 5);
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading questions: $e')),
      );
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

  void _handleAnswer(String selectedAnswer) async {
    if (!_isPlaying) return;

    final question = _questions[_currentQuestionIndex];
    final isCorrect = selectedAnswer == question.correctAnswer;

    if (isCorrect) {
      setState(() {
        _correctAnswers++;
      });
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      // Quiz completed, show ad then award points
      if (_rewardedAd == null) {
        _processQuizResults();
      } else {
        _rewardedAd?.show(
          onUserEarnedReward: (ad, reward) => _processQuizResults(),
        );
      }
    }
  }

  Future<void> _processQuizResults() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final points = _calculatePoints();

      await userProvider.updatePoints(
        points,
        TransactionTypes.earnQuiz,
        description: 'Quiz completed: $_correctAnswers/${_questions.length} correct',
      );
      
      await userProvider.incrementDailyCounter('quiz');
      
      setState(() {
        _isPlaying = false;
        _remainingQuizzes--;
      });

      if (mounted) {
        _showCompletionDialog(points);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  int _calculatePoints() {
    // Base points for participating
    int points = 50;
    
    // Additional points for correct answers
    points += (_correctAnswers * 100);
    
    // Bonus for perfect score
    if (_correctAnswers == _questions.length) {
      points += 250;
    }
    
    return points;
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _correctAnswers = 0;
      _isLoading = true;
      _isPlaying = false;
    });
    _loadQuestions();
  }

  void _startQuiz() {
    setState(() {
      _isPlaying = true;
    });
  }

  void _showCompletionDialog(int points) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Quiz Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _correctAnswers == _questions.length ? Icons.emoji_events : Icons.check_circle,
              color: _correctAnswers == _questions.length ? Colors.amber : Colors.green,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              _correctAnswers == _questions.length 
                ? 'Perfect Score! Amazing!' 
                : 'Well Done!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text('Correct Answers: $_correctAnswers/${_questions.length}'),
            const SizedBox(height: 8),
            Text(
              'Points Earned: $points',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have $_remainingQuizzes quizzes left today',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (_remainingQuizzes > 0) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Exit Quiz'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetQuiz();
              },
              child: const Text('Play Again'),
            ),
          ] else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
        ],
      ),
    );

    // If no more quizzes, return to home screen
    if (_remainingQuizzes <= 0) {
      if (mounted) Navigator.of(context).pop();
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
        title: const Text('Quiz Master'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _remainingQuizzes <= 0
              ? const Center(
                  child: Text('No quizzes remaining today. Come back tomorrow!'),
                )
              : !_isPlaying
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ready to Play?',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_remainingQuizzes quizzes remaining today',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _startQuiz,
                            child: const Text('Start Quiz'),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LinearProgressIndicator(
                            value: (_currentQuestionIndex + 1) / _questions.length,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _questions[_currentQuestionIndex].question,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._questions[_currentQuestionIndex]
                              .options
                              .map((option) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () => _handleAnswer(option),
                                      child: Text(option),
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
    );
  }
}

class QuestionModel {
  final String id;
  final String question;
  final List<String> options;
  final String correctAnswer;

  QuestionModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory QuestionModel.fromMap(Map<String, dynamic> data, String id) {
    return QuestionModel(
      id: id,
      question: data['question'] as String,
      options: List<String>.from(data['options'] as List),
      correctAnswer: data['correctAnswer'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
    };
  }
}