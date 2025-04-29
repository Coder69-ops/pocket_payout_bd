import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/services/firestore_service.dart';
import 'package:pocket_payout_bd/widgets/custom_button.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:pocket_payout_bd/models/user_model.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pointsController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _firestoreService = FirestoreService();
  
  String _withdrawalMethod = 'bkash';
  bool _isLoading = false;
  String? _errorMessage;
  late TabController _tabController;
  List<WithdrawalRequestModel> _withdrawalHistory = [];
  bool _isLoadingHistory = false;

  static const int _minWithdrawal = 20000; // 20,000 points = 20 BDT
  static const double _conversionRate = 0.001; // 1000 points = 1 BDT
  
  // Predefined withdrawal amounts
  final List<int> _quickAmounts = [20000, 50000, 100000, 200000];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWithdrawalHistory();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _accountNumberController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadWithdrawalHistory() async {
    if (_isLoadingHistory) return;
    
    setState(() {
      _isLoadingHistory = true;
    });
    
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        final history = await _firestoreService.getUserWithdrawals(user.uid);
        setState(() {
          _withdrawalHistory = history;
        });
      }
    } catch (e) {
      // Handle error silently
      debugPrint('Error loading withdrawal history: $e');
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _selectQuickAmount(int amount) {
    setState(() {
      _pointsController.text = amount.toString();
    });
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.monetization_on_outlined, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Confirm Withdrawal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please confirm your withdrawal details:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildConfirmationDetailsRow(
              'Amount:',
              '${_pointsController.text} points',
            ),
            _buildConfirmationDetailsRow(
              'Value:',
              '${(int.parse(_pointsController.text) * _conversionRate).toStringAsFixed(2)} BDT',
            ),
            _buildConfirmationDetailsRow(
              'Method:',
              _getMethodName(_withdrawalMethod),
            ),
            _buildConfirmationDetailsRow(
              'Number:',
              _accountNumberController.text,
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: Processing may take 24-48 hours.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user == null) throw Exception('User not found');

      // Process withdrawal
      final points = int.parse(_pointsController.text);
      final amount = points * _conversionRate;
      
      await _firestoreService.requestWithdrawal(
        userId: user.uid,
        points: points,
        amount: amount,
        method: _withdrawalMethod,
        accountNumber: _accountNumberController.text.trim(),
      );

      // After successful withdrawal, reload history
      _loadWithdrawalHistory();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 28),
                const SizedBox(width: 8),
                const Text('Withdrawal Requested'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your withdrawal request for $points points (${amount.toStringAsFixed(2)} BDT) '
                  'has been submitted successfully.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Processing time: 24-48 hours',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
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
      
      // Reset form
      _pointsController.clear();
      _accountNumberController.clear();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Widget _buildConfirmationDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Withdraw Points',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Request'),
            Tab(text: 'History'),
          ],
          indicatorColor: theme.primaryColor,
          indicatorWeight: 3,
          labelColor: theme.primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWithdrawalForm(),
          _buildWithdrawalHistory(),
        ],
      ),
    );
  }
  
  Widget _buildWithdrawalForm() {
    final theme = Theme.of(context);
    
    return Consumer<UserProvider>(
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
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor.withOpacity(0.7),
                        theme.primaryColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Available Balance',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        NumberFormat('#,###').format(points),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(points * _conversionRate).toStringAsFixed(2)} BDT',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick amount buttons
                Row(
                  children: [
                    const Icon(
                      Icons.flash_on,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Quick Select',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts.map((amount) {
                      final bool isEnabled = amount <= points;
                      final bool isSelected = _pointsController.text == amount.toString();
                      return InkWell(
                        onTap: isEnabled ? () => _selectQuickAmount(amount) : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.primaryColor
                                : (isEnabled ? theme.cardColor : theme.disabledColor.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? theme.primaryColor
                                  : (isEnabled ? theme.dividerColor : theme.disabledColor.withOpacity(0.3)),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${amount / 1000}k',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isEnabled ? theme.colorScheme.onSurface : theme.disabledColor),
                                ),
                              ),
                              Text(
                                '${(amount * _conversionRate).toStringAsFixed(0)} BDT',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.9)
                                      : (isEnabled ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.disabledColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Points input
                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Points to Withdraw',
                    hintText: 'Minimum ${_minWithdrawal} points',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    prefixIcon: Icon(
                      Icons.payments_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    suffixText: 'points',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter points amount';
                    }
                    final pointsVal = int.tryParse(value);
                    if (pointsVal == null) {
                      return 'Please enter a valid number';
                    }
                    if (pointsVal < _minWithdrawal) {
                      return 'Minimum withdrawal is $_minWithdrawal points';
                    }
                    if (pointsVal > userProvider.points) {
                      return 'Insufficient points balance';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    // Trigger UI update for quick amount buttons
                    setState(() {});
                  },
                ),
                if (_pointsController.text.isNotEmpty && int.tryParse(_pointsController.text) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.currency_exchange,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Value: ${(int.parse(_pointsController.text) * _conversionRate).toStringAsFixed(2)} BDT',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Withdrawal method
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdrawal Method',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildPaymentMethodOption('bkash', 'bKash'),
                          _buildPaymentMethodOption('nagad', 'Nagad'),
                          _buildPaymentMethodOption('rocket', 'Rocket'),
                          _buildPaymentMethodOption('mobile_recharge', 'Mobile'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Account/Phone number
                TextFormField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 16, letterSpacing: 1),
                  decoration: InputDecoration(
                    labelText: _getAccountLabel(),
                    hintText: 'Enter 11-digit number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    prefixIcon: Icon(
                      Icons.phone_android,
                      color: theme.colorScheme.primary,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
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

                CustomButton(
                  onPressed: _isLoading ? null : _submitWithdrawal,
                  isLoading: _isLoading,
                  text: 'REQUEST WITHDRAWAL',
                  icon: Icons.send_rounded,
                  buttonColor: theme.primaryColor,
                  isFullWidth: true,
                  height: 54,
                ),
                
                const SizedBox(height: 20),
                _WithdrawalInfoCard(),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPaymentMethodOption(String value, String label) {
    final theme = Theme.of(context);
    final bool isSelected = _withdrawalMethod == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _withdrawalMethod = value;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? theme.primaryColor : theme.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: theme.primaryColor,
                ),
              if (isSelected)
                const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getAccountLabel() {
    switch (_withdrawalMethod) {
      case 'bkash':
        return 'bKash Number';
      case 'nagad':
        return 'Nagad Number';
      case 'rocket':
        return 'Rocket Number';
      case 'mobile_recharge':
        return 'Phone Number';
      default:
        return 'Account Number';
    }
  }
  
  Widget _buildWithdrawalHistory() {
    final theme = Theme.of(context);
    
    if (_isLoadingHistory) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.primaryColor,
        ),
      );
    }
    
    if (_withdrawalHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 64,
                color: theme.primaryColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No withdrawal history yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Your withdrawal requests will appear here once you make them',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.add),
              label: const Text('Make a Withdrawal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadWithdrawalHistory,
      color: theme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _withdrawalHistory.length,
        itemBuilder: (context, index) {
          final withdrawal = _withdrawalHistory[index];
          return _WithdrawalHistoryItem(withdrawal: withdrawal);
        },
      ),
    );
  }
  
  String _getMethodName(String method) {
    switch (method.toLowerCase()) {
      case 'bkash':
        return 'bKash';
      case 'mobile_recharge':
        return 'Mobile Recharge';
      case 'nagad':
        return 'Nagad';
      case 'rocket':
        return 'Rocket';
      default:
        return method;
    }
  }
}

class _WithdrawalInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Withdrawal Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem(context, 'Minimum withdrawal: 20,000 points (20 BDT)'),
            _buildInfoItem(context, 'Processing time: 24-48 hours (weekdays)'),
            _buildInfoItem(context, 'Conversion rate: 1,000 points = 1 BDT'),
            _buildInfoItem(context, 'Mobile recharge option available for all operators'),
            _buildInfoItem(context, 'Make sure the number you provide is correct'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(BuildContext context, String text) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalHistoryItem extends StatelessWidget {
  final WithdrawalRequestModel withdrawal;
  
  const _WithdrawalHistoryItem({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(withdrawal.status);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final formattedDate = dateFormat.format(withdrawal.requestDate);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator at the top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Center(
                child: Text(
                  _getStatusText(withdrawal.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${withdrawal.amount.toStringAsFixed(2)} BDT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat('#,###').format(withdrawal.points) + ' points',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getMethodIcon(withdrawal.method),
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    context,
                    'Payment Method',
                    _getMethodName(withdrawal.method),
                  ),
                  _buildDetailRow(
                    context,
                    'Account Number',
                    _maskAccountNumber(withdrawal.accountNumber),
                  ),
                  _buildDetailRow(
                    context,
                    'Request Date',
                    formattedDate,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isLast = false}) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'completed':
        return 'COMPLETED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'bkash':
        return Icons.account_balance_wallet;
      case 'nagad':
        return Icons.account_balance_wallet;
      case 'rocket':
        return Icons.account_balance_wallet;
      case 'mobile_recharge':
        return Icons.phone_android;
      default:
        return Icons.payments;
    }
  }

  String _getMethodName(String method) {
    switch (method.toLowerCase()) {
      case 'bkash':
        return 'bKash';
      case 'mobile_recharge':
        return 'Mobile Recharge';
      case 'nagad':
        return 'Nagad';
      case 'rocket':
        return 'Rocket';
      default:
        return method;
    }
  }

  String _maskAccountNumber(String number) {
    if (number.length <= 4) return number;
    return '****${number.substring(number.length - 4)}';
  }
}