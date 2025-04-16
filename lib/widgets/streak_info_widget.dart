import 'package:flutter/material.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class StreakInfoWidget extends StatelessWidget {
  final int streakCount;
  final bool showDetailedView;
  final bool animateIcon;

  const StreakInfoWidget({
    Key? key, 
    required this.streakCount,
    this.showDetailedView = true,
    this.animateIcon = false,
  }) : super(key: key);

  Color _getStreakColor(int streakCount) {
    if (streakCount >= 7) return Colors.purple;
    if (streakCount >= 5) return Colors.orange;
    if (streakCount >= 3) return Colors.green;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final streakMultiplier = GameConstants.getStreakMultiplier(streakCount);
    final streakColor = _getStreakColor(streakCount);
    
    if (!showDetailedView) {
      // Compact view for limited space areas
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: streakColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: streakColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              color: streakColor,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '$streakCount Day Streak: ${streakMultiplier}x',
              style: TextStyle(
                color: streakColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Detailed view with all multiplier levels
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
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: streakColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedRotation(
                  turns: animateIcon ? (DateTime.now().millisecondsSinceEpoch % 10000) / 10000 : 0,
                  duration: const Duration(milliseconds: 1000),
                  child: Icon(
                    Icons.local_fire_department,
                    color: streakColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Streak: $streakCount days',
                  style: TextStyle(
                    color: streakColor,
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
                Text(
                  'Your current multiplier: ${streakMultiplier}x',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Multiplier progress visualization
                Row(
                  children: [
                    Expanded(
                      child: _buildMultiplierProgressBar(
                        context: context,
                        streakCount: streakCount,
                        streakColor: streakColor,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Multiplier levels
                const Text(
                  'Streak Multipliers',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (int day = 1; day <= 7; day++)
                      _buildDayChip(
                        day: day, 
                        streakCount: streakCount,
                        multiplier: GameConstants.streakMultipliers[day] ?? 1.0,
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Next goal text
                if (streakCount < 7)
                  Text(
                    'Keep your streak going! Log in tomorrow for ${GameConstants.getStreakMultiplier(streakCount + 1)}x multiplier',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, color: Colors.purple, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Maximum multiplier achieved!',
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplierProgressBar({
    required BuildContext context,
    required int streakCount,
    required Color streakColor,
  }) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: streakCount >= 7 ? 1.0 : streakCount / 7,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(streakColor),
            minHeight: 12,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Day 1',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              'Day 7',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayChip({
    required int day,
    required int streakCount,
    required double multiplier,
  }) {
    final bool isActive = streakCount >= day;
    final bool isCurrentDay = streakCount == day;
    
    Color chipColor;
    if (day >= 7) chipColor = Colors.purple;
    else if (day >= 5) chipColor = Colors.orange;
    else if (day >= 3) chipColor = Colors.green;
    else chipColor = Colors.blue;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? chipColor.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? chipColor.withOpacity(0.5) : Colors.grey.shade300,
          width: isCurrentDay ? 2 : 1,
        ),
        boxShadow: isCurrentDay ? [
          BoxShadow(
            color: chipColor.withOpacity(0.2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ] : null,
      ),
      child: Column(
        children: [
          Text(
            'Day $day',
            style: TextStyle(
              fontSize: 12,
              color: isActive ? chipColor : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${multiplier}x',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive ? chipColor : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
} 