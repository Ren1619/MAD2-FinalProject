import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';
import '../theme.dart';
import '../authorized_spender/add_expense_form.dart';

class BudgetDetailsPage extends StatefulWidget {
  final String budgetId;

  const BudgetDetailsPage({super.key, required this.budgetId});

  @override
  _BudgetDetailsPageState createState() => _BudgetDetailsPageState();
}

class _BudgetDetailsPageState extends State<BudgetDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _budget;
  List<Map<String, dynamic>> _expenses = [];
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBudgetDetails();
    _loadUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await _authService.currentUser;
      if (user != null) {
        setState(() {
          _userRole = user['role'];
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }

  Future<void> _loadBudgetDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load budget details
      _budget = await _databaseService.getBudgetById(widget.budgetId);

      // Load expenses
      _expenses = await _databaseService.fetchExpenses(
        budgetId: widget.budgetId,
      );
    } catch (e) {
      print('Error loading budget details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '\$0.00';

    double numAmount;
    if (amount is double) {
      numAmount = amount;
    } else if (amount is int) {
      numAmount = amount.toDouble();
    } else if (amount is String) {
      numAmount = double.tryParse(amount) ?? 0.0;
    } else {
      numAmount = 0.0;
    }

    return '\$${numAmount.toStringAsFixed(2)}';
  }

  // Calculate budget metrics
  Map<String, dynamic> _calculateBudgetMetrics() {
    double totalBudget = _budget?['budget'] ?? 0.0;
    double totalSpent = 0.0;

    // Calculate total approved expenses
    for (var expense in _expenses) {
      if (expense['status'] == 'Approved') {
        totalSpent +=
            expense['amount'] is double
                ? expense['amount']
                : double.tryParse(expense['amount'].toString()) ?? 0.0;
      }
    }

    double percentageSpent = totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;
    double remaining = totalBudget - totalSpent;

    return {
      'totalBudget': totalBudget,
      'totalSpent': totalSpent,
      'percentageSpent': percentageSpent,
      'remaining': remaining,
    };
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _calculateBudgetMetrics();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _budget?['name'] ?? 'Budget Details',
          style: TextStyle(color: AppTheme.primaryColor),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBudgetDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Budget summary card
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _budget?['name'] ?? 'Unnamed Budget',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                _buildStatusChip(
                                  _budget?['status'] ?? 'Pending',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Budget',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatCurrency(metrics['totalBudget']),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spent',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatCurrency(metrics['totalSpent']),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Remaining',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatCurrency(metrics['remaining']),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color:
                                              metrics['remaining'] < 0
                                                  ? Colors.red[700]
                                                  : Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Progress bar
                            LinearProgressIndicator(
                              value:
                                  metrics['percentageSpent'] > 1.0
                                      ? 1.0
                                      : metrics['percentageSpent'],
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                metrics['percentageSpent'] > 0.9
                                    ? Colors.red
                                    : metrics['percentageSpent'] > 0.7
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              minHeight: 10,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(metrics['percentageSpent'] * 100).toStringAsFixed(1)}% Used',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tabs for Details and Expenses
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue[700],
                    unselectedLabelColor: Colors.grey[600],
                    tabs: const [Tab(text: 'DETAILS'), Tab(text: 'EXPENSES')],
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_buildDetailsTab(), _buildExpensesTab()],
                    ),
                  ),
                ],
              ),
      floatingActionButton:
          _userRole == 'Authorized Spender' && _tabController.index == 1
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddExpenseForm(
                            budgetId: widget.budgetId,
                            budgetName: _budget?['name'] ?? 'Budget',
                            budgetAmount: metrics['remaining'],
                            onExpenseAdded: _loadBudgetDetails,
                          ),
                    ),
                  );
                },
                backgroundColor: Colors.blue[700],
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  Widget _buildStatusChip(String status) {
    Color statusColor;
    switch (status) {
      case 'Pending':
        statusColor = Colors.orange;
        break;
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'For Revision':
        statusColor = Colors.blue;
        break;
      case 'Denied':
        statusColor = Colors.red;
        break;
      case 'Archived':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.black;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description section
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_budget?['description'] ?? 'No description provided'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Additional details section
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Department', _budget?['department'] ?? 'N/A'),
                  const Divider(),
                  _buildInfoRow('Quarter', _budget?['quarter'] ?? 'N/A'),
                  const Divider(),
                  _buildInfoRow('Category', _budget?['category'] ?? 'N/A'),
                  const Divider(),
                  _buildInfoRow(
                    'Created By',
                    _budget?['submittedByEmail'] ?? 'N/A',
                  ),
                  const Divider(),
                  _buildInfoRow(
                    'Date Submitted',
                    _formatDate(_budget?['dateSubmitted']),
                  ),

                  // Show additional information based on status
                  if (_budget?['status'] == 'Approved') ...[
                    const Divider(),
                    _buildInfoRow(
                      'Date Approved',
                      _formatDate(_budget?['dateApproved']),
                    ),
                  ],

                  if (_budget?['status'] == 'For Revision') ...[
                    const Divider(),
                    _buildInfoRow(
                      'Revision Requested',
                      _formatDate(_budget?['revisionRequested']),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Revision Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Text(
                        _budget?['revisionNotes'] ?? 'No notes provided',
                      ),
                    ),
                  ],

                  if (_budget?['status'] == 'Denied') ...[
                    const Divider(),
                    _buildInfoRow(
                      'Date Denied',
                      _formatDate(_budget?['dateDenied']),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Denial Reason',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        _budget?['denialReason'] ?? 'No reason provided',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Authorized spenders section
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Authorized Spenders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Replace with actual authorized spenders
                  if (_budget?['authorizedSpenders'] == null ||
                      (_budget?['authorizedSpenders'] as List).isEmpty)
                    Text(
                      'No authorized spenders assigned to this budget',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Column(
                      children:
                          (_budget?['authorizedSpenders'] as List).map<Widget>((
                            spenderId,
                          ) {
                            // In a real implementation, we would fetch the user information
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text('Authorized User'),
                              subtitle: Text('ID: $spenderId'),
                            );
                          }).toList(),
                    ),
                ],
              ),
            ),
          ),

          // Action buttons based on status and role
          if (_userRole == 'Budget Manager' ||
              _userRole == 'Company Admin') ...[
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No expenses yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (_userRole == 'Authorized Spender')
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
                onPressed: () {
                  final metrics = _calculateBudgetMetrics();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddExpenseForm(
                            budgetId: widget.budgetId,
                            budgetName: _budget?['name'] ?? 'Budget',
                            budgetAmount: metrics['remaining'],
                            onExpenseAdded: _loadBudgetDetails,
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(
                expense['category'],
              ).withOpacity(0.2),
              child: Icon(
                _getCategoryIcon(expense['category']),
                color: _getCategoryColor(expense['category']),
                size: 20,
              ),
            ),
            title: Text(
              expense['description'] ?? 'No description',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(expense['amount']),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatDate(expense['date']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          expense['status'],
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        expense['status'] ?? 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(expense['status']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (expense['receipt'] == 1) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.receipt, size: 14, color: Colors.green[700]),
                    ],
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showExpenseOptions(context, expense),
            ),
            onTap: () => _showExpenseDetails(context, expense),
          ),
        );
      },
    );
  }

  // Helper methods
  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Office Supplies':
        return Colors.blue;
      case 'Travel':
        return Colors.green;
      case 'Meals':
        return Colors.orange;
      case 'Software':
        return Colors.purple;
      case 'Hardware':
        return Colors.red;
      case 'Services':
        return Colors.teal;
      case 'Marketing':
        return Colors.pink;
      case 'Events':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Office Supplies':
        return Icons.business_center;
      case 'Travel':
        return Icons.flight;
      case 'Meals':
        return Icons.restaurant;
      case 'Software':
        return Icons.code;
      case 'Hardware':
        return Icons.computer;
      case 'Services':
        return Icons.miscellaneous_services;
      case 'Marketing':
        return Icons.campaign;
      case 'Events':
        return Icons.event;
      default:
        return Icons.category;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Denied':
        return Colors.red;
      case 'Fraudulent':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    if (date is String) {
      try {
        final DateTime dateTime = DateTime.parse(date);
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      } catch (e) {
        return date;
      }
    }

    return 'N/A';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = _budget?['status'] ?? 'Pending';

    if (status == 'Pending' &&
        (_userRole == 'Budget Manager' || _userRole == 'Company Admin')) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showRejectDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showRevisionDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: BorderSide(color: Colors.orange),
              ),
              child: const Text('Request Revision'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _approveBudget(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve'),
            ),
          ),
        ],
      );
    } else if (status == 'For Revision' &&
        _userRole == 'Financial Planning and Analysis Manager') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            // Navigate to edit budget form
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
          child: const Text('Edit Budget'),
        ),
      );
    } else if (status == 'Denied' &&
        _userRole == 'Financial Planning and Analysis Manager') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _resubmitBudget(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Resubmit Budget'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Budget action methods
  Future<void> _approveBudget(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await _databaseService.updateBudgetStatus(
        widget.budgetId,
        'Approved',
      );

      if (success) {
        _loadBudgetDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget approved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve budget')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reject Budget'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please provide a reason for rejecting this budget:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter rejection reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (reasonController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a reason')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    bool success = await _databaseService.updateBudgetStatus(
                      widget.budgetId,
                      'Denied',
                      notes: reasonController.text,
                    );

                    if (success) {
                      _loadBudgetDetails();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Budget rejected')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to reject budget'),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject'),
              ),
            ],
          ),
    );
  }

  void _showRevisionDialog(BuildContext context) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Request Revision'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please provide details on what needs to be revised:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter revision notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (notesController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter revision notes'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    bool success = await _databaseService.updateBudgetStatus(
                      widget.budgetId,
                      'For Revision',
                      notes: notesController.text,
                    );

                    if (success) {
                      _loadBudgetDetails();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Revision requested')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to request revision'),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Request Revision'),
              ),
            ],
          ),
    );
  }

  Future<void> _resubmitBudget(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await _databaseService.updateBudgetStatus(
        widget.budgetId,
        'Pending',
      );

      if (success) {
        _loadBudgetDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget resubmitted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resubmit budget')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Expense action methods
  void _showExpenseDetails(BuildContext context, Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Expense Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Description', expense['description'] ?? 'N/A'),
                  const Divider(),
                  _buildInfoRow('Amount', _formatCurrency(expense['amount'])),
                  const Divider(),
                  _buildInfoRow('Category', expense['category'] ?? 'N/A'),
                  const Divider(),
                  _buildInfoRow(
                    'Payment Method',
                    expense['paymentMethod'] ?? 'N/A',
                  ),
                  const Divider(),
                  _buildInfoRow('Date', _formatDate(expense['date'])),
                  const Divider(),
                  _buildInfoRow('Status', expense['status'] ?? 'Pending'),

                  if (expense['receipt'] == 1) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Receipt',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),

              // Only show action buttons for budget managers and admins
              if (_userRole == 'Budget Manager' ||
                  _userRole == 'Company Admin') ...[
                if (expense['status'] == 'Pending')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _markExpenseAsFraudulent(expense['id']);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Mark as Fraudulent'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveExpense(expense['id']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
    );
  }

  void _showExpenseOptions(BuildContext context, Map<String, dynamic> expense) {
    final String status = expense['status'] ?? 'Pending';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View Details'),
                  onTap: () {
                    Navigator.pop(context);
                    _showExpenseDetails(context, expense);
                  },
                ),

                if (_userRole == 'Budget Manager' ||
                    _userRole == 'Company Admin') ...[
                  if (status == 'Pending')
                    ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: const Text('Approve Expense'),
                      onTap: () {
                        Navigator.pop(context);
                        _approveExpense(expense['id']);
                      },
                    ),

                  if (status == 'Pending')
                    ListTile(
                      leading: const Icon(Icons.warning, color: Colors.red),
                      title: const Text('Mark as Fraudulent'),
                      onTap: () {
                        Navigator.pop(context);
                        _markExpenseAsFraudulent(expense['id']);
                      },
                    ),
                ],

                if (_userRole == 'Authorized Spender' && status == 'Pending')
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Expense'),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteExpense(expense['id']);
                    },
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _approveExpense(String expenseId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await _databaseService.updateExpenseStatus(
        expenseId,
        'Approved',
      );

      if (success) {
        _loadBudgetDetails();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense approved')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve expense')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markExpenseAsFraudulent(String expenseId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await _databaseService.updateExpenseStatus(
        expenseId,
        'Fraudulent',
      );

      if (success) {
        _loadBudgetDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense marked as fraudulent')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to mark expense')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
              'Are you sure you want to delete this expense?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    bool success = await _databaseService.deleteExpense(
                      expenseId,
                    );

                    if (success) {
                      _loadBudgetDetails();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense deleted')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to delete expense'),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
