import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';

// If the packages aren't already in your pubspec.yaml, run:
// flutter pub add intl
// flutter pub add percent_indicator

class BudgetDetailsPage extends StatefulWidget {
  final Map<String, dynamic> budget;

  const BudgetDetailsPage({super.key, required this.budget});

  @override
  _BudgetDetailsPageState createState() => _BudgetDetailsPageState();
}

class _BudgetDetailsPageState extends State<BudgetDetailsPage> {
  bool _isLoading = false;
  String _activeTab = "Details";

  // Format currency
  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  // Get color for status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'For Revision':
        return Colors.blue;
      case 'Denied':
        return Colors.red;
      case 'Archived':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  // Sample expenses data
  // In a real app, this would be fetched from your backend
  List<Map<String, dynamic>> get _expenses {
    return [
      {
        'id': 'EXP-001',
        'description': 'Office supplies purchase',
        'amount': 250.75,
        'date': DateTime.now().subtract(const Duration(days: 2)),
        'category': 'Supplies',
        'approvedBy': 'Jane Smith',
        'receipt': true,
        'status': 'Approved',
        'paymentMethod': 'Corporate Card',
      },
      {
        'id': 'EXP-002',
        'description': 'Team lunch meeting',
        'amount': 175.25,
        'date': DateTime.now().subtract(const Duration(days: 4)),
        'category': 'Meals',
        'approvedBy': 'Jane Smith',
        'receipt': true,
        'status': 'Approved',
        'paymentMethod': 'Reimbursement',
      },
      {
        'id': 'EXP-003',
        'description': 'Software subscription renewal',
        'amount': 499.99,
        'date': DateTime.now().subtract(const Duration(days: 7)),
        'category': 'Software',
        'approvedBy': 'Robert Brown',
        'receipt': true,
        'status': 'Approved',
        'paymentMethod': 'Corporate Card',
      },
      {
        'id': 'EXP-004',
        'description': 'Client meeting transportation',
        'amount': 89.50,
        'date': DateTime.now().subtract(const Duration(days: 10)),
        'category': 'Travel',
        'approvedBy': 'Pending',
        'receipt': true,
        'status': 'Pending',
        'paymentMethod': 'Reimbursement',
      },
      {
        'id': 'EXP-005',
        'description': 'Conference registration fees',
        'amount': 899.00,
        'date': DateTime.now().subtract(const Duration(days: 15)),
        'category': 'Events',
        'approvedBy': 'Robert Brown',
        'receipt': true,
        'status': 'Approved',
        'paymentMethod': 'Corporate Card',
      },
    ];
  }

  // Calculate budget metrics
  Map<String, dynamic> get _budgetMetrics {
    double totalSpent = 0;
    double totalBudget = widget.budget['budget'];

    // Calculate total expenses
    for (var expense in _expenses) {
      if (expense['status'] == 'Approved') {
        totalSpent += expense['amount'];
      }
    }

    double percentageSpent = totalSpent / totalBudget;
    double remaining = totalBudget - totalSpent;

    return {
      'totalBudget': totalBudget,
      'totalSpent': totalSpent,
      'percentageSpent': percentageSpent,
      'remaining': remaining,
    };
  }

  // Get expense categories for charts
  Map<String, double> get _expenseCategories {
    Map<String, double> categories = {};

    for (var expense in _expenses) {
      if (expense['status'] == 'Approved') {
        String category = expense['category'];
        double amount = expense['amount'];

        if (categories.containsKey(category)) {
          categories[category] = categories[category]! + amount;
        } else {
          categories[category] = amount;
        }
      }
    }

    return categories;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.budget['name'],
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.grey),
            tooltip: 'Print',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparing to print...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.grey),
            tooltip: 'Export',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting to PDF...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            tooltip: 'More options',
            onPressed: () {
              showMenu(
                context: context,
                position: const RelativeRect.fromLTRB(100, 80, 0, 0),
                items: [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Budget'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 18),
                        const SizedBox(width: 8),
                        const Text('Change Status'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive, size: 18),
                        SizedBox(width: 8),
                        Text('Archive'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingIndicator(message: 'Loading budget details...')
              : _buildBody(),
      floatingActionButton:
          _activeTab == "Expenses"
              ? FloatingActionButton(
                backgroundColor: Colors.blue[700],
                child: const Icon(Icons.add),
                onPressed: () {
                  _showAddExpenseDialog(context);
                },
              )
              : null,
    );
  }

  Widget _buildBody() {
    final metrics = _budgetMetrics;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return _buildMobileLayout(metrics);
        } else {
          return _buildDesktopLayout(metrics);
        }
      },
    );
  }

  Widget _buildMobileLayout(Map<String, dynamic> metrics) {
    return Column(
      children: [
        // Status bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: _getStatusColor(widget.budget['status']).withOpacity(0.1),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    widget.budget['status'],
                  ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getStatusColor(
                      widget.budget['status'],
                    ).withOpacity(0.5),
                  ),
                ),
                child: Text(
                  widget.budget['status'],
                  style: TextStyle(
                    color: _getStatusColor(widget.budget['status']),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Submitted: ${widget.budget['dateSubmitted']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),

        // Navigation tabs
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildTab("Details", Icons.info_outline),
              _buildTab("Expenses", Icons.receipt_long),
              _buildTab("Analytics", Icons.bar_chart),
            ],
          ),
        ),

        // Main content area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child:
                _activeTab == "Details"
                    ? _buildDetailsTab(metrics, true)
                    : _activeTab == "Expenses"
                    ? _buildExpensesTab(true)
                    : _buildAnalyticsTab(metrics, true),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(Map<String, dynamic> metrics) {
    return Row(
      children: [
        // Left sidebar with budget details
        SizedBox(
          width: 300,
          child: Card(
            elevation: 1,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        widget.budget['status'],
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.budget['status'],
                          style: TextStyle(
                            color: _getStatusColor(widget.budget['status']),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Budget Amount',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(widget.budget['budget']),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 24),
                  LinearPercentIndicator(
                    lineHeight: 16.0,
                    percent:
                        metrics['percentageSpent'] > 1
                            ? 1
                            : metrics['percentageSpent'],
                    center: Text(
                      "${(metrics['percentageSpent'] * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    barRadius: const Radius.circular(8),
                    backgroundColor: Colors.grey[200],
                    progressColor:
                        metrics['percentageSpent'] > 0.9
                            ? Colors.red
                            : metrics['percentageSpent'] > 0.7
                            ? Colors.orange
                            : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Spent: ${_formatCurrency(metrics['totalSpent'])}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        'Remaining: ${_formatCurrency(metrics['remaining'])}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              metrics['remaining'] < 0
                                  ? Colors.red
                                  : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.budget['description'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Important Dates',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  _buildDateRow('Submitted', widget.budget['dateSubmitted']),
                  if (widget.budget['status'] == 'Approved')
                    _buildDateRow('Approved', widget.budget['dateApproved']),
                  if (widget.budget['status'] == 'For Revision')
                    _buildDateRow(
                      'Revision Requested',
                      widget.budget['revisionRequested'],
                    ),
                  if (widget.budget['status'] == 'Denied')
                    _buildDateRow('Denied', widget.budget['dateDenied']),
                  if (widget.budget['status'] == 'Archived')
                    _buildDateRow('Archived', widget.budget['dateArchived']),
                  const Spacer(),
                  if (widget.budget['status'] == 'Pending')
                    _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),

        // Right side with tabs for details, expenses, analytics
        Expanded(
          child: Column(
            children: [
              // Tab navigation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildTab("Details", Icons.info_outline),
                    _buildTab("Expenses", Icons.receipt_long),
                    _buildTab("Analytics", Icons.bar_chart),
                    const Spacer(),
                    if (_activeTab == "Expenses")
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Expense'),
                        onPressed: () => _showAddExpenseDialog(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                        ),
                      ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child:
                    _activeTab == "Details"
                        ? _buildDetailsTab(metrics, false)
                        : _activeTab == "Expenses"
                        ? _buildExpensesTab(false)
                        : _buildAnalyticsTab(metrics, false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String title, IconData icon) {
    final isActive = _activeTab == title;

    return InkWell(
      onTap: () => setState(() => _activeTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.blue : Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.grey[700],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> metrics, bool isMobile) {
    if (isMobile) {
      // Mobile layout for details tab
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBudgetOverviewCard(metrics),
          const SizedBox(height: 16),
          _buildBudgetInfoCard(),
          const SizedBox(height: 16),
          _buildNotesCard(),
          const SizedBox(height: 16),
          _buildActivityCard(),
        ],
      );
    } else {
      // Desktop layout for details tab
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildBudgetInfoCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildNotesCard()),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildActivityCard()),
          ],
        ),
      );
    }
  }

  Widget _buildExpensesTab(bool isMobile) {
    if (isMobile) {
      // Mobile layout for expenses tab
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildExpensesList(true)],
      );
    } else {
      // Desktop layout for expenses tab
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildExpensesList(false),
      );
    }
  }

  Widget _buildAnalyticsTab(Map<String, dynamic> metrics, bool isMobile) {
    if (isMobile) {
      // Mobile layout for analytics tab
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSpendingTrendCard(),
          const SizedBox(height: 16),
          _buildCategoryBreakdownCard(),
          const SizedBox(height: 16),
          _buildBudgetStatusCard(metrics),
        ],
      );
    } else {
      // Desktop layout for analytics tab
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildSpendingTrendCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildCategoryBreakdownCard()),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBudgetStatusCard(metrics)),
          ],
        ),
      );
    }
  }

  // Budget overview card
  Widget _buildBudgetOverviewCard(Map<String, dynamic> metrics) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Budget',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      _formatCurrency(metrics['totalBudget']),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      _formatCurrency(metrics['remaining']),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            metrics['remaining'] < 0
                                ? Colors.red
                                : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearPercentIndicator(
              lineHeight: 16.0,
              percent:
                  metrics['percentageSpent'] > 1
                      ? 1
                      : metrics['percentageSpent'],
              center: Text(
                "${(metrics['percentageSpent'] * 100).toStringAsFixed(1)}%",
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              barRadius: const Radius.circular(8),
              backgroundColor: Colors.grey[200],
              progressColor:
                  metrics['percentageSpent'] > 0.9
                      ? Colors.red
                      : metrics['percentageSpent'] > 0.7
                      ? Colors.orange
                      : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              'Spent: ${_formatCurrency(metrics['totalSpent'])}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Budget info card
  Widget _buildBudgetInfoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', widget.budget['name']),
            const Divider(),
            _buildInfoRow('Description', widget.budget['description']),
            const Divider(),
            _buildInfoRow('Date Submitted', widget.budget['dateSubmitted']),
            const Divider(),
            _buildInfoRow(
              'Status',
              widget.budget['status'],
              _getStatusColor(widget.budget['status']),
            ),
            if (widget.budget['status'] == 'For Revision') ...[
              const Divider(),
              _buildInfoRow('Revision Notes', widget.budget['revisionNotes']),
            ],
            if (widget.budget['status'] == 'Denied') ...[
              const Divider(),
              _buildInfoRow('Denial Reason', widget.budget['denialReason']),
            ],
          ],
        ),
      ),
    );
  }

  // Notes card
  Widget _buildNotesCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notes & Documents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () {
                    // Add note functionality
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildNoteItem(
              'Budget proposal document attached',
              'Jane Smith',
              DateTime.now().subtract(const Duration(days: 2)),
              Icons.description,
              Colors.blue,
              true,
            ),
            _buildNoteItem(
              'Please review the updated cost estimates',
              'Robert Brown',
              DateTime.now().subtract(const Duration(days: 4)),
              Icons.comment,
              Colors.purple,
              false,
            ),
            _buildNoteItem(
              'Initial planning document',
              'Mike Johnson',
              DateTime.now().subtract(const Duration(days: 7)),
              Icons.description,
              Colors.blue,
              true,
            ),
          ],
        ),
      ),
    );
  }

  // Activity card
  Widget _buildActivityCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildActivityItem(
                    'Budget submitted for approval',
                    'John Doe',
                    DateTime.now().subtract(const Duration(days: 1)),
                    Icons.send,
                    Colors.blue,
                  ),
                  _buildActivityItem(
                    'Initial budget created',
                    'John Doe',
                    DateTime.now().subtract(const Duration(days: 2)),
                    Icons.create,
                    Colors.green,
                  ),
                  if (widget.budget['status'] == 'Approved')
                    _buildActivityItem(
                      'Budget approved',
                      'Jane Smith',
                      DateTime.now().subtract(const Duration(hours: 5)),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  if (widget.budget['status'] == 'For Revision')
                    _buildActivityItem(
                      'Revision requested',
                      'Jane Smith',
                      DateTime.now().subtract(const Duration(hours: 12)),
                      Icons.edit,
                      Colors.orange,
                    ),
                  if (widget.budget['status'] == 'Denied')
                    _buildActivityItem(
                      'Budget denied',
                      'Jane Smith',
                      DateTime.now().subtract(const Duration(hours: 8)),
                      Icons.cancel,
                      Colors.red,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Expenses list
  Widget _buildExpensesList(bool isMobile) {
    if (_expenses.isEmpty) {
      return EmptyStateWidget(
        message: 'No expenses yet',
        icon: Icons.receipt_long,
        actionLabel: 'Add Expense',
        onActionPressed: () => _showAddExpenseDialog(context),
      );
    }

    if (isMobile) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
                expense['description'],
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
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(expense['date']),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color:
                              expense['status'] == 'Approved'
                                  ? Colors.green[50]
                                  : Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          expense['status'],
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                expense['status'] == 'Approved'
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (expense['receipt'])
                        Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showExpenseDetails(context, expense),
              ),
            ),
          );
        },
      );
    } else {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expenses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download, size: 18),
                        label: const Text('Export'),
                        onPressed: () {
                          // Export functionality
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[300]!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.filter_list, size: 18),
                        label: const Text('Filter'),
                        onPressed: () {
                          // Filter functionality
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[300]!),
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
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Description')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows:
                        _expenses.map((expense) {
                          return DataRow(
                            cells: [
                              DataCell(Text(expense['id'])),
                              DataCell(Text(expense['description'])),
                              DataCell(
                                Row(
                                  children: [
                                    Icon(
                                      _getCategoryIcon(expense['category']),
                                      size: 16,
                                      color: _getCategoryColor(
                                        expense['category'],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(expense['category']),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatCurrency(expense['amount']),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy',
                                  ).format(expense['date']),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        expense['status'] == 'Approved'
                                            ? Colors.green[50]
                                            : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    expense['status'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          expense['status'] == 'Approved'
                                              ? Colors.green[700]
                                              : Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    if (expense['receipt'])
                                      IconButton(
                                        icon: const Icon(
                                          Icons.receipt,
                                          size: 18,
                                        ),
                                        tooltip: 'View Receipt',
                                        onPressed: () {
                                          // View receipt functionality
                                        },
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.info_outline,
                                        size: 18,
                                      ),
                                      tooltip: 'View Details',
                                      onPressed:
                                          () => _showExpenseDetails(
                                            context,
                                            expense,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Spending trend card
  Widget _buildSpendingTrendCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Spending trend graph will be displayed here',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
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

  // Category breakdown card
  Widget _buildCategoryBreakdownCard() {
    final categories = _expenseCategories;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  categories.isEmpty
                      ? Center(
                        child: Text(
                          'No expense data available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                      : ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories.keys.elementAt(index);
                          final amount = categories[category]!;
                          final percentage =
                              amount / _budgetMetrics['totalSpent'] * 100;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getCategoryIcon(category),
                                      size: 16,
                                      color: _getCategoryColor(category),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatCurrency(amount),
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${percentage.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearPercentIndicator(
                                  lineHeight: 8.0,
                                  percent: percentage / 100,
                                  backgroundColor: Colors.grey[200],
                                  progressColor: _getCategoryColor(category),
                                  barRadius: const Radius.circular(4),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // Budget status card
  Widget _buildBudgetStatusCard(Map<String, dynamic> metrics) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Total Budget',
                    _formatCurrency(metrics['totalBudget']),
                    Colors.blue,
                    Icons.account_balance_wallet,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Total Spent',
                    _formatCurrency(metrics['totalSpent']),
                    Colors.orange,
                    Icons.payments,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Remaining',
                    _formatCurrency(metrics['remaining']),
                    metrics['remaining'] < 0 ? Colors.red : Colors.green,
                    metrics['remaining'] < 0
                        ? Icons.warning
                        : Icons.check_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Spending Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            LinearPercentIndicator(
              lineHeight: 24.0,
              percent:
                  metrics['percentageSpent'] > 1
                      ? 1
                      : metrics['percentageSpent'],
              center: Text(
                "${(metrics['percentageSpent'] * 100).toStringAsFixed(1)}%",
                style: const TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              barRadius: const Radius.circular(12),
              backgroundColor: Colors.grey[200],
              progressColor:
                  metrics['percentageSpent'] > 0.9
                      ? Colors.red
                      : metrics['percentageSpent'] > 0.7
                      ? Colors.orange
                      : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              metrics['percentageSpent'] > 0.9
                  ? 'Budget almost depleted'
                  : metrics['percentageSpent'] > 0.7
                  ? 'Budget usage on track'
                  : 'Budget usage healthy',
              style: TextStyle(
                color:
                    metrics['percentageSpent'] > 0.9
                        ? Colors.red
                        : metrics['percentageSpent'] > 0.7
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for building UI components
  Widget _buildDateRow(String label, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(date, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: valueColor ?? Colors.grey[800],
              fontWeight:
                  valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(
    String text,
    String author,
    DateTime date,
    IconData icon,
    Color color,
    bool isDocument,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      author,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, y').format(date),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (isDocument) ...[
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text(
                          'Download',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          // Download functionality
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String text,
    String user,
    DateTime date,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      user,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, y').format(date),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              // Deny budget
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: const Text('Deny'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              // Request revisions
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: BorderSide(color: Colors.orange),
            ),
            child: const Text('Request Revisions'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Approve budget
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ),
      ],
    );
  }

  // Get category color
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Supplies':
        return Colors.blue;
      case 'Meals':
        return Colors.orange;
      case 'Software':
        return Colors.purple;
      case 'Travel':
        return Colors.green;
      case 'Events':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  // Get category icon
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Supplies':
        return Icons.shopping_bag;
      case 'Meals':
        return Icons.restaurant;
      case 'Software':
        return Icons.computer;
      case 'Travel':
        return Icons.flight;
      case 'Events':
        return Icons.event;
      default:
        return Icons.category;
    }
  }

  // Add expense dialog
  void _showAddExpenseDialog(BuildContext context) {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Supplies';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Add New Expense',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter expense description',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter expense amount',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Category'),
                    value: selectedCategory,
                    items:
                        [
                              'Supplies',
                              'Meals',
                              'Software',
                              'Travel',
                              'Events',
                              'Other',
                            ]
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedCategory = value;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.receipt, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          // Upload receipt functionality
                        },
                        child: const Text('Upload Receipt'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                ),
                onPressed: () {
                  // Add expense logic
                  if (descriptionController.text.isNotEmpty &&
                      amountController.text.isNotEmpty) {
                    setState(() {
                      _expenses.add({
                        'id': 'EXP-${_expenses.length + 6}',
                        'description': descriptionController.text,
                        'amount': double.tryParse(amountController.text) ?? 0.0,
                        'date': DateTime.now(),
                        'category': selectedCategory,
                        'approvedBy': 'Pending',
                        'receipt': false,
                        'status': 'Pending',
                        'paymentMethod': 'Corporate Card',
                      });
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Expense added successfully'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all required fields'),
                      ),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
    );
  }

  // Helper function to build detail rows
  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: valueColor ?? Colors.grey[800],
            fontWeight:
                valueColor != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // Show expense details
  void _showExpenseDetails(BuildContext context, Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Expense Details',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: _getCategoryColor(
                        expense['category'],
                      ).withOpacity(0.2),
                      child: Icon(
                        _getCategoryIcon(expense['category']),
                        size: 30,
                        color: _getCategoryColor(expense['category']),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('ID', expense['id']),
                  const SizedBox(height: 16),
                  _buildDetailRow('Description', expense['description']),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Amount',
                    _formatCurrency(expense['amount']),
                    Colors.blue[700],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Category', expense['category']),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Date',
                    DateFormat('MMMM d, yyyy').format(expense['date']),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Status',
                    expense['status'],
                    expense['status'] == 'Approved'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Payment Method', expense['paymentMethod']),
                  const SizedBox(height: 16),
                  _buildDetailRow('Approved By', expense['approvedBy']),
                  const SizedBox(height: 24),
                  if (expense['receipt'])
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt),
                      label: const Text('View Receipt'),
                      onPressed: () {
                        // View receipt functionality
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening receipt...')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: Colors.grey[700])),
              ),
              if (expense['status'] == 'Pending')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    // Approve expense
                    setState(() {
                      expense['status'] = 'Approved';
                      expense['approvedBy'] = 'Jane Smith';
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense approved')),
                    );
                  },
                  child: const Text('Approve'),
                ),
            ],
          ),
    );
  }
}
