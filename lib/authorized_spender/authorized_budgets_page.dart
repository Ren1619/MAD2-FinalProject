import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/common_widgets.dart';
import '../theme.dart';

class AuthorizedBudgetsPage extends StatefulWidget {
  const AuthorizedBudgetsPage({super.key});

  @override
  _AuthorizedBudgetsPageState createState() => _AuthorizedBudgetsPageState();
}

class _AuthorizedBudgetsPageState extends State<AuthorizedBudgetsPage> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _budgets = [];

  @override
  void initState() {
    super.initState();
    _fetchAuthorizedBudgets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAuthorizedBudgets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // This will need a new method in DatabaseService
      _budgets = await _databaseService.fetchAuthorizedBudgets();
    } catch (e) {
      print('Error fetching authorized budgets: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter budgets based on search query
  List<Map<String, dynamic>> _getFilteredBudgets() {
    if (_isLoading) return [];

    String searchQuery = _searchController.text.toLowerCase();
    
    if (searchQuery.isEmpty) {
      return _budgets;
    }

    return _budgets.where((budget) {
      final String name = budget['name'] ?? '';
      final String description = budget['description'] ?? '';
      return name.toLowerCase().contains(searchQuery) ||
          description.toLowerCase().contains(searchQuery);
    }).toList();
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
        title: Text('My Authorized Budgets',
            style: TextStyle(color: AppTheme.primaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search budgets...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          
          // Budgets list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBudgetsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.receipt_long),
        onPressed: () {
          // Navigate to add expense page
          // This will be implemented in the next section
        },
      ),
    );
  }

  Widget _buildBudgetsList() {
    final filteredBudgets = _getFilteredBudgets();
    
    if (filteredBudgets.isEmpty) {
      return EmptyStateWidget(
        message: 'No authorized budgets found',
        icon: Icons.account_balance_wallet,
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredBudgets.length,
      itemBuilder: (context, index) {
        final budget = filteredBudgets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              budget['name'] ?? 'Unnamed Budget',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  budget['description'] ?? 'No description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Text(
                  'Budget: ${_formatCurrency(budget['budget'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: () {
                // Navigate to budget details
                // Will be implemented in the next part
              },
            ),
          ),
        );
      },
    );
  }
}