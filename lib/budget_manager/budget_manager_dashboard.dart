// Create a new file: lib/budget_manager/budget_manager_dashboard.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/common_widgets.dart';
import '../budgets/budget_details_page.dart';

class BudgetManagerDashboard extends StatefulWidget {
  const BudgetManagerDashboard({super.key});

  @override
  _BudgetManagerDashboardState createState() => _BudgetManagerDashboardState();
}

class _BudgetManagerDashboardState extends State<BudgetManagerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _pendingExpenses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all budgets and pending expenses
      _budgets = await _databaseService.fetchBudgets();
      _pendingExpenses = await _databaseService.fetchExpenses(
        status: 'Pending',
      );
    } catch (e) {
      print('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Format currency
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Manager Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Pending Approvals"),
            Tab(text: "All Budgets"),
          ],
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[700],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [_buildPendingApprovalsTab(), _buildAllBudgetsTab()],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchData,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.refresh),
        tooltip: 'Refresh',
      ),
    );
  }

  Widget _buildPendingApprovalsTab() {
    // Filter pending budgets and pending expenses
    final pendingBudgets =
        _budgets.where((budget) => budget['status'] == 'Pending').toList();

    if (pendingBudgets.isEmpty && _pendingExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No items pending approval',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending Budgets Section
          if (pendingBudgets.isNotEmpty) ...[
            Text(
              'Pending Budgets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            ...pendingBudgets
                .map((budget) => _buildBudgetCard(budget))
                .toList(),
            const SizedBox(height: 24),
          ],

          // Pending Expenses Section
          if (_pendingExpenses.isNotEmpty) ...[
            Text(
              'Pending Expenses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            ...(_pendingExpenses
                .map((expense) => _buildExpenseCard(expense))
                .toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildAllBudgetsTab() {
    // Group budgets by status
    final groupedBudgets = <String, List<Map<String, dynamic>>>{};

    for (var budget in _budgets) {
      final status = budget['status'] ?? 'Unknown';
      if (!groupedBudgets.containsKey(status)) {
        groupedBudgets[status] = [];
      }
      groupedBudgets[status]!.add(budget);
    }

    // Define status order
    final statusOrder = [
      'Pending',
      'Approved',
      'For Revision',
      'Denied',
      'Archived',
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search budgets...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Budgets by status
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final status in statusOrder)
                    if (groupedBudgets.containsKey(status) &&
                        groupedBudgets[status]!.isNotEmpty) ...[
                      _buildStatusHeader(status),
                      const SizedBox(height: 8),
                      ...(_filterBudgetsBySearch(
                        groupedBudgets[status]!,
                      ).map((budget) => _buildBudgetCard(budget)).toList()),
                      const SizedBox(height: 24),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterBudgetsBySearch(
    List<Map<String, dynamic>> budgets,
  ) {
    if (_searchController.text.isEmpty) {
      return budgets;
    }

    final query = _searchController.text.toLowerCase();
    return budgets.where((budget) {
      final name = budget['name']?.toString().toLowerCase() ?? '';
      final description = budget['description']?.toString().toLowerCase() ?? '';
      final submittedBy =
          budget['submittedByEmail']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          description.contains(query) ||
          submittedBy.contains(query);
    }).toList();
  }

  Widget _buildStatusHeader(String status) {
    Color color;
    switch (status) {
      case 'Pending':
        color = Colors.orange;
        break;
      case 'Approved':
        color = Colors.green;
        break;
      case 'For Revision':
        color = Colors.blue;
        break;
      case 'Denied':
        color = Colors.red;
        break;
      case 'Archived':
        color = Colors.grey;
        break;
      default:
        color = Colors.black;
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          status,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(Map<String, dynamic> budget) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BudgetDetailsPage(budgetId: budget['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      budget['name'] ?? 'Unnamed Budget',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(budget['status'] ?? 'Pending'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(budget['budget']),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                budget['description'] ?? 'No description provided',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    budget['submittedByEmail'] ?? 'Unknown',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(budget['dateSubmitted']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          _showExpenseDetails(context, expense);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    radius: 20,
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense['description'] ?? 'Unnamed Expense',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(expense['amount']),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Budget ID: ${expense['budgetId']?.toString().substring(0, 8) ?? 'N/A'}...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(expense['date']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () => _markExpenseAsFraudulent(expense['id']),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Approve'),
                    onPressed: () => _approveExpense(expense['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';

    if (date is String) {
      try {
        final DateTime dateTime = DateTime.parse(date);
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      } catch (e) {
        return date;
      }
    }

    return 'Unknown';
  }

  void _showExpenseDetails(BuildContext context, Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Expense Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Description', expense['description'] ?? 'N/A'),
                const Divider(),
                _buildInfoRow('Amount', _formatCurrency(expense['amount'])),
                const Divider(),
                _buildInfoRow('Category', expense['category'] ?? 'N/A'),
                const Divider(),
                _buildInfoRow('Date', _formatDate(expense['date'])),
                const Divider(),
                _buildInfoRow('Budget ID', expense['budgetId'] ?? 'N/A'),

                if (expense['receipt'] == 1) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Receipt',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue[800],
                    ),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _markExpenseAsFraudulent(expense['id']);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _approveExpense(expense['id']);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
        _fetchData(); // Refresh data
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
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Mark as Fraudulent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please provide a reason for flagging this expense:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason',
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
                    // Update expense status to Fraudulent
                    bool success = await _databaseService.updateExpenseStatus(
                      expenseId,
                      'Fraudulent',
                    );

                    if (success) {
                      _fetchData(); // Refresh data
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Expense marked as fraudulent'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update expense'),
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
                child: const Text('Mark as Fraudulent'),
              ),
            ],
          ),
    );
  }
}
