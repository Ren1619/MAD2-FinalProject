import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/common_widgets.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  _BudgetsPageState createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = "All";
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _budgets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchBudgets();

    // Listen for tab changes to refresh the list
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBudgets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _budgets = await _databaseService.fetchBudgets();
    } catch (e) {
      print('Error fetching budgets: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter budgets based on the selected tab and search query
  List<Map<String, dynamic>> _getFilteredBudgets() {
    if (_isLoading) return [];

    List<Map<String, dynamic>> filteredList = [];

    String statusFilter = '';
    switch (_tabController.index) {
      case 0:
        statusFilter = 'Pending';
        break;
      case 1:
        statusFilter = 'Approved';
        break;
      case 2:
        statusFilter = 'For Revision';
        break;
      case 3:
        statusFilter = 'Denied';
        break;
      case 4:
        statusFilter = 'Archived';
        break;
    }

    String searchQuery = _searchController.text.toLowerCase();

    // Filter by status and search query
    for (var budget in _budgets) {
      final String status = budget['status'] ?? '';
      final String name = budget['name'] ?? '';
      final String description = budget['description'] ?? '';

      if (status == statusFilter) {
        if (searchQuery.isEmpty ||
            name.toLowerCase().contains(searchQuery) ||
            description.toLowerCase().contains(searchQuery)) {
          filteredList.add(budget);
        }
      }
    }

    // Additional filtering based on _filterStatus
    if (_filterStatus == "High") {
      filteredList.sort(
        (a, b) => (b['budget'] as num).compareTo(a['budget'] as num),
      );
    } else if (_filterStatus == "Low") {
      filteredList.sort(
        (a, b) => (a['budget'] as num).compareTo(b['budget'] as num),
      );
    } else if (_filterStatus == "Recent") {
      // Sort by dateSubmitted (most recent first)
      filteredList.sort((a, b) {
        final aDate = DateTime.parse(a['dateSubmitted'] ?? '2025-01-01');
        final bDate = DateTime.parse(b['dateSubmitted'] ?? '2025-01-01');
        return bDate.compareTo(aDate);
      });
    }

    return filteredList;
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

  // Return appropriate color for status
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and filter section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - stacked
                  return Column(
                    children: [
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
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_buildFilterDropdown()],
                      ),
                    ],
                  );
                } else {
                  // Desktop/tablet layout
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
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
                      ),
                      const SizedBox(width: 16),
                      _buildFilterDropdown(),
                    ],
                  );
                }
              },
            ),
          ),

          // Tab Bar - Made scrollable to prevent overflow on small screens
          TabBar(
            controller: _tabController,
            isScrollable: true, // Important for small screens
            onTap: (_) => setState(() {}),
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'For Revision'),
              Tab(text: 'Denied'),
              Tab(text: 'Archived'),
            ],
          ),

          // Main content area with budget cards
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Each tab has the same widget but with different filtered data
                _buildBudgetList(),
                _buildBudgetList(),
                _buildBudgetList(),
                _buildBudgetList(),
                _buildBudgetList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddBudgetDialog(context);
        },
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: _filterStatus,
        icon: Icon(Icons.filter_list, color: Colors.blue[700]),
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'All', child: Text('All Budgets')),
          DropdownMenuItem(value: 'High', child: Text('High Value')),
          DropdownMenuItem(value: 'Low', child: Text('Low Value')),
          DropdownMenuItem(value: 'Recent', child: Text('Recently Added')),
        ],
        onChanged: (value) {
          setState(() {
            _filterStatus = value!;
          });
        },
      ),
    );
  }

  Widget _buildBudgetList() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading budgets...');
    }

    final filteredBudgets = _getFilteredBudgets();

    if (filteredBudgets.isEmpty) {
      return EmptyStateWidget(
        message: 'No budgets found',
        icon: Icons.account_balance_wallet,
        actionLabel: 'Create Budget',
        onActionPressed: () => _showAddBudgetDialog(context),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Choose layout based on screen width
        if (constraints.maxWidth < 600) {
          return _buildMobileList(filteredBudgets);
        } else if (constraints.maxWidth < 1000) {
          return _buildTabletList(filteredBudgets);
        } else {
          return _buildDesktopList(filteredBudgets);
        }
      },
    );
  }

  // Mobile layout - stacked cards
  Widget _buildMobileList(List<Map<String, dynamic>> budgets) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: budgets.length,
      itemBuilder: (context, index) {
        final budget = budgets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
                        maxLines: 1, // Prevent overflow
                      ),
                    ),
                    const SizedBox(width: 8), // Ensure spacing
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Submitted: ${_formatDate(budget['dateSubmitted'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildActionButton(budget),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to format date string
  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';

    if (date is String) {
      try {
        final DateTime dateTime = DateTime.parse(date);
        return dateTime.toString().substring(0, 10);
      } catch (e) {
        return date;
      }
    } else {
      return 'Invalid date';
    }
  }

  // Tablet layout - grid cards with improved overflow protection
  Widget _buildTabletList(List<Map<String, dynamic>> budgets) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: budgets.length,
      itemBuilder: (context, index) {
        final budget = budgets[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                Expanded(
                  child: Text(
                    budget['description'] ?? 'No description provided',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Submitted: ${_formatDate(budget['dateSubmitted'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildActionButton(budget),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Desktop layout - table with horizontal scrolling for smaller screens
  Widget _buildDesktopList(List<Map<String, dynamic>> budgets) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      // Added horizontal scrolling to prevent overflow on smaller screens
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ConstrainedBox(
            // Set a minimum width to ensure the table is usable
            constraints: BoxConstraints(
              minWidth: 600,
              maxWidth:
                  MediaQuery.of(context).size.width > 800
                      ? MediaQuery.of(context).size.width - 64
                      : 800,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Budget',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows:
                    budgets.map((budget) {
                      return DataRow(
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                budget['name'] ?? 'Unnamed Budget',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatCurrency(budget['budget']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              child: Text(
                                budget['description'] ??
                                    'No description provided',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                          DataCell(
                            _buildStatusChip(budget['status'] ?? 'Pending'),
                          ),
                          DataCell(Text(_formatDate(budget['dateSubmitted']))),
                          DataCell(_buildActionButton(budget)),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActionButton(Map<String, dynamic> budget) {
    IconData icon;
    String tooltip;
    String status = budget['status'] ?? 'Pending';
    String id = budget['id'] ?? '';

    // Different actions based on status
    switch (status) {
      case 'Pending':
        icon = Icons.check_circle_outline;
        tooltip = 'Review';
        break;
      case 'Approved':
        icon = Icons.description;
        tooltip = 'View Details';
        break;
      case 'For Revision':
        icon = Icons.edit;
        tooltip = 'Edit';
        break;
      case 'Denied':
        icon = Icons.refresh;
        tooltip = 'Resubmit';
        break;
      case 'Archived':
        icon = Icons.restore;
        tooltip = 'Restore';
        break;
      default:
        icon = Icons.more_horiz;
        tooltip = 'More';
    }

    return IconButton(
      icon: Icon(icon, color: Colors.blue[700]),
      tooltip: tooltip,
      onPressed: () {
        _showBudgetDetailsDialog(context, budget);
      },
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isLoading = false;

    // Use a responsive width based on screen size
    final double dialogWidth =
        MediaQuery.of(context).size.width > 600
            ? 500
            : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  // Constrained size to prevent overflow
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dialogWidth,
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create New Budget',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Budget Name',
                                hintText: 'Enter budget name',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: budgetController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                hintText: 'Enter budget amount',
                                prefixText: '\$ ',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: descriptionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Enter budget description',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                  ),
                                  onPressed:
                                      isLoading
                                          ? null
                                          : () async {
                                            // Validate input fields
                                            if (nameController.text.isEmpty ||
                                                budgetController.text.isEmpty ||
                                                descriptionController
                                                    .text
                                                    .isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please fill all fields',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            // Parse budget amount
                                            double? budgetAmount =
                                                double.tryParse(
                                                  budgetController.text,
                                                );
                                            if (budgetAmount == null) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please enter a valid amount',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            setState(() {
                                              isLoading = true;
                                            });

                                            try {
                                              // Create budget in SQLite
                                              await _databaseService
                                                  .createBudget({
                                                    'name': nameController.text,
                                                    'budget': budgetAmount,
                                                    'description':
                                                        descriptionController
                                                            .text,
                                                  });

                                              Navigator.pop(context);

                                              // Refresh budget list
                                              _fetchBudgets();

                                              // Show success message
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Budget submitted successfully',
                                                  ),
                                                ),
                                              );
                                            } catch (e) {
                                              // Show error message
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Error: ${e.toString()}',
                                                  ),
                                                ),
                                              );
                                            } finally {
                                              setState(() {
                                                isLoading = false;
                                              });
                                            }
                                          },
                                  child:
                                      isLoading
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.0,
                                            ),
                                          )
                                          : const Text('Submit'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  void _showBudgetDetailsDialog(
    BuildContext context,
    Map<String, dynamic> budget,
  ) {
    final String id = budget['id'] ?? '';
    final String status = budget['status'] ?? 'Pending';
    final String name = budget['name'] ?? 'Unnamed Budget';
    bool isLoading = false;

    // Use a responsive width based on screen size
    final double dialogWidth =
        MediaQuery.of(context).size.width > 600
            ? 500
            : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  // Constrained size to prevent overflow
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dialogWidth,
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  'Status: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                _buildStatusChip(status),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Budget Amount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              _formatCurrency(budget['budget']),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Description',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              budget['description'] ??
                                  'No description provided',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Date Submitted',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              _formatDate(budget['dateSubmitted']),
                              style: TextStyle(color: Colors.grey[600]),
                            ),

                            // Show different information based on status
                            if (status == 'Approved') ...[
                              const SizedBox(height: 16),
                              Text(
                                'Date Approved',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                _formatDate(budget['dateApproved']),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],

                            if (status == 'For Revision') ...[
                              const SizedBox(height: 16),
                              Text(
                                'Revision Requested',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                _formatDate(budget['revisionRequested']),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber[100]!),
                                ),
                                child: Text(
                                  budget['revisionNotes'] ??
                                      'No notes provided',
                                  style: TextStyle(color: Colors.amber[800]),
                                ),
                              ),
                            ],

                            if (status == 'Denied') ...[
                              const SizedBox(height: 16),
                              Text(
                                'Date Denied',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                _formatDate(budget['dateDenied']),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Reason',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red[100]!),
                                ),
                                child: Text(
                                  budget['denialReason'] ??
                                      'No reason provided',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Close',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                                if (status == 'Pending')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                    ),
                                    onPressed:
                                        isLoading
                                            ? null
                                            : () async {
                                              setState(() {
                                                isLoading = true;
                                              });

                                              try {
                                                // Update budget status to Approved
                                                await _databaseService
                                                    .updateBudgetStatus(
                                                      id,
                                                      'Approved',
                                                    );

                                                Navigator.pop(context);

                                                // Refresh budget list
                                                _fetchBudgets();

                                                // Show success message
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Budget approved',
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Error: ${e.toString()}',
                                                    ),
                                                  ),
                                                );
                                              } finally {
                                                setState(() {
                                                  isLoading = false;
                                                });
                                              }
                                            },
                                    child:
                                        isLoading
                                            ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.0,
                                              ),
                                            )
                                            : const Text('Approve'),
                                  ),
                                if (status == 'For Revision')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      // Handle revision submission
                                      // This would typically open another dialog for editing
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Revision feature coming soon',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Submit Revisions'),
                                  ),
                                if (status == 'Denied')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange[700],
                                    ),
                                    onPressed:
                                        isLoading
                                            ? null
                                            : () async {
                                              setState(() {
                                                isLoading = true;
                                              });

                                              try {
                                                // Update budget status to Pending (resubmitted)
                                                await _databaseService
                                                    .updateBudgetStatus(
                                                      id,
                                                      'Pending',
                                                    );

                                                Navigator.pop(context);

                                                // Refresh budget list
                                                _fetchBudgets();

                                                // Show success message
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Budget resubmitted',
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Error: ${e.toString()}',
                                                    ),
                                                  ),
                                                );
                                              } finally {
                                                setState(() {
                                                  isLoading = false;
                                                });
                                              }
                                            },
                                    child:
                                        isLoading
                                            ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.0,
                                              ),
                                            )
                                            : const Text('Resubmit'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ),
    );
  }
}
