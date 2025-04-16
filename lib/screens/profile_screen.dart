import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/models/user_model.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/services/auth_service.dart';
import 'package:pocket_payout_bd/services/firestore_service.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  List<TransactionModel>? _transactions;
  
  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }
  
  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        _transactions = await _firestoreService.getUserTransactions(user.uid, limit: 10);
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _copyReferralCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  Future<void> _signOut() async {
    // Show confirmation dialog
    bool confirmSignOut = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmSignOut) return;
    
    try {
      // Show loading indicator
      setState(() => _isLoading = true);
      
      // Clear user data from UserProvider first
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.clearUser();
      
      // Sign out from auth service
      await _authService.signOut();
      
      // Force navigation to authentication screen for extra safety
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
      }
    } catch (e) {
      // Hide loading indicator if error occurs
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.user;
          
          if (user == null) {
            return const Center(
              child: Text('User data not available'),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () async {
              await userProvider.initUser(user.uid);
              await _loadTransactions();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info card
                    _buildUserInfoCard(context, user),
                    const SizedBox(height: 24),
                    
                    // Referral card
                    _buildReferralCard(context, user),
                    const SizedBox(height: 24),
                    
                    // Recent transactions
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _transactions == null || _transactions!.isEmpty
                            ? const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No transactions yet'),
                                ),
                              )
                            : _buildTransactionsList(),
                    
                    const SizedBox(height: 24),
                    
                    // Sign out button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildUserInfoCard(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final textTheme = theme.textTheme;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // User photo or avatar with tap to change
                GestureDetector(
                  onTap: () => _showChangeProfilePictureOptions(context),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: primaryColor.withOpacity(0.2),
                        backgroundImage: user.photoURL != null 
                            ? NetworkImage(user.photoURL!) 
                            : null,
                        child: user.photoURL == null ? Icon(
                          Icons.person,
                          size: 40,
                          color: primaryColor,
                        ) : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'BD User',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (user.email != null) ...[
                        Row(
                          children: [
                            Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user.email!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              user.phoneNumber!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Add Edit Profile Button
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditProfileDialog(context, user),
                  tooltip: 'Edit Profile',
                  color: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            
            // Stats section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      Icons.monetization_on,
                      '${user.pointsBalance}',
                      'Points',
                      Colors.amber,
                    ),
                    const VerticalDivider(thickness: 1),
                    _buildStatItem(
                      context,
                      Icons.local_fire_department,
                      '${user.streakCounter}',
                      'Day Streak',
                      Colors.orangeAccent,
                    ),
                    const VerticalDivider(thickness: 1),
                    _buildStatItem(
                      context,
                      Icons.bar_chart,
                      '${user.totalEarned}',
                      'Earned',
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Show additional user data
            if (user.referredUsers.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'You have referred ${user.referredUsers.length} friends',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            
            // Show membership info
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Member since ${_formatJoinDate(user.createdAt)}',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label, Color color) {
    final textTheme = Theme.of(context).textTheme;
    
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatJoinDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }
  
  Widget _buildReferralCard(BuildContext context, UserModel user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Invite Friends & Earn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Share your referral code with friends. When they join, both of you will earn bonus points!',
              style: TextStyle(fontSize: 14),
            ),
            
            // Show referrer information if available
            if (user.referrerInfo.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'You were referred by:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${user.referrerInfo['displayName'] ?? 'User'} (${user.referrerInfo['referralCode']})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    user.referralCode,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyReferralCode(user.referralCode),
                    tooltip: 'Copy referral code',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Add share functionality here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sharing functionality to be implemented'),
                  ),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share with Friends'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            
            // Referral history section
            if (user.referredUsers.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Referral History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              ...user.referredUsers.map((referral) => _buildReferralItem(context, referral)),
              const SizedBox(height: 8),
              Text(
                'You have referred ${user.referredUsers.length} ${user.referredUsers.length == 1 ? 'friend' : 'friends'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildReferralItem(BuildContext context, Map<String, dynamic> referral) {
    final userName = referral['name'] ?? 'User';
    final timestamp = referral['timestamp'] is DateTime 
        ? referral['timestamp'] 
        : (referral['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.green.withOpacity(0.2),
            child: const Icon(Icons.person_add, size: 16, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDate(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Text(
              '+ ${GameConstants.referrerReward} pts',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions!.length,
      itemBuilder: (context, index) {
        final transaction = _transactions![index];
        final bool isPositive = transaction.points > 0;
        
        IconData icon;
        Color color;
        
        // Determine icon and color based on transaction type
        switch (transaction.type) {
          case 'earn_spin':
            icon = Icons.rotate_right;
            color = Colors.blue;
            break;
          case 'earn_quiz':
            icon = Icons.quiz;
            color = Colors.amber;
            break;
          case 'earn_scratch':
            icon = Icons.format_paint;
            color = Colors.green;
            break;
          case 'earn_dice':
            icon = Icons.casino;
            color = Colors.purple;
            break;
          case 'earn_ad_watch':
            icon = Icons.videocam;
            color = Colors.red;
            break;
          case 'earn_offer_complete':
            icon = Icons.workspace_premium;
            color = Colors.orange;
            break;
          case 'earn_referral':
          case 'earn_referral_bonus':
            icon = Icons.people;
            color = Colors.teal;
            break;
          case 'withdrawal_request':
            icon = Icons.account_balance_wallet;
            color = Colors.red;
            break;
          default:
            icon = Icons.attach_money;
            color = Colors.grey;
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            title: Text(
              transaction.description ?? 
                  _getTransactionTypeDescription(transaction.type),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatDate(transaction.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            trailing: Text(
              '${isPositive ? '+' : ''}${transaction.points}',
              style: TextStyle(
                color: isPositive ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _getTransactionTypeDescription(String type) {
    switch (type) {
      case 'earn_spin':
        return 'Earned from Spin & Win';
      case 'earn_quiz':
        return 'Earned from Quiz Master';
      case 'earn_scratch':
        return 'Earned from Scratch Card';
      case 'earn_dice':
        return 'Earned from Dice Roll';
      case 'earn_ad_watch':
        return 'Earned from watching ad';
      case 'earn_offer_complete':
        return 'Earned from completing offer';
      case 'earn_referral':
        return 'Earned from referral';
      case 'earn_referral_bonus':
        return 'Referral bonus';
      case 'withdrawal_request':
        return 'Withdrawal request';
      default:
        return 'Transaction';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Add this method to show the edit profile dialog
  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final _displayNameController = TextEditingController(text: user.displayName);
    final _phoneNumberController = TextEditingController(text: user.phoneNumber);
    final _formKey = GlobalKey<FormState>();
    bool _isUpdating = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            _isUpdating 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _isUpdating = true;
                      });
                      
                      try {
                        // Update profile using UserProvider
                        final userProvider = Provider.of<UserProvider>(context, listen: false);
                        await userProvider.updateUserProfile(
                          displayName: _displayNameController.text.trim(),
                          phoneNumber: _phoneNumberController.text.trim(),
                        );
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        setState(() {
                          _isUpdating = false;
                        });
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating profile: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
          ],
        ),
      ),
    );
  }

  // Add this method after the _showEditProfileDialog method
  void _showChangeProfilePictureOptions(BuildContext context) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library,
                  color: theme.primaryColor,
                ),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                // This would integrate with image_picker to select from gallery
                // For now, just show a placeholder message
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gallery selection would be implemented here'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: theme.primaryColor,
                ),
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                // This would integrate with image_picker to take a photo
                // For now, just show a placeholder message
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Camera capture would be implemented here'),
                  ),
                );
              },
            ),
            if (Provider.of<UserProvider>(context, listen: false).user?.photoURL != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete,
                    color: Colors.red.shade700,
                  ),
                ),
                title: const Text('Remove Current Photo'),
                onTap: () {
                  // Implementation for removing the profile photo would go here
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile picture removal would be implemented here'),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}