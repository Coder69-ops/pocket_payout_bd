import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:pocket_payout_bd/services/ad_service.dart';
import 'dart:async';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'dart:math';

class WatchAdsScreen extends StatefulWidget {
  const WatchAdsScreen({Key? key}) : super(key: key);

  @override
  State<WatchAdsScreen> createState() => _WatchAdsScreenState();
}

class _WatchAdsScreenState extends State<WatchAdsScreen> with SingleTickerProviderStateMixin {
  final AdService _adService = AdService();
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  bool _isInterstitialAdLoading = false;
  bool _isBannerAdLoaded = false;
  bool _isAwarding = false;
  Timer? _cooldownTimer;
  int _watchCount = 0;
  int _maxDailyWatches = 20;
  int _remainingWatches = 20;
  int _pointsPerAd = GameConstants.basePoints['watch_ad'] ?? 50;
  int _lastEarnedPoints = 0;
  int _totalPointsEarned = 0;
  int _cooldownSeconds = 0;
  int _streakCount = 0;
  bool _isStreakActive = false;
  
  // Animation controller for pulse effect
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  // Confetti controller for celebration
  late ConfettiController _confettiController;
  
  // List of rewarded ad types with varying point values
  final List<Map<String, dynamic>> _adTypes = [
    {
      'name': 'Standard Ad',
      'pointsMultiplier': 1.0,
      'icon': Icons.videocam,
      'color': Colors.blue,
      'description': 'Watch a short video ad',
      'cooldown': 60, // seconds
    },
    {
      'name': 'Premium Ad',
      'pointsMultiplier': 1.5,
      'icon': Icons.stars,
      'color': Colors.purple,
      'description': 'Watch a longer video for more points',
      'cooldown': 120, // seconds
    },
    {
      'name': 'Survey Ad',
      'pointsMultiplier': 2.0,
      'icon': Icons.poll,
      'color': Colors.orange,
      'description': 'Complete a short survey',
      'cooldown': 180, // seconds
    },
  ];
  
  // Currently selected ad type index
  int _selectedAdTypeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadInterstitialAd();
    _loadBannerAd();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Start pulsing animation
    _animationController.repeat(reverse: true);
    
    // Initialize confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }
  
  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user != null) {
      setState(() {
        _streakCount = user.streakCounter;
        _isStreakActive = _streakCount >= 1; // Any streak is now active with the new system
        
        // Use database values for watch count and remaining watches
        _watchCount = user.dailyAdWatchCount;
        _maxDailyWatches = user.maxDailyAdWatches;
        _remainingWatches = user.remainingAdWatches;
        
        // Use database values for earnings
        _totalPointsEarned = user.todayAdEarnings;
        _lastEarnedPoints = user.lastAdEarnings;
      });
    }
  }

  void _loadInterstitialAd() {
    setState(() {
      _isInterstitialAdLoading = true;
    });
    
    // Use AdService to load the interstitial ad
    _adService.loadInterstitialAd();
    
    // Set up a periodic check to monitor ad availability
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Check if ad is available from AdService
        final bool isAdAvailable = _adService.isInterstitialAdAvailable;
        
        if (isAdAvailable) {
          setState(() {
            _isInterstitialAdLoading = false;
          });
          
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }
  
  void _loadBannerAd() {
    _bannerAd = _adService.createBannerAd();
    _bannerAd!.load().then((_) {
      if (mounted) {
        setState(() {
          _isBannerAdLoaded = true;
        });
      }
    });
  }
  
  Future<void> _showRewardedAd() async {
    if (!_adService.isRewardedAdAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready. Please try again.')),
      );
      return;
    }
    
    if (_cooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait $_cooldownSeconds seconds before watching another ad')),
      );
      return;
    }
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Show ad using the AdService
    final bool success = await _adService.showRewardedAd(
      onUserEarnedReward: (ad, reward) {
        _processReward();
      },
    );
    
    if (success) {
      // Start cooldown timer
      _startCooldown();
    }
  }
  
  Future<void> _showInterstitialAd() async {
    if (!_adService.isInterstitialAdAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready. Please try again.')),
      );
      return;
    }
    
    if (_cooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait $_cooldownSeconds seconds before watching another ad')),
      );
      return;
    }
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Show ad using AdService
    final bool success = await _adService.showInterstitialAd(
      onAdDismissed: () {
        // Process reward after ad is dismissed
        _processReward();
      },
    );
    
    if (success) {
      // Start cooldown timer
      _startCooldown();
    }
  }
  
  void _startCooldown() {
    // Set cooldown based on selected ad type
    setState(() {
      _cooldownSeconds = _adTypes[_selectedAdTypeIndex]['cooldown'] as int;
    });
    
    // Cancel any existing timer
    _cooldownTimer?.cancel();
    
    // Start new cooldown timer
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }
  
  Future<void> _processReward() async {
    if (_isAwarding) return;
    
    setState(() {
      _isAwarding = true;
    });
    
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      
      if (user == null) {
        throw Exception('User data not available');
      }
      
      // Update watch count and check if limit reached
      final newWatchCount = user.dailyAdWatchCount + 1;
      if (newWatchCount > _maxDailyWatches) {
        throw Exception('Daily watch limit reached');
      }
      
      // Calculate points based on selected ad type
      final int basePoints = _pointsPerAd;
      final adMultiplier = _adTypes[_selectedAdTypeIndex]['pointsMultiplier'] as double;
      final streakMultiplier = GameConstants.getStreakMultiplier(_streakCount);
      
      // Calculate final earnings with all multipliers
      final earnedPoints = (basePoints * adMultiplier * streakMultiplier).round();
      
      // Update points in user's account
      await userProvider.updatePoints(
        earnedPoints,
        TransactionTypes.earnAd,
        description: 'Earned from watching ${_adTypes[_selectedAdTypeIndex]['name']}',
      );
      
      // Update ad watch counter
      await userProvider.incrementDailyCounter('ad_watch');
      
      // Update ad earnings record
      await userProvider.updateAdEarnings(earnedPoints);
      
      // Update local state
      setState(() {
        _watchCount++;
        _remainingWatches--;
        _lastEarnedPoints = earnedPoints;
        _totalPointsEarned += earnedPoints;
        _isAwarding = false;
      });
      
      // Play confetti and show reward dialog
      _confettiController.play();
      _showRewardDialog(earnedPoints, adMultiplier, streakMultiplier);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isAwarding = false;
      });
    }
  }
  
  void _showRewardDialog(int points, double adMultiplier, double streakMultiplier) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Points Earned!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$points',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (adMultiplier > 1.0 || streakMultiplier > 1.0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Rewards Breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Base:',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '$_pointsPerAd points',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (adMultiplier > 1.0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Ad Bonus:',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '${adMultiplier}x',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (streakMultiplier > 1.0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Streak Bonus:',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '${streakMultiplier}x',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'CONTINUE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    _cooldownTimer?.cancel();
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch & Earn'),
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withOpacity(0.3),
                  Colors.white,
                ],
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stats dashboard
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Today',
                            '$_totalPointsEarned',
                            'pts',
                            Icons.timeline,
                            Colors.green,
                          ),
                          _buildStatItem(
                            'Last Earned',
                            '$_lastEarnedPoints',
                            'pts',
                            Icons.monetization_on,
                            Colors.amber,
                          ),
                          _buildStatItem(
                            'Remaining',
                            '$_remainingWatches',
                            'ads',
                            Icons.videocam,
                            Colors.blue,
                          ),
                        ],
                      ),
                      if (_isStreakActive) ...[
                        const SizedBox(height: 16),
                        _buildStreakInfo(),
                      ],
                    ],
                  ),
                ),
                
                // Ad type selection
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose an Ad Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _adTypes.length,
                          itemBuilder: (context, index) {
                            final adType = _adTypes[index];
                            final isSelected = _selectedAdTypeIndex == index;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAdTypeIndex = index;
                                });
                                // Provide haptic feedback
                                HapticFeedback.selectionClick();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? (adType['color'] as Color).withOpacity(0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? adType['color'] as Color
                                        : Colors.grey.withOpacity(0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: (adType['color'] as Color).withOpacity(0.2),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      adType['icon'] as IconData,
                                      color: adType['color'] as Color,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      adType['name'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? adType['color'] as Color
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(adType['pointsMultiplier'] as double).toStringAsFixed(1)}x',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Ad description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adTypes[_selectedAdTypeIndex]['name'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _adTypes[_selectedAdTypeIndex]['description'] as String,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(color: Colors.grey[700]),
                                children: [
                                  const TextSpan(text: 'Points: '),
                                  TextSpan(
                                    text: '${(_pointsPerAd * (_adTypes[_selectedAdTypeIndex]['pointsMultiplier'] as double)).round()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(color: Colors.grey[700]),
                                children: [
                                  const TextSpan(text: 'Cooldown: '),
                                  TextSpan(
                                    text: '${_adTypes[_selectedAdTypeIndex]['cooldown']} seconds',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Watch ad button with countdown
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _cooldownSeconds == 0 ? _pulseAnimation.value : 1.0,
                            child: ElevatedButton(
                              onPressed: (_adService.isRewardedAdAvailable && _cooldownSeconds == 0 && !_isAwarding)
                                  ? _showRewardedAd
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: _cooldownSeconds == 0 ? 4 : 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _adService.isRewardedAdLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          _adTypes[_selectedAdTypeIndex]['icon'] as IconData,
                                          size: 24,
                                        ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _cooldownSeconds > 0
                                        ? 'WAIT $_cooldownSeconds SECONDS'
                                        : 'WATCH & EARN',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      if (_isBannerAdLoaded && _bannerAd != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
              numberOfParticles: 30,
              gravity: 0.05,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.amber,
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String title, String value, String unit, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
  
  // Display information about streak bonus in the UI
  Widget _buildStreakInfo() {
    if (_streakCount <= 0) return const SizedBox.shrink();
    
    final double multiplier = GameConstants.getStreakMultiplier(_streakCount);
    final Color streakColor = _getStreakColor(_streakCount);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: streakColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: streakColor.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: streakColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '$_streakCount Day Streak: ${multiplier}x Points',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: streakColor,
            ),
          ),
        ],
      ),
    );
  }
  
  // Get streak color based on streak count
  Color _getStreakColor(int streakCount) {
    if (streakCount >= 7) return Colors.purple;
    if (streakCount >= 5) return Colors.orange;
    if (streakCount >= 3) return Colors.green;
    return Colors.blue;
  }
}