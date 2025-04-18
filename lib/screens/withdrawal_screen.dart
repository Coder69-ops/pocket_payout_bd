import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/services/auth_service.dart';
import 'package:pocket_payout_bd/services/firestore_service.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pointsController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _otpController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  
  String _withdrawalMethod = 'bkash';
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _verificationId;
  String? _errorMessage;

  static const int _minWithdrawal = 20000; // 20,000 points = 20 BDT
  static const double _conversionRate = 0.001; // 1000 points = 1 BDT

  @override
  void dispose() {
    _pointsController.dispose();
    _accountNumberController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _initiateWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user == null) throw Exception('User not found');

      final String phoneNumber = user.phoneNumber ?? '';
      if (phoneNumber.isEmpty) {
        setState(() {
          _errorMessage = 'No phone number associated with your account';
          _isLoading = false;
        });
        return;
      }
      
      // Start verification
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification not handled for withdrawals for security
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.message ?? 'Verification failed. Please try again.';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isVerifying = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _verifyAndWithdraw() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Verify OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await _authService.signInWithCredential(credential);

      // Process withdrawal
      final points = int.parse(_pointsController.text);
      final amount = points * _conversionRate;
      
      await _firestoreService.requestWithdrawal(
        userId: Provider.of<UserProvider>(context, listen: false).user!.uid,
        points: points,
        amount: amount,
        method: _withdrawalMethod,
        accountNumber: _accountNumberController.text.trim(),
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Withdrawal Requested'),
            content: Text(
              'Your withdrawal request for $points points (${amount.toStringAsFixed(2)} BDT) '
              'has been submitted successfully. Please allow 24-48 hours for processing.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                    ..pop() // Close dialog
                    ..pop(); // Close withdrawal screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Points'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final points = userProvider.points;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Balance display
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            '$points',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const Text('Available Points'),
                          const SizedBox(height: 8),
                          Text(
                            '${(points * _conversionRate).toStringAsFixed(2)} BDT',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  if (!_isVerifying) ...[
                    // Points input
                    TextFormField(
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Points to Withdraw',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter points amount';
                        }
                        final points = int.tryParse(value);
                        if (points == null) {
                          return 'Please enter a valid number';
                        }
                        if (points < _minWithdrawal) {
                          return 'Minimum withdrawal is $_minWithdrawal points';
                        }
                        if (points > userProvider.points) {
                          return 'Insufficient points balance';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Withdrawal method
                    DropdownButtonFormField<String>(
                      value: _withdrawalMethod,
                      decoration: const InputDecoration(
                        labelText: 'Withdrawal Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'bkash',
                          child: Text('bKash'),
                        ),
                        DropdownMenuItem(
                          value: 'mobile_recharge',
                          child: Text('Mobile Recharge'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _withdrawalMethod = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Account/Phone number
                    TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: _withdrawalMethod == 'bkash'
                            ? 'bKash Number'
                            : 'Phone Number',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a number';
                        }
                        if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                          return 'Please enter a valid 11-digit number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _initiateWithdrawal,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Request Withdrawal'),
                    ),
                  ] else ...[
                    // OTP verification
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Verification Code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAndWithdraw,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Verify & Withdraw'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}