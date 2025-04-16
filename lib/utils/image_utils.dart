import 'package:flutter/material.dart';

/// A utility class for safely loading and displaying images
class ImageUtils {
  /// Load an asset image with optimized settings to prevent rendering issues
  static Image loadAssetImage(
    String assetPath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Color? color,
    BlendMode? colorBlendMode,
  }) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      // Use medium quality for better performance and to avoid mipmap issues
      filterQuality: FilterQuality.medium,
      // Prevents texture generation issues
      gaplessPlayback: true,
      // Avoid frame drops during image loading
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
      // Avoid excessive memory use for large images
      excludeFromSemantics: true,
    );
  }
  
  /// Creates a widget that displays an asset image with optimized settings
  static Widget loadAssetImageWidget(
    String assetPath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Color? color,
    BlendMode? colorBlendMode,
  }) {
    return loadAssetImage(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
    );
  }
  
  /// Preload images to avoid jank when they're first shown
  static Future<void> preloadAssets(BuildContext context, List<String> assetPaths) async {
    for (final path in assetPaths) {
      precacheImage(AssetImage(path), context);
    }
  }
  
  /// Creates a circular image from an asset
  static Widget circularAssetImage(
    String assetPath, {
    required double size,
    BoxFit fit = BoxFit.cover,
  }) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: loadAssetImage(
          assetPath,
          width: size,
          height: size,
          fit: fit,
        ),
      ),
    );
  }
} 