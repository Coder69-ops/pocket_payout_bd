import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String type; // 'earn_spin', 'earn_quiz', 'withdraw_request', etc.
  final int points;
  final String? description;
  final DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.points,
    this.description,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TransactionModel.fromMap(Map<String, dynamic> data, String id) {
    return TransactionModel(
      id: id,
      userId: data['userId'],
      type: data['type'],
      points: data['points'],
      description: data['description'],
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'points': points,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}