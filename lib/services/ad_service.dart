import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pocket_payout_bd/utils/constants.dart';

class AdService {
  // Singleton pattern
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();
  
  // Ad instances
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isRewardedAdLoading = false;
  bool _isInterstitialAdLoading = false;
  
  // Getters
  bool get isRewardedAdLoading => _isRewardedAdLoading;
  bool get isRewardedAdAvailable => _rewardedAd != null;
  bool get isInterstitialAdLoading => _isInterstitialAdLoading;
  bool get isInterstitialAdAvailable => _interstitialAd != null;
  
  // Initialize the ad service
  Future<void> initialize() async {
    // Initialize Google Mobile Ads SDK
    await MobileAds.instance.initialize();
    
    // Configure for demo mode or test devices if needed
    if (kDebugMode) {
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
          testDeviceIds: ['ABCDEF123456'], // Add your test device ID here
        ),
      );
    }
    
    // Preload ads
    loadRewardedAd();
    loadInterstitialAd();
  }
  
  // Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (_isRewardedAdLoading) return;
    
    _isRewardedAdLoading = true;
    
    try {
      await RewardedAd.load(
        adUnitId: AppConstants.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('AdService: Rewarded ad loaded successfully');
            _rewardedAd = ad;
            _isRewardedAdLoading = false;
            
            _setRewardedAdCallbacks(ad);
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdService: Failed to load rewarded ad: ${error.message} (code: ${error.code})');
            _rewardedAd = null;
            _isRewardedAdLoading = false;
            
            // Retry after a delay
            Future.delayed(const Duration(minutes: 1), () {
              loadRewardedAd();
            });
          },
        ),
      );
    } catch (e) {
      debugPrint('AdService: Error loading rewarded ad: $e');
      _isRewardedAdLoading = false;
    }
  }
  
  // Set rewarded ad callbacks
  void _setRewardedAdCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdService: Rewarded ad dismissed');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load a new ad when the current one is dismissed
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdService: Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Try to load a new ad after failure
      },
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdService: Rewarded ad showed fullscreen content');
      },
      onAdImpression: (ad) {
        debugPrint('AdService: Rewarded ad impression recorded');
      },
    );
  }
  
  // Show rewarded ad and handle reward callback
  Future<bool> showRewardedAd({
    required Function(AdWithoutView ad, RewardItem reward) onUserEarnedReward,
  }) async {
    if (_rewardedAd == null) {
      debugPrint('AdService: Tried to show rewarded ad, but none was loaded');
      // Try to load a new ad
      loadRewardedAd();
      return false;
    }
    
    try {
      await _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
      // Set to null to prevent repeated use of the same ad
      _rewardedAd = null;
      return true;
    } catch (e) {
      debugPrint('AdService: Error showing rewarded ad: $e');
      _rewardedAd = null;
      // Try to load a new ad after error
      loadRewardedAd();
      return false;
    }
  }
  
  // Load an interstitial ad
  Future<void> loadInterstitialAd() async {
    if (_isInterstitialAdLoading) return;
    
    _isInterstitialAdLoading = true;
    
    try {
      await InterstitialAd.load(
        adUnitId: AppConstants.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('AdService: Interstitial ad loaded successfully');
            _interstitialAd = ad;
            _isInterstitialAdLoading = false;
            
            _setInterstitialAdCallbacks(ad);
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdService: Failed to load interstitial ad: ${error.message} (code: ${error.code})');
            _interstitialAd = null;
            _isInterstitialAdLoading = false;
            
            // Retry after a delay
            Future.delayed(const Duration(minutes: 1), () {
              loadInterstitialAd();
            });
          },
        ),
      );
    } catch (e) {
      debugPrint('AdService: Error loading interstitial ad: $e');
      _isInterstitialAdLoading = false;
    }
  }
  
  // Set interstitial ad callbacks
  void _setInterstitialAdCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdService: Interstitial ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Load a new ad when the current one is dismissed
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdService: Interstitial ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Try to load a new ad after failure
      },
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdService: Interstitial ad showed fullscreen content');
      },
      onAdImpression: (ad) {
        debugPrint('AdService: Interstitial ad impression recorded');
      },
    );
  }
  
  // Show interstitial ad
  Future<bool> showInterstitialAd({
    Function? onAdDismissed,
  }) async {
    if (_interstitialAd == null) {
      debugPrint('AdService: Tried to show interstitial ad, but none was loaded');
      // Try to load a new ad
      loadInterstitialAd();
      return false;
    }
    
    try {
      // Save the callback to execute after ad is dismissed
      if (onAdDismissed != null) {
        final originalCallback = _interstitialAd!.fullScreenContentCallback;
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            // Call the original callback first
            if (originalCallback?.onAdDismissedFullScreenContent != null) {
              originalCallback!.onAdDismissedFullScreenContent!(ad);
            }
            // Then execute the provided callback
            onAdDismissed();
          },
          onAdFailedToShowFullScreenContent: originalCallback?.onAdFailedToShowFullScreenContent,
          onAdShowedFullScreenContent: originalCallback?.onAdShowedFullScreenContent,
          onAdImpression: originalCallback?.onAdImpression,
        );
      }
      
      await _interstitialAd!.show();
      // The ad will be set to null in the callback after being shown
      return true;
    } catch (e) {
      debugPrint('AdService: Error showing interstitial ad: $e');
      _interstitialAd = null;
      // Try to load a new ad after error
      loadInterstitialAd();
      return false;
    }
  }
  
  // Create a banner ad with specified size
  BannerAd createBannerAd({AdSize adSize = AdSize.banner}) {
    return BannerAd(
      adUnitId: AppConstants.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdService: Banner ad loaded successfully');
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('AdService: Banner ad failed to load: $error');
          ad.dispose();
        },
        onAdOpened: (Ad ad) {
          debugPrint('AdService: Banner ad opened');
        },
        onAdClosed: (Ad ad) {
          debugPrint('AdService: Banner ad closed');
        },
        onAdImpression: (Ad ad) {
          debugPrint('AdService: Banner ad impression recorded');
        },
      ),
    );
  }
  
  // Dispose ad instances
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}