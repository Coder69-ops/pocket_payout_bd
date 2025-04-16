import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/screens/profile_screen.dart';
import 'package:pocket_payout_bd/screens/withdrawal_screen.dart';
import 'package:pocket_payout_bd/screens/games/spin_wheel_screen.dart';
import 'package:pocket_payout_bd/screens/games/dice_game_screen.dart';
import 'package:pocket_payout_bd/screens/games/math_puzzle_screen.dart';
import 'package:pocket_payout_bd/screens/games/memory_game_screen.dart';
import 'package:pocket_payout_bd/screens/games/color_match_screen.dart';
import 'package:pocket_payout_bd/screens/games/word_game_screen.dart';
import 'package:pocket_payout_bd/screens/offer_wall_screen.dart';
import 'package:pocket_payout_bd/screens/watch_ads_screen.dart';
import 'package:pocket_payout_bd/screens/games/games_menu_screen.dart';
import 'package:pocket_payout_bd/screens/streak_details_screen.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  // Add streak color helper
  Color _getStreakColor(int streakCount) {
    if (streakCount >= 7) return Colors.purple;
    if (streakCount >= 5) return Colors.orange;
    if (streakCount >= 3) return Colors.green;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final theme = Theme.of(context);
    final streakCount = user?.streakCounter ?? 0;
    final primaryColor = theme.colorScheme.primary;
    final background = theme.colorScheme.background;
    final foreground = theme.colorScheme.onBackground;

    // Custom color scheme for this screen
    final secondaryColor = Color(0xFF7895CB);
    final accentColor = Color(0xFFA0BFE0);
    final backgroundLight = Color(0xFFC5DFF8);

    // Determine streak multiplier
    final streakMultiplier = GameConstants.getStreakMultiplier(streakCount);
    final streakColor = _getStreakColor(streakCount);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Custom App Bar
            SliverAppBar(
              floating: true,
              expandedHeight: 110,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        secondaryColor,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Welcome back,",
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.displayName ?? "BD User",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: primaryColor.withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Points Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            secondaryColor,
                            primaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Balance',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${user?.points ?? 0}',
                                          style: theme.textTheme.headlineLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            'Points',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // Updated Streak UI
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Text(
                                            '$streakCount',
                                            style: theme.textTheme.headlineSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (streakCount > 0) 
                                            Positioned(
                                              right: -6,
                                              top: -2,
                                              child: Icon(
                                                Icons.local_fire_department,
                                                color: streakColor,
                                                size: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        'Day Streak',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Withdrawal button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => const WithdrawalScreen()),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Withdraw Points'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Streak Bonus Card - Show for all users
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StreakDetailsScreen()),
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: streakCount > 0 
                                    ? streakColor.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    streakCount > 0 
                                        ? Icons.local_fire_department
                                        : Icons.calendar_today,
                                    color: streakCount > 0 
                                        ? streakColor
                                        : Colors.blue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    streakCount > 0 
                                        ? 'Streak Bonus Active'
                                        : 'Daily Streak',
                                    style: TextStyle(
                                      color: streakCount > 0 
                                          ? streakColor
                                          : Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  if (streakCount > 0) ...[
                                    Text(
                                      'You have a ${streakMultiplier}x point multiplier!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Progress indicator for next multiplier level
                                    if (streakCount < 7) ...[
                                      Row(
                                        children: [
                                          Text(
                                            '$streakCount',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value: streakCount / 7,
                                                backgroundColor: Colors.grey.shade200,
                                                valueColor: AlwaysStoppedAnimation<Color>(streakColor),
                                                minHeight: 10,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '7',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        streakCount >= 7 
                                            ? 'Maximum bonus achieved!'
                                            : 'Keep your streak going to reach ${streakCount < 6 ? GameConstants.getStreakMultiplier(streakCount + 1) : 3.0}x multiplier!',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.emoji_events, color: Colors.purple),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Maximum 3x multiplier achieved!',
                                              style: TextStyle(
                                                color: Colors.purple,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ] else ...[
                                    // Display for users with 0 streak
                                    Text(
                                      'Start your daily streak to earn up to 3x more points!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Example streak benefits
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Text('Day 1: '),
                                              Spacer(),
                                              Text('1.0x points', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          Divider(),
                                          Row(
                                            children: [
                                              Text('Day 3: '),
                                              Spacer(),
                                              Text('1.5x points', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                            ],
                                          ),
                                          Divider(),
                                          Row(
                                            children: [
                                              Text('Day 7+: '),
                                              Spacer(),
                                              Text('3.0x points', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                  // View details button
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'View Details',
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Daily Tasks Section
                    Text(
                      "Daily Tasks",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDailyTaskCard(
                      context,
                      title: "Spin the Wheel of Fortune",
                      subtitle: "Up to 3000 points with streak bonus!",
                      icon: Icons.rotate_right,
                      color: Colors.purple,
                      progress: (user?.dailySpinCount ?? 0) / (user?.maxDailySpins ?? 5),
                      current: user?.dailySpinCount ?? 0,
                      max: user?.maxDailySpins ?? 5,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SpinWheelScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDailyTaskCard(
                      context,
                      title: "Roll the Dice",
                      subtitle: "Up to 150 points",
                      icon: Icons.casino,
                      color: Colors.red,
                      progress: (user?.dailyDiceCount ?? 0) / (user?.maxDailyDiceRolls ?? 5),
                      current: user?.dailyDiceCount ?? 0,
                      max: user?.maxDailyDiceRolls ?? 5,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DiceGameScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDailyTaskCard(
                      context,
                      title: "Math Puzzles",
                      subtitle: "Solve puzzles to earn points",
                      icon: Icons.calculate,
                      color: Colors.indigo,
                      progress: (user?.dailyMathPuzzleCount ?? 0) / (user?.maxDailyMathPuzzles ?? 10),
                      current: user?.dailyMathPuzzleCount ?? 0,
                      max: user?.maxDailyMathPuzzles ?? 10,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MathPuzzleScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDailyTaskCard(
                      context,
                      title: "Memory Game",
                      subtitle: "Test your memory skills",
                      icon: Icons.psychology,
                      color: Colors.teal,
                      progress: (user?.dailyMemoryGameCount ?? 0) / (user?.maxDailyMemoryGames ?? 5),
                      current: user?.dailyMemoryGameCount ?? 0,
                      max: user?.maxDailyMemoryGames ?? 5,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MemoryGameScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDailyTaskCard(
                      context,
                      title: "Color Match",
                      subtitle: "Match colors quickly",
                      icon: Icons.palette,
                      color: Colors.amber,
                      progress: (user?.dailyColorMatchCount ?? 0) / (user?.maxDailyColorMatches ?? 8),
                      current: user?.dailyColorMatchCount ?? 0,
                      max: user?.maxDailyColorMatches ?? 8,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ColorMatchScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDailyTaskCard(
                      context,
                      title: "Word Game",
                      subtitle: "Test your vocabulary",
                      icon: Icons.text_fields,
                      color: Colors.green,
                      progress: (user?.dailyWordGameCount ?? 0) / (user?.maxDailyWordGames ?? 6),
                      current: user?.dailyWordGameCount ?? 0,
                      max: user?.maxDailyWordGames ?? 6,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const WordGameScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // More Ways to Earn
                    Text(
                      "More Ways to Earn",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEarningOptionCard(
                            context,
                            title: "All Games",
                            icon: Icons.games,
                            color: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const GamesMenuScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEarningOptionCard(
                            context,
                            title: "Watch Ads",
                            icon: Icons.videocam,
                            color: Color(0xFF8E44AD),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const WatchAdsScreen()),
                              );
                              // Force refresh of the provider data when returning
                              if (context.mounted) {
                                final userProvider = Provider.of<UserProvider>(context, listen: false);
                                final user = userProvider.user;
                                if (user != null) {
                                  userProvider.notifyListeners();
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEarningOptionCard(
                            context,
                            title: "Offer Wall",
                            icon: Icons.workspace_premium,
                            color: secondaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const OfferWallScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEarningOptionCard(
                            context,
                            title: "Invite Friends",
                            icon: Icons.people,
                            color: accentColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTaskCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double progress,
    required int current,
    required int max,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isCompleted = current >= max;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCompleted ? color.withOpacity(0.5) : Colors.transparent,
          width: isCompleted ? 1 : 0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        color: color,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "$current/$max",
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isCompleted
                            ? color
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningOptionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}