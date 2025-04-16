import 'package:flutter/material.dart';

class DiceRollScreen extends StatelessWidget {
  const DiceRollScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Roll'),
      ),
      body: const Center(
        child: Text('Dice Roll Game - Coming Soon'),
      ),
    );
  }
} 