import 'package:flutter/material.dart';
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

  // Sample data for budgets with different statuses
  final List<Map<String, dynamic>> _budgets = [
    {
      'name': 'Q1 Marketing Campaign',
      'budget': 25000.00,
      'description':
          'Budget for Q1 digital marketing initiatives across all platforms',
      'status': 'Pending',
      'dateSubmitted': '2025-04-28',
    },
    {
      'name': 'IT Infrastructure Upgrade',
      'budget': 75000.00,
      'description': 'Server upgrades and new developer workstations',
      'status': 'Approved',
      'dateSubmitted': '2025-04-15',
      'dateApproved': '2025-04-22',
    },
    {
      'name': 'Office Supplies',
      'budget': 2500.00,
      'description':
          'Monthly office supplies including paper, pens, and other consumables',
      'status': 'Approved',
      'dateSubmitted': '2025-04-10',
      'dateApproved': '2025-04-12',
    },
    {
      'name': 'Customer Appreciation Event',
      'budget': 15000.00,
      'description': 'Annual customer appreciation dinner and networking event',
      'status': 'For Revision',
      'dateSubmitted': '2025-04-18',
      'revisionRequested': '2025-04-25',
      'revisionNotes':
          'Please provide more detailed breakdown of catering costs',
    },
    {
      'name': 'Executive Retreat',
      'budget': 35000.00,
      'description': 'Annual planning retreat for executive leadership team',
      'status': 'Denied',
      'dateSubmitted': '2025-04-05',
      'dateDenied': '2025-04-08',
      'denialReason':
          'Budget constraints for current quarter - resubmit for Q3',
    },
    {
      'name': 'Employee Training Program',
      'budget': 10000.00,
      'description':
          'Professional development courses and certification for staff',
      'status': 'Pending',
      'dateSubmitted': '2025-04-30',
    },
    {
      'name': 'Q4 2024 Holiday Party',
      'budget': 8500.00,
      'description':
          'End of year celebration for all employees and their families',
      'status': 'Archived',
      'dateSubmitted': '2024-11-01',
      'dateApproved': '2024-11-05',
      'dateArchived': '2025-01-15',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Filter budgets based on the selected tab
  List<Map<String, dynamic>> _getFilteredBudgets() {
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
      if (budget['status'] == statusFilter) {
        if (searchQuery.isEmpty ||
            budget['name'].toLowerCase().contains(searchQuery) ||
            budget['description'].toLowerCase().contains(searchQuery)) {
          filteredList.add(budget);
        }
      }
    }

    return filteredList;
  }

  // Format currency
  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
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

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
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
                        budget['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusChip(budget['status']),
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
                  budget['description'],
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Submitted: ${budget['dateSubmitted']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  // Tablet layout - grid cards
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
                        budget['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusChip(budget['status']),
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
                    budget['description'],
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Submitted: ${budget['dateSubmitted']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  // Desktop layout - table
  Widget _buildDesktopList(List<Map<String, dynamic>> budgets) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        SizedBox(
                          width: 150,
                          child: Text(
                            budget['name'],
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
                        SizedBox(
                          width: 250,
                          child: Text(
                            budget['description'],
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(_buildStatusChip(budget['status'])),
                      DataCell(Text(budget['dateSubmitted'])),
                      DataCell(_buildActionButton(budget)),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

    // Different actions based on status
    switch (budget['status']) {
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

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Create New Budget',
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
                  // Add new budget logic would go here
                  // Currently just adds to the local list for demo
                  if (nameController.text.isNotEmpty &&
                      budgetController.text.isNotEmpty &&
                      descriptionController.text.isNotEmpty) {
                    setState(() {
                      _budgets.add({
                        'name': nameController.text,
                        'budget': double.tryParse(budgetController.text) ?? 0.0,
                        'description': descriptionController.text,
                        'status': 'Pending',
                        'dateSubmitted':
                            '2025-05-06', // Current date in your app
                      });
                    });

                    Navigator.pop(context);

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Budget submitted successfully'),
                      ),
                    );
                  } else {
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
    );
  }

  void _showBudgetDetailsDialog(
    BuildContext context,
    Map<String, dynamic> budget,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              budget['name'],
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
                  Row(
                    children: [
                      Text(
                        'Status: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      _buildStatusChip(budget['status']),
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
                    budget['description'],
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
                    budget['dateSubmitted'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),

                  // Show different information based on status
                  if (budget['status'] == 'Approved') ...[
                    const SizedBox(height: 16),
                    Text(
                      'Date Approved',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      budget['dateApproved'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],

                  if (budget['status'] == 'For Revision') ...[
                    const SizedBox(height: 16),
                    Text(
                      'Revision Requested',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      budget['revisionRequested'],
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
                        budget['revisionNotes'],
                        style: TextStyle(color: Colors.amber[800]),
                      ),
                    ),
                  ],

                  if (budget['status'] == 'Denied') ...[
                    const SizedBox(height: 16),
                    Text(
                      'Date Denied',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      budget['dateDenied'],
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
                        budget['denialReason'],
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: Colors.grey[700])),
              ),
              if (budget['status'] == 'Pending')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle approval logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Budget approved')),
                    );
                  },
                  child: const Text('Approve'),
                ),
              if (budget['status'] == 'For Revision')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle revision submission
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Revisions submitted')),
                    );
                  },
                  child: const Text('Submit Revisions'),
                ),
              if (budget['status'] == 'Denied')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle resubmission
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Budget resubmitted')),
                    );
                  },
                  child: const Text('Resubmit'),
                ),
            ],
          ),
    );
  }
}
