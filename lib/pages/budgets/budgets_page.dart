import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import 'budget_details_page.dart';
import 'create_budget_page.dart';

class BudgetsPage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final Map<String, dynamic>? userData;
  const BudgetsPage({super.key, this.onOpenDrawer, this.userData});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // Budget lists by status
  Map<String, List<Map<String, dynamic>>> _budgetsByStatus = {
    'Pending for Approval': [],
    'Active': [],
    'Completed': [],
    'For Revision': [],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<FirebaseAuthService>(
      context,
      listen: false,
    );
    final userData = await authService.currentUser;

    setState(() {
      _userData = userData;
    });

    await _loadBudgets();
    setState(() => _isLoading = false);
  }

  bool _isRefreshing = false;

  Future<void> _loadBudgets() async {
    if (_userData == null) return;

    setState(() => _isLoading = true);

    try {
      // Direct Firestore access for testing
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final companyId = _userData!['company_id'];

      print('Loading budgets for company: $companyId');

      // Get all budgets for the company
      final snapshot =
          await firestore
              .collection('budgets')
              .where('company_id', isEqualTo: companyId)
              .get();

      print('Found ${snapshot.docs.length} total budgets');

      // Organize by status
      final Map<String, List<Map<String, dynamic>>> budgetsByStatus = {
        'Pending for Approval': [],
        'Active': [],
        'Completed': [],
        'For Revision': [],
      };

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'Unknown';

        print('Budget: ${data['budget_name']} - Status: $status');

        if (budgetsByStatus.containsKey(status)) {
          budgetsByStatus[status]!.add(data);
        }
      }

      setState(() {
        _budgetsByStatus = budgetsByStatus;
        _isLoading = false;
      });

      print('Budget counts by status:');
      budgetsByStatus.forEach((status, budgets) {
        print('  $status: ${budgets.length}');
      });
    } catch (e) {
      print('Error loading budgets: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading budgets: $e');
    }
  }

  Future<void> _refreshBudgets() async {
    setState(() => _isRefreshing = true);
    await _loadBudgets();

    // Show feedback to user
    if (mounted) {
      _showSuccessSnackBar('Budget list updated');
    }
  }

  void _showCreateBudgetPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateBudgetPage()),
    ).then((result) {
      // Check if a budget was successfully created
      if (result == true) {
        // Set refreshing state before loading
        setState(() => _isRefreshing = true);

        // Add a delay to ensure Firestore has propagated the changes
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _loadBudgets().then((_) {
              if (mounted) {
                // Switch to the "Pending for Approval" tab to show the new budget
                _tabController.animateTo(0);
                _showSuccessSnackBar('Budget created and list refreshed');
              }
            });
          }
        });
      }
    });
  }

  void _viewBudgetDetails(Map<String, dynamic> budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BudgetDetailsPage(budget: budget),
      ),
    ).then((_) => _loadBudgets());
  }

  Future<void> _approveBudget(Map<String, dynamic> budget) async {
    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      final success = await budgetService.updateBudgetStatus(
        budget['budget_id'],
        'Active',
      );

      if (success) {
        _showSuccessSnackBar('Budget approved successfully');
        _loadBudgets();
      } else {
        _showErrorSnackBar('Failed to approve budget');
      }
    } catch (e) {
      _showErrorSnackBar('Error approving budget: $e');
    }
  }

  Future<void> _markForRevision(Map<String, dynamic> budget) async {
    showDialog(
      context: context,
      builder:
          (context) => _RevisionNotesDialog(
            budget: budget,
            onRevisionMarked: () {
              Navigator.pop(context);
              _loadBudgets();
            },
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

  bool _canCreateBudgets() {
    return _userData?['role'] == 'Financial Planning and Budgeting Officer';
  }

  bool _canApproveBudgets() {
    return _userData?['role'] == 'Budget Manager' ||
        _userData?['role'] == 'Administrator';
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

      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading budgets...'),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Budget Management',
        onMenuPressed: widget.onOpenDrawer,
        userData: widget.userData,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadBudgets();
              _showSuccessSnackBar('Budget list refreshed');
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // User Role Info and Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Role: ${_userData?['role'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    if (_canCreateBudgets())
                      ElevatedButton.icon(
                        onPressed: _showCreateBudgetPage,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Budget'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Budget Stats with pull-to-refresh hint
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Pending Approval',
                            _budgetsByStatus['Pending for Approval']!.length
                                .toString(),
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Active',
                            _budgetsByStatus['Active']!.length.toString(),
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Completed',
                            _budgetsByStatus['Completed']!.length.toString(),
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'For Revision',
                            _budgetsByStatus['For Revision']!.length.toString(),
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pull down any list to refresh',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Pending Approval'),
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
                Tab(text: 'For Revision'),
              ],
            ),
          ),

          // Tab Content with RefreshIndicator
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBudgetList('Pending for Approval'),
                _buildBudgetList('Active'),
                _buildBudgetList('Completed'),
                _buildBudgetList('For Revision'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetList(String status) {
    final budgets = _budgetsByStatus[status]!;

    if (budgets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBudgets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            child: EmptyStateWidget(
              message:
                  status == 'Pending for Approval'
                      ? 'No budgets pending approval.\n${_canCreateBudgets() ? 'Create a new budget to get started.' : 'Budgets will appear here when created by Financial Officers.'}'
                      : 'No $status budgets found.',
              icon: Icons.account_balance_wallet_outlined,
              onActionPressed:
                  (status == 'Pending for Approval' && _canCreateBudgets())
                      ? _showCreateBudgetPage
                      : null,
              actionLabel: 'Create Budget',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBudgets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          return _buildBudgetCard(budgets[index], status);
        },
      ),
    );
  }

  Widget _buildBudgetCard(Map<String, dynamic> budget, String status) {
    final budgetAmount = (budget['budget_amount'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (budget['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final remainingAmount = budgetAmount - totalExpenses;
    final expenseCount = budget['expense_count'] as int? ?? 0;
    final percentageUsed =
        budgetAmount > 0 ? (totalExpenses / budgetAmount) : 0.0;

    Color progressColor = Colors.green;
    if (percentageUsed > 0.8) {
      progressColor = Colors.red;
    } else if (percentageUsed > 0.6) {
      progressColor = Colors.orange;
    }

    return HoverCard(
      onTap: () => _viewBudgetDetails(budget),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget['budget_name'] ?? 'Unnamed Budget',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        budget['budget_description'] ?? 'No description',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),

            const SizedBox(height: 16),

            // Budget Info
            Row(
              children: [
                Expanded(
                  child: _buildInfoColumn(
                    'Budget Amount',
                    _formatCurrency(budgetAmount),
                    Icons.account_balance_wallet,
                  ),
                ),
                Expanded(
                  child: _buildInfoColumn(
                    'Total Expenses',
                    _formatCurrency(totalExpenses),
                    Icons.receipt,
                  ),
                ),
                Expanded(
                  child: _buildInfoColumn(
                    'Remaining',
                    _formatCurrency(remainingAmount),
                    Icons.savings,
                  ),
                ),
                Expanded(
                  child: _buildInfoColumn(
                    'Expenses Count',
                    expenseCount.toString(),
                    Icons.list_alt,
                  ),
                ),
              ],
            ),

            if (status == 'Active' || status == 'Completed') ...[
              const SizedBox(height: 16),

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
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${(percentageUsed * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
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
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 8,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Creator and Date Info
            Row(
              children: [
                Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Created by: ${budget['created_by_name'] ?? 'Unknown'}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(budget['created_at']),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),

            // Action Buttons for Budget Managers
            if (status == 'Pending for Approval' && _canApproveBudgets()) ...[
              const SizedBox(height: 16),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveBudget(budget),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markForRevision(budget),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Mark for Revision'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // View Details Button
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _viewBudgetDetails(budget),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Revision Notes Dialog
class _RevisionNotesDialog extends StatefulWidget {
  final Map<String, dynamic> budget;
  final VoidCallback onRevisionMarked;

  const _RevisionNotesDialog({
    required this.budget,
    required this.onRevisionMarked,
  });

  @override
  State<_RevisionNotesDialog> createState() => _RevisionNotesDialogState();
}

class _RevisionNotesDialogState extends State<_RevisionNotesDialog> {
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _markForRevision() async {
    setState(() => _isLoading = true);

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      final success = await budgetService.updateBudgetStatus(
        widget.budget['budget_id'],
        'For Revision',
        notes:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
      );

      if (success) {
        widget.onRevisionMarked();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Budget marked for revision'),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to mark budget for revision'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Mark Budget for Revision',
        style: TextStyle(color: Colors.orange[700]),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget: ${widget.budget['budget_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Revision Notes (Optional)',
                hintText:
                    'Enter reasons for revision or suggestions for improvement...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This budget will be moved to "For Revision" status and the creator will be notified.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _markForRevision,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Text(
                    'Mark for Revision',
                    style: TextStyle(color: Colors.white),
                  ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
