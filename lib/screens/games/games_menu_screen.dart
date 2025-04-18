import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:pocket_payout_bd/widgets/banner_ad_widget.dart';
import 'spin_wheel_screen.dart';
import 'dice_game_screen.dart';
import 'math_puzzle_screen.dart';
import 'memory_game_screen.dart';
import 'color_match_screen.dart';
import 'word_game_screen.dart';

class GamesMenuScreen extends StatelessWidget {
  const GamesMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Games & Earn'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Banner Ad at the top
          const BannerAdWidget(showOnTop: true),
          
          // Game content
          Expanded(
            child: Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                final user = userProvider.user;
                final points = user?.pointsBalance ?? 0;
                
                return Column(
                  children: [
                    // Top points card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor,
                            theme.primaryColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Points',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  color: Colors.amber,
                                  size: 32,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$points',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Section title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.games, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Available Games',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Game cards
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.75,
                          children: [
                            _GameCard(
                              title: 'Spin Wheel',
                              description: 'Spin the wheel and win random points',
                              icon: Icons.rotate_right,
                              color: Colors.purple,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SpinWheelScreen()),
                              ),
                              pointsRange: '${GameConstants.basePoints['spin']!}',
                              remainingPlays: user?.maxDailySpins ?? 10 - (user?.dailySpinCount ?? 0),
                              maxPlays: user?.maxDailySpins ?? 10,
                            ),
                            _GameCard(
                              title: 'Dice Roll',
                              description: 'Roll the dice and try your luck',
                              icon: Icons.casino,
                              color: Colors.red,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const DiceGameScreen()),
                              ),
                              pointsRange: '${GameConstants.basePoints['dice']!}',
                              remainingPlays: user?.maxDailyDiceRolls ?? 15 - (user?.dailyDiceCount ?? 0),
                              maxPlays: user?.maxDailyDiceRolls ?? 15,
                            ),
                            _GameCard(
                              title: 'Math Puzzles',
                              description: 'Solve math problems and earn rewards',
                              icon: Icons.calculate,
                              color: Colors.indigo,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MathPuzzleScreen()),
                              ),
                              pointsRange: '${GameConstants.basePoints['math_puzzle']!}',
                              remainingPlays: user?.remainingMathPuzzles ?? 0,
                              maxPlays: user?.maxDailyMathPuzzles ?? 10,
                            ),
                            _GameCard(
                              title: 'Memory Game',
                              description: 'Test your memory skills to earn points',
                              icon: Icons.psychology,
                              color: Colors.teal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MemoryGameScreen()),
                              ),
                              pointsRange: '${GameConstants.basePoints['memory_game']!}',
                              remainingPlays: user?.remainingMemoryGames ?? 0,
                              maxPlays: user?.maxDailyMemoryGames ?? 5,
                            ),
                            _GameCard(
                              title: 'Color Match',
                              description: 'Match colors quickly to earn rewards',
                              icon: Icons.palette,
                              color: Colors.amber,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ColorMatchScreen()),
                              ),
                              pointsRange: '${GameConstants.basePoints['color_match']!}',
                              remainingPlays: user?.remainingColorMatches ?? 0,
                              maxPlays: user?.maxDailyColorMatches ?? 8,
                            ),
                            _GameCard(
                              title: 'Word Game',
                              description: 'Test your vocabulary to earn points',
                              icon: Icons.text_fields,
                              color: Colors.green,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const WordGameScreen()),
                              ),
                              pointsRange: '${GameConstants.basePoints['word_game']!}',
                              remainingPlays: user?.remainingWordGames ?? 0,
                              maxPlays: user?.maxDailyWordGames ?? 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String pointsRange;
  final int remainingPlays;
  final int maxPlays;

  const _GameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.pointsRange,
    required this.remainingPlays,
    required this.maxPlays,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.7),
                  widget.color.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 32,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.pointsRange} points',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    final double progress = widget.remainingPlays / widget.maxPlays;
    final bool noPlaysLeft = widget.remainingPlays <= 0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Plays Left:',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            Text(
              '${widget.remainingPlays}/${widget.maxPlays}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: noPlaysLeft ? Colors.red.shade300 : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              noPlaysLeft ? Colors.red.shade300 : Colors.white,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}