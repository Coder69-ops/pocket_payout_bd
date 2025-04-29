import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pocket_payout_bd/services/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;
  final double height;
  final bool showOnTop;

  /// A reusable widget for displaying banner ads
  /// 
  /// [adSize] - The size of the banner ad (default is AdSize.banner)
  /// [height] - The height of the banner ad container
  /// [showOnTop] - Whether to show the banner at the top of the screen with a shadow
  const BannerAdWidget({
    Key? key,
    this.adSize = AdSize.banner,
    this.height = 60,
    this.showOnTop = false,
  }) : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  final AdService _adService = AdService();
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isAdLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = _adService.createBannerAd(adSize: widget.adSize);
    _bannerAd!.load().then((_) {
      if (mounted) {
        setState(() {
          _isAdLoaded = true;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isAdLoadFailed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdLoadFailed) {
      return const SizedBox.shrink(); // Don't show anything if ad failed to load
    }

    // Create the ad container
    Widget adContainer = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: _isAdLoaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
    );

    // If showing at the top, add a shadow
    if (widget.showOnTop) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: adContainer,
      );
    }

    return adContainer;
  }
}