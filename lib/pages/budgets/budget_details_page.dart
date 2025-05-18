import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import '../expenses/add_expense_page.dart';

class BudgetDetailsPage extends StatefulWidget {
  final Map<String, dynamic> budget;

  const BudgetDetailsPage({super.key, required this.budget});

  @override
  State<BudgetDetailsPage> createState() => _BudgetDetailsPageState();
}

class _BudgetDetailsPageState extends State<BudgetDetailsPage> {
  Map<String, dynamic>? _budgetData;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isLoadingExpenses = false;
  String _expenseStatusFilter = 'All';
  String _searchQuery = '';

  final List<String> _expenseStatusOptions = [
    'All',
    'Pending',
    'Approved',
    'Fraudulent',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _loadUserData();
    await _loadBudgetDetails();
    await _loadExpenses();

    setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<FirebaseAuthService>(
      context,
      listen: false,
    );
    final userData = await authService.currentUser;
    setState(() => _userData = userData);
  }

  Future<void> _loadBudgetDetails() async {
    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      final budgetData = await budgetService.getBudgetById(
        widget.budget['budget_id'],
      );

      setState(() => _budgetData = budgetData ?? widget.budget);
    } catch (e) {
      print('Error loading budget details: $e');
      setState(() => _budgetData = widget.budget);
    }
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoadingExpenses = true);

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      final expenses = await budgetService.getExpensesForBudget(
        widget.budget['budget_id'],
      );

      setState(() {
        _expenses = expenses;
        _filteredExpenses = expenses;
      });

      _applyExpenseFilters();
    } catch (e) {
      _showErrorSnackBar('Error loading expenses: $e');
    } finally {
      setState(() => _isLoadingExpenses = false);
    }
  }

  void _applyExpenseFilters() {
    setState(() {
      _filteredExpenses =
          _expenses.where((expense) {
            // Search filter
            if (_searchQuery.isNotEmpty) {
              final searchLower = _searchQuery.toLowerCase();
              final description = (expense['expense_desc'] ?? '').toLowerCase();
              final creatorName =
                  (expense['created_by_name'] ?? '').toLowerCase();

              if (!description.contains(searchLower) &&
                  !creatorName.contains(searchLower)) {
                return false;
              }
            }

            // Status filter
            if (_expenseStatusFilter != 'All' &&
                expense['status'] != _expenseStatusFilter) {
              return false;
            }

            return true;
          }).toList();
    });
  }

  bool _canCreateExpenses() {
    if (_userData?['role'] != 'Authorized Spender') return false;
    if (_budgetData?['status'] != 'Active') return false;

    // Check if user is in authorized spenders list
    final authorizedSpenders =
        _budgetData?['authorized_spenders'] as List? ?? [];
    return authorizedSpenders.any(
      (spender) => spender['account_id'] == _userData?['account_id'],
    );
  }

  bool _canManageExpenses() {
    return _userData?['role'] == 'Budget Manager' ||
        _userData?['role'] == 'Administrator';
  }

  void _createExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpensePage(budget: _budgetData!),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _updateExpenseStatus(
    Map<String, dynamic> expense,
    String newStatus, {
    String? notes,
  }) async {
    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      final success = await budgetService.updateExpenseStatus(
        expense['expense_id'],
        newStatus,
        notes: notes,
      );

      if (success) {
        _showSuccessSnackBar('Expense status updated successfully');
        _loadData();
      } else {
        _showErrorSnackBar('Failed to update expense status');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating expense status: $e');
    }
  }

  void _markExpenseAsFraudulent(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder:
          (context) => _FraudulentExpenseDialog(
            expense: expense,
            onMarked: (reason) {
              Navigator.pop(context);
              _updateExpenseStatus(expense, 'Fraudulent', notes: reason);
            },
          ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder:
          (context) => _ExpenseDetailsDialog(
            expense: expense,
            canManage: _canManageExpenses(),
            onStatusUpdate: _updateExpenseStatus,
            onMarkFraudulent: _markExpenseAsFraudulent,
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        dateTime = timestamp.toDate();
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading budget details...'),
      );
    }

    if (_budgetData == null) {
      return Scaffold(
        appBar: CustomAppBar(title: 'Budget Details'),
        body: const EmptyStateWidget(
          message: 'Budget not found',
          icon: Icons.error_outline,
        ),
      );
    }

    final budgetAmount =
        (_budgetData!['budget_amount'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (_budgetData!['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final remainingAmount = budgetAmount - totalExpenses;
    final percentageUsed =
        budgetAmount > 0 ? (totalExpenses / budgetAmount) : 0.0;
    final authorizedSpenders =
        _budgetData!['authorized_spenders'] as List? ?? [];

    Color progressColor = Colors.green;
    if (percentageUsed > 0.8) {
      progressColor = Colors.red;
    } else if (percentageUsed > 0.6) {
      progressColor = Colors.orange;
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Budget Details',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Budget Overview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _budgetData!['budget_name'] ?? 'Unnamed Budget',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _budgetData!['budget_description'] ??
                                    'No description',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          status: _budgetData!['status'] ?? 'Unknown',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Budget Statistics
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatColumn(
                            'Budget Amount',
                            _formatCurrency(budgetAmount),
                            Icons.account_balance_wallet,
                            AppTheme.primaryColor,
                          ),
                        ),
                        Expanded(
                          child: _buildStatColumn(
                            'Total Expenses',
                            _formatCurrency(totalExpenses),
                            Icons.receipt,
                            Colors.orange,
                          ),
                        ),
                        Expanded(
                          child: _buildStatColumn(
                            'Remaining',
                            _formatCurrency(remainingAmount),
                            Icons.savings,
                            remainingAmount >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        Expanded(
                          child: _buildStatColumn(
                            'Expenses',
                            '${_expenses.length}',
                            Icons.list_alt,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    if (_budgetData!['status'] == 'Active' ||
                        _budgetData!['status'] == 'Completed') ...[
                      const SizedBox(height: 24),

                      // Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Budget Usage',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${(percentageUsed * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: progressColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: percentageUsed.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressColor,
                            ),
                            minHeight: 10,
                          ),
                          if (percentageUsed > 1.0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Budget exceeded by ${_formatCurrency(totalExpenses - budgetAmount)}',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Budget Information
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            'Created by',
                            _budgetData!['created_by_name'] ?? 'Unknown',
                            Icons.person,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoRow(
                            'Created on',
                            _formatTimestamp(_budgetData!['created_at']),
                            Icons.calendar_today,
                          ),
                        ),
                      ],
                    ),

                    if (_budgetData!['notes'] != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow('Notes', _budgetData!['notes'], Icons.note),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Authorized Spenders Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authorized Spenders (${authorizedSpenders.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (authorizedSpenders.isEmpty)
                      Text(
                        'No authorized spenders assigned',
                        style: TextStyle(color: AppTheme.textSecondary),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            authorizedSpenders.map<Widget>((spender) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLightColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppTheme.primaryColor,
                                      child: Text(
                                        (spender['name'] ?? '')
                                            .split(' ')
                                            .map(
                                              (e) => e.isNotEmpty ? e[0] : '',
                                            )
                                            .join('')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      spender['name'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Expenses Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Expenses',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        if (_canCreateExpenses())
                          ElevatedButton.icon(
                            onPressed: _createExpense,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Expense'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Expense Filters
                    Row(
                      children: [
                        Expanded(
                          child: CustomSearchField(
                            hintText: 'Search expenses...',
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                              _applyExpenseFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _expenseStatusFilter,
                          items:
                              _expenseStatusOptions.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() => _expenseStatusFilter = value!);
                            _applyExpenseFilters();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Expenses List
                    if (_isLoadingExpenses)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_filteredExpenses.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _expenses.isEmpty
                                  ? 'No expenses recorded yet'
                                  : 'No expenses match your search criteria',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (_canCreateExpenses() && _expenses.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _createExpense,
                                icon: const Icon(Icons.add),
                                label: const Text('Create First Expense'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      Column(
                        children:
                            _filteredExpenses.map((expense) {
                              return _buildExpenseCard(expense);
                            }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: AppTheme.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final amount = (expense['expense_amt'] as num?)?.toDouble() ?? 0.0;
    final status = expense['status'] ?? 'Unknown';
    final hasReceipt = expense['has_receipt'] == true;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help;

    switch (status) {
      case 'Pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Fraudulent':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
    }

    return HoverCard(
      onTap: () => _showExpenseDetails(expense),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense['expense_desc'] ?? 'No description',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${expense['created_by_name'] ?? 'Unknown'} • ${_formatTimestamp(expense['created_at'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(amount),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                if (hasReceipt)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Receipt Attached',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (_canManageExpenses() && status == 'Pending') ...[
                  TextButton.icon(
                    onPressed: () => _updateExpenseStatus(expense, 'Approved'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _markExpenseAsFraudulent(expense),
                    icon: const Icon(Icons.warning, size: 16),
                    label: const Text('Fraudulent'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Fraudulent Expense Dialog
class _FraudulentExpenseDialog extends StatefulWidget {
  final Map<String, dynamic> expense;
  final Function(String reason) onMarked;

  const _FraudulentExpenseDialog({
    required this.expense,
    required this.onMarked,
  });

  @override
  State<_FraudulentExpenseDialog> createState() =>
      _FraudulentExpenseDialogState();
}

class _FraudulentExpenseDialogState extends State<_FraudulentExpenseDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Mark as Fraudulent',
        style: TextStyle(color: Colors.red[700]),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense: ${widget.expense['expense_desc']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Amount: \$${(widget.expense['expense_amt'] as num).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason for marking as fraudulent',
                hintText:
                    'Explain why this expense is considered fraudulent...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone. The expense will be marked as fraudulent and the user will be notified.',
              style: TextStyle(fontSize: 12, color: Colors.red[600]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.trim().isNotEmpty) {
              widget.onMarked(_reasonController.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text(
            'Mark as Fraudulent',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// Expense Details Dialog
class _ExpenseDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> expense;
  final bool canManage;
  final Function(Map<String, dynamic>, String, {String? notes}) onStatusUpdate;
  final Function(Map<String, dynamic>) onMarkFraudulent;

  const _ExpenseDetailsDialog({
    required this.expense,
    required this.canManage,
    required this.onStatusUpdate,
    required this.onMarkFraudulent,
  });

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        dateTime = timestamp.toDate();
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (expense['expense_amt'] as num?)?.toDouble() ?? 0.0;
    final status = expense['status'] ?? 'Unknown';
    final hasReceipt = expense['has_receipt'] == true;
    final receiptImage = expense['receipt_image'] as String?;

    return AlertDialog(
      title: Text(
        'Expense Details',
        style: TextStyle(color: AppTheme.primaryColor),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expense Information
              _buildDetailRow(
                'Description',
                expense['expense_desc'] ?? 'No description',
              ),
              _buildDetailRow('Amount', _formatCurrency(amount)),
              _buildDetailRow('Status', status),
              _buildDetailRow(
                'Created by',
                expense['created_by_name'] ?? 'Unknown',
              ),
              _buildDetailRow(
                'Created on',
                _formatTimestamp(expense['created_at']),
              ),

              if (expense['updated_at'] != null)
                _buildDetailRow(
                  'Last updated',
                  _formatTimestamp(expense['updated_at']),
                ),

              if (expense['notes'] != null)
                _buildDetailRow('Notes', expense['notes']),

              const SizedBox(height: 16),

              // Receipt Section
              if (hasReceipt && receiptImage != null) ...[
                Text(
                  'Receipt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      Uri.parse(
                        'data:image/jpeg;base64,$receiptImage',
                      ).data!.contentAsBytes(),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.error, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load receipt image',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ] else if (hasReceipt) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt, color: Colors.grey[400], size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Receipt attached but preview unavailable',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: Colors.grey[400],
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No receipt attached',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (canManage && status == 'Pending') ...[
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onStatusUpdate(expense, 'Approved');
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Approve'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onMarkFraudulent(expense);
            },
            icon: const Icon(Icons.warning),
            label: const Text('Fraudulent'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
