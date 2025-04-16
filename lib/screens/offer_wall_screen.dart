import 'package:flutter/material.dart';

class OfferWallScreen extends StatelessWidget {
  const OfferWallScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer Wall'),
      ),
      body: const Center(
        child: Text('Complete offers to earn points - Coming Soon'),
      ),
    );
  }
} 