import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:pocket_payout_bd/widgets/streak_info_widget.dart';

class StreakDetailsScreen extends StatelessWidget {
  const StreakDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final streakCount = userProvider.user?.streakCounter ?? 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streak Bonus'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$streakCount Day Streak',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Multiplier: ${GameConstants.getStreakMultiplier(streakCount)}x',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Main content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Detailed streak widget
                  StreakInfoWidget(
                    streakCount: streakCount,
                    animateIcon: true,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // How it works section
                  _buildSection(
                    title: 'How It Works',
                    icon: Icons.info_outline,
                    content: const Text(
                      'Your streak increases each day you log in to the app. The longer your streak, the higher your point multiplier gets! All point rewards are multiplied by your streak bonus.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tips section
                  _buildSection(
                    title: 'Tips to Maintain Your Streak',
                    icon: Icons.lightbulb_outline,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _BulletPoint(text: 'Open the app at least once every day'),
                        _BulletPoint(text: 'Set a daily reminder to check in'),
                        _BulletPoint(text: 'Complete at least one activity each day'),
                        _BulletPoint(text: 'Your streak resets if you miss a day'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Points calculation section
                  _buildSection(
                    title: 'Points Calculation',
                    icon: Icons.calculate_outlined,
                    content: Column(
                      children: [
                        _buildCalculationExample(
                          basePoints: GameConstants.basePoints['spin']!,
                          multiplier: GameConstants.getStreakMultiplier(streakCount),
                          activityName: 'Spin Wheel',
                        ),
                        const SizedBox(height: 12),
                        _buildCalculationExample(
                          basePoints: GameConstants.basePoints['watch_ad']!,
                          multiplier: GameConstants.getStreakMultiplier(streakCount),
                          activityName: 'Watch Ad',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({
    required String title, 
    required IconData icon, 
    required Widget content
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: content,
          ),
        ],
      ),
    );
  }
  
  Widget _buildCalculationExample({
    required int basePoints,
    required double multiplier,
    required String activityName,
  }) {
    final result = (basePoints * multiplier).round();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activityName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Base points:'),
              ),
              Text(
                '$basePoints',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text('Streak multiplier:'),
              ),
              Text(
                '${multiplier}x',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text('Total points:'),
              ),
              Text(
                '$result',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  
  const _BulletPoint({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
} 