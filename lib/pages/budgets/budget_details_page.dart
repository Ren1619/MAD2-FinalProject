import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import '../expenses/add_expense_page.dart';
import 'dart:async';

class BudgetDetailsPage extends StatefulWidget {
  final Map<String, dynamic> budget;

  const BudgetDetailsPage({super.key, required this.budget});

  @override
  State<BudgetDetailsPage> createState() => _BudgetDetailsPageState();
}

class _BudgetDetailsPageState extends State<BudgetDetailsPage> 
    with TickerProviderStateMixin {
  // Data
  Map<String, dynamic>? _budgetData;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  Map<String, dynamic>? _userData;
  
  // Loading states
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMoreExpenses = false;
  bool _hasMoreExpenses = true;
  
  // Pagination
  static const int _expensesPerPage = 20;
  int _currentExpensePage = 0;
  
  // Filters
  String _expenseStatusFilter = 'All';
  String _searchQuery = '';
  Timer? _searchDebouncer;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Scroll controller for lazy loading
  final ScrollController _expensesScrollController = ScrollController();

  final List<String> _expenseStatusOptions = [
    'All',
    'Pending',
    'Approved',
    'Fraudulent',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
    _loadInitialData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  void _setupScrollListener() {
    _expensesScrollController.addListener(() {
      if (_expensesScrollController.position.pixels >=
          _expensesScrollController.position.maxScrollExtent - 200) {
        _loadMoreExpenses();
      }
    });
  }

  // Helper methods for responsive layout
  bool get _isMobile => MediaQuery.of(context).size.width < 768;
  bool get _isTablet {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1024;
  }
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  EdgeInsets get _responsivePadding {
    if (_isMobile) return const EdgeInsets.all(12);
    if (_isTablet) return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }

  EdgeInsets get _responsiveCardPadding {
    if (_isMobile) return const EdgeInsets.all(16);
    if (_isTablet) return const EdgeInsets.all(20);
    return const EdgeInsets.all(24);
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    // Start with the budget data we already have
    setState(() {
      _budgetData = widget.budget;
      _isInitialLoading = true;
    });

    // Load user data first (usually fast)
    await _loadUserData();

    // Then load other data in parallel
    await Future.wait([
      _loadBudgetDetails(),
      _loadExpenses(isInitial: true),
    ]);

    if (!mounted) return;

    setState(() => _isInitialLoading = false);
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<FirebaseAuthService>(
      context,
      listen: false,
    );
    final userData = await authService.currentUser;

    if (!mounted) return;

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

      if (!mounted) return;

      setState(() {
        _budgetData = budgetData ?? widget.budget;
      });
    } catch (e) {
      print('Error loading budget details: $e');
      if (!mounted) return;
      setState(() => _budgetData = widget.budget);
    }
  }

  Future<void> _loadExpenses({bool isInitial = false}) async {
    if (!isInitial && (_isLoadingMoreExpenses || !_hasMoreExpenses)) return;

    setState(() {
      if (isInitial) {
        _currentExpensePage = 0;
        _hasMoreExpenses = true;
      } else {
        _isLoadingMoreExpenses = true;
      }
    });

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      
      final expenses = await budgetService.getExpensesForBudget(
        widget.budget['budget_id'],
      );

      if (!mounted) return;

      setState(() {
        if (isInitial) {
          _expenses = expenses;
          _filteredExpenses = expenses.take(_expensesPerPage).toList();
          _currentExpensePage = 1;
        } else {
          final startIndex = _currentExpensePage * _expensesPerPage;
          final endIndex = startIndex + _expensesPerPage;
          
          if (startIndex < _expenses.length) {
            _filteredExpenses.addAll(
              _expenses.skip(startIndex).take(_expensesPerPage).toList()
            );
            _currentExpensePage++;
          }
          
          _hasMoreExpenses = endIndex < _expenses.length;
        }
      });

      _applyExpenseFilters();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error loading expenses: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMoreExpenses = false);
      }
    }
  }

  Future<void> _loadMoreExpenses() async {
    await _loadExpenses(isInitial: false);
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    setState(() => _isRefreshing = true);
    
    // Add haptic feedback
    HapticFeedback.mediumImpact();

    await Future.wait([
      _loadBudgetDetails(),
      _loadExpenses(isInitial: true),
    ]);

    if (!mounted) return;

    setState(() => _isRefreshing = false);
    
    _showSuccessSnackBar('Budget data refreshed');
  }

  void _applyExpenseFilters() {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      setState(() {
        List<Map<String, dynamic>> filtered = _expenses;

        // Search filter
        if (_searchQuery.isNotEmpty) {
          final searchLower = _searchQuery.toLowerCase();
          filtered = filtered.where((expense) {
            final description = (expense['expense_desc'] ?? '').toLowerCase();
            final creatorName = (expense['created_by_name'] ?? '').toLowerCase();
            return description.contains(searchLower) || 
                   creatorName.contains(searchLower);
          }).toList();
        }

        // Status filter
        if (_expenseStatusFilter != 'All') {
          filtered = filtered.where((expense) => 
            expense['status'] == _expenseStatusFilter
          ).toList();
        }

        _filteredExpenses = filtered.take(_expensesPerPage).toList();
        _currentExpensePage = 1;
        _hasMoreExpenses = filtered.length > _expensesPerPage;
      });
    });
  }

  bool _canCreateExpenses() {
    if (_userData?['role'] != 'Authorized Spender') return false;
    if (_budgetData?['status'] != 'Active') return false;

    final authorizedSpenders = _budgetData?['authorized_spenders'] as List? ?? [];
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          AddExpensePage(budget: _budgetData!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                CurveTween(curve: Curves.easeOutCubic),
              ),
            ),
            child: child,
          );
        },
      ),
    ).then((result) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  Future<void> _updateExpenseStatus(
    Map<String, dynamic> expense,
    String newStatus, {
    String? notes,
  }) async {
    if (!mounted) return;
    
    // Optimistic update
    final expenseIndex = _filteredExpenses.indexWhere(
      (e) => e['expense_id'] == expense['expense_id']
    );
    
    if (expenseIndex != -1) {
      final oldStatus = _filteredExpenses[expenseIndex]['status'];
      
      setState(() {
        _filteredExpenses[expenseIndex] = {
          ..._filteredExpenses[expenseIndex],
          'status': newStatus,
          'updated_at': DateTime.now(),
          if (notes != null) 'notes': notes,
        };
      });
      
      HapticFeedback.lightImpact();
      
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
          _showSuccessSnackBar('Expense $newStatus successfully');
          // Refresh to get server data
          _loadExpenses(isInitial: true);
        } else {
          // Revert optimistic update
          setState(() {
            _filteredExpenses[expenseIndex]['status'] = oldStatus;
          });
          _showErrorSnackBar('Failed to update expense status');
        }
      } catch (e) {
        // Revert optimistic update
        setState(() {
          _filteredExpenses[expenseIndex]['status'] = oldStatus;
        });
        _showErrorSnackBar('Error updating expense status: $e');
      }
    }
  }

  void _markExpenseAsFraudulent(Map<String, dynamic> expense) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _FraudulentExpenseDialog(
        expense: expense,
        onMarked: (reason) {
          Navigator.pop(context);
          _updateExpenseStatus(expense, 'Fraudulent', notes: reason);
        },
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _ExpenseDetailsDialog(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(_isMobile ? 8 : 16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(_isMobile ? 8 : 16),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
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
  void dispose() {
    _searchDebouncer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _expensesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: _isMobile ? Colors.grey[50] : AppTheme.scaffoldBackground,
        appBar: CustomAppBar(
          title: 'Budget Details',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: null,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _buildLoadingSkeleton(),
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

    final budgetAmount = (_budgetData!['budget_amount'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (_budgetData!['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final remainingAmount = budgetAmount - totalExpenses;
    final percentageUsed = budgetAmount > 0 ? (totalExpenses / budgetAmount) : 0.0;
    final authorizedSpenders = _budgetData!['authorized_spenders'] as List? ?? [];

    Color progressColor = Colors.green;
    if (percentageUsed > 0.8) {
      progressColor = Colors.red;
    } else if (percentageUsed > 0.6) {
      progressColor = Colors.orange;
    }

    return Scaffold(
      backgroundColor: _isMobile ? Colors.grey[50] : AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Budget Details',
        actions: [
          IconButton(
            icon: AnimatedRotation(
              turns: _isRefreshing ? 1 : 0,
              duration: const Duration(seconds: 1),
              child: const Icon(Icons.refresh),
            ),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: _canCreateExpenses() && _isMobile
          ? FloatingActionButton.extended(
              onPressed: _createExpense,
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
              tooltip: 'Add Expense',
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildResponsiveLayout(
              budgetAmount: budgetAmount,
              totalExpenses: totalExpenses,
              remainingAmount: remainingAmount,
              percentageUsed: percentageUsed,
              progressColor: progressColor,
              authorizedSpenders: authorizedSpenders,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: _responsivePadding,
      child: Column(
        children: [
          // Budget overview skeleton
          _buildSkeletonCard(height: 300),
          const SizedBox(height: 20),
          // Authorized spenders skeleton
          _buildSkeletonCard(height: 150),
          const SizedBox(height: 20),
          // Expenses skeleton
          _buildSkeletonCard(height: 400),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard({required double height}) {
    return Card(
      elevation: _isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: height,
        padding: _responsiveCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 150,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout({
    required double budgetAmount,
    required double totalExpenses,
    required double remainingAmount,
    required double percentageUsed,
    required Color progressColor,
    required List authorizedSpenders,
  }) {
    if (_isDesktop) {
      return _buildDesktopLayout(
        budgetAmount: budgetAmount,
        totalExpenses: totalExpenses,
        remainingAmount: remainingAmount,
        percentageUsed: percentageUsed,
        progressColor: progressColor,
        authorizedSpenders: authorizedSpenders,
      );
    } else {
      return _buildMobileTabletLayout(
        budgetAmount: budgetAmount,
        totalExpenses: totalExpenses,
        remainingAmount: remainingAmount,
        percentageUsed: percentageUsed,
        progressColor: progressColor,
        authorizedSpenders: authorizedSpenders,
      );
    }
  }

  Widget _buildDesktopLayout({
    required double budgetAmount,
    required double totalExpenses,
    required double remainingAmount,
    required double percentageUsed,
    required Color progressColor,
    required List authorizedSpenders,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column - Budget Overview and Authorized Spenders
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildBudgetOverviewCard(
                  budgetAmount: budgetAmount,
                  totalExpenses: totalExpenses,
                  remainingAmount: remainingAmount,
                  percentageUsed: percentageUsed,
                  progressColor: progressColor,
                ),
                const SizedBox(height: 24),
                _buildAuthorizedSpendersCard(authorizedSpenders),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right Column - Expenses
          Expanded(
            flex: 2,
            child: _buildExpensesCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabletLayout({
    required double budgetAmount,
    required double totalExpenses,
    required double remainingAmount,
    required double percentageUsed,
    required Color progressColor,
    required List authorizedSpenders,
  }) {
    return SingleChildScrollView(
      padding: _responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBudgetOverviewCard(
            budgetAmount: budgetAmount,
            totalExpenses: totalExpenses,
            remainingAmount: remainingAmount,
            percentageUsed: percentageUsed,
            progressColor: progressColor,
          ),
          SizedBox(height: _isMobile ? 16 : 24),
          _buildAuthorizedSpendersCard(authorizedSpenders),
          SizedBox(height: _isMobile ? 16 : 24),
          _buildExpensesCard(),
          if (_isMobile) const SizedBox(height: 80), // FAB spacing
        ],
      ),
    );
  }

  Widget _buildBudgetOverviewCard({
    required double budgetAmount,
    required double totalExpenses,
    required double remainingAmount,
    required double percentageUsed,
    required Color progressColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: _isMobile ? 2 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppTheme.primaryColor.withOpacity(0.02),
              ],
            ),
          ),
          child: Padding(
            padding: _responsiveCardPadding,
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
                            _budgetData!['budget_name'] ?? 'Unnamed Budget',
                            style: TextStyle(
                              fontSize: _isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _budgetData!['budget_description'] ?? 'No description',
                            style: TextStyle(
                              fontSize: _isMobile ? 14 : 16,
                              color: AppTheme.textSecondary,
                              height: 1.4,
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

                SizedBox(height: _isMobile ? 20 : 24),

                // Statistics Grid with animation
                _buildStatisticsGrid(
                  budgetAmount: budgetAmount,
                  totalExpenses: totalExpenses,
                  remainingAmount: remainingAmount,
                ),

                if (_budgetData!['status'] == 'Active' ||
                    _budgetData!['status'] == 'Completed') ...[
                  SizedBox(height: _isMobile ? 20 : 24),
                  _buildProgressSection(
                    percentageUsed,
                    progressColor,
                    totalExpenses,
                    budgetAmount,
                  ),
                ],

                SizedBox(height: _isMobile ? 20 : 24),

                // Budget Information
                _buildBudgetInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid({
    required double budgetAmount,
    required double totalExpenses,
    required double remainingAmount,
  }) {
    final stats = [
      {
        'label': 'Budget Amount',
        'value': _formatCurrency(budgetAmount),
        'icon': Icons.account_balance_wallet,
        'color': AppTheme.primaryColor,
      },
      {
        'label': 'Total Expenses',
        'value': _formatCurrency(totalExpenses),
        'icon': Icons.receipt,
        'color': Colors.orange,
      },
      {
        'label': 'Remaining',
        'value': _formatCurrency(remainingAmount),
        'icon': Icons.savings,
        'color': remainingAmount >= 0 ? Colors.green : Colors.red,
      },
      {
        'label': 'Expenses',
        'value': '${_expenses.length}',
        'icon': Icons.list_alt,
        'color': Colors.blue,
      },
    ];

    if (_isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: _buildStatCard(stats[index]),
          ),
        ),
      );
    } else {
      return Row(
        children: stats
            .asMap()
            .entries
            .map((entry) => Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + (entry.key * 100)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _buildStatCard(entry.value),
                      ),
                    ),
                  ),
                ))
            .toList(),
      );
    }
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: (stat['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (stat['color'] as Color).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: stat['color'],
              shape: BoxShape.circle,
            ),
            child: Icon(
              stat['icon'],
              color: Colors.white,
              size: _isMobile ? 20 : 24,
            ),
          ),
          SizedBox(height: _isMobile ? 6 : 8),
          Text(
            stat['value'],
            style: TextStyle(
              fontSize: _isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: stat['color'],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            stat['label'],
            style: TextStyle(
              fontSize: _isMobile ? 10 : 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(
    double percentageUsed,
    Color progressColor,
    double totalExpenses,
    double budgetAmount,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(percentageUsed * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percentageUsed.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 12,
              ),
            ),
          ),
          if (percentageUsed > 1.0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget exceeded by ${_formatCurrency(totalExpenses - budgetAmount)}',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            'Created by',
            _budgetData!['created_by_name'] ?? 'Unknown',
            Icons.person,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Created on',
            _formatTimestamp(_budgetData!['created_at']),
            Icons.calendar_today,
          ),
          if (_budgetData!['notes'] != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Notes', _budgetData!['notes'], Icons.note),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthorizedSpendersCard(List authorizedSpenders) {
    return Card(
      elevation: _isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: _responsiveCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: AppTheme.primaryColor,
                  size: _isMobile ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Authorized Spenders',
                  style: TextStyle(
                    fontSize: _isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${authorizedSpenders.length}',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (authorizedSpenders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No authorized spenders assigned',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: _isMobile ? 6 : 8,
                runSpacing: _isMobile ? 6 : 8,
                children: authorizedSpenders.map<Widget>((spender) {
                  return _buildSpenderChip(spender);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpenderChip(Map<String, dynamic> spender) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 10 : 12,
        vertical: _isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryLightColor,
            AppTheme.primaryColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: _isMobile ? 10 : 12,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              (spender['name'] ?? '')
                  .split(' ')
                  .map((e) => e.isNotEmpty ? e[0] : '')
                  .join('')
                  .toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: _isMobile ? 9 : 10,
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
              fontSize: _isMobile ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesCard() {
    return Card(
      elevation: _isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: _responsiveCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: AppTheme.primaryColor,
                  size: _isMobile ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Expenses',
                  style: TextStyle(
                    fontSize: _isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                if (_canCreateExpenses() && !_isMobile)
                  ElevatedButton.icon(
                    onPressed: _createExpense,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Filters
            _buildExpenseFilters(),

            const SizedBox(height: 16),

            // Expenses List
            _buildExpensesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseFilters() {
    if (_isMobile) {
      return Column(
        children: [
          CustomSearchField(
            hintText: 'Search expenses...',
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyExpenseFilters();
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _expenseStatusFilter,
                isExpanded: true,
                items: _expenseStatusOptions.map((status) {
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
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: CustomSearchField(
              hintText: 'Search expenses...',
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyExpenseFilters();
              },
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _expenseStatusFilter,
                items: _expenseStatusOptions.map((status) {
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
            ),
          ),
        ],
      );
    }
  }

  Widget _buildExpensesList() {
    if (_filteredExpenses.isEmpty && _searchQuery.isEmpty && _expenseStatusFilter == 'All') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: _isMobile ? 48 : 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses recorded yet',
              style: TextStyle(
                fontSize: _isMobile ? 14 : 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (_canCreateExpenses()) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _createExpense,
                icon: const Icon(Icons.add),
                label: const Text('Create First Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_filteredExpenses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: _isMobile ? 48 : 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses match your search criteria',
              style: TextStyle(
                fontSize: _isMobile ? 14 : 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...List.generate(
          _filteredExpenses.length,
          (index) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 200 + (index * 50)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildExpenseCard(_filteredExpenses[index]),
              ),
            ),
          ),
        ),
        if (_isLoadingMoreExpenses)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        if (_hasMoreExpenses && !_isLoadingMoreExpenses)
          TextButton(
            onPressed: _loadMoreExpenses,
            child: const Text('Load more'),
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
            fontSize: _isMobile ? 12 : 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: _isMobile ? 12 : 13,
            ),
          ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showExpenseDetails(expense),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(_isMobile ? 12 : 16),
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
                              style: TextStyle(
                                fontSize: _isMobile ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'by ${expense['created_by_name'] ?? 'Unknown'} • ${_formatTimestamp(expense['created_at'])}',
                              style: TextStyle(
                                fontSize: _isMobile ? 11 : 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(amount),
                            style: TextStyle(
                              fontSize: _isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
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
                              Icon(
                                Icons.receipt,
                                size: 12,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Receipt',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (_canManageExpenses() &&
                          status == 'Pending' &&
                          !_isMobile) ...[
                        TextButton.icon(
                          onPressed: () => _updateExpenseStatus(expense, 'Approved'),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Approve'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _markExpenseAsFraudulent(expense),
                          icon: const Icon(Icons.warning, size: 14),
                          label: const Text('Fraudulent'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Fraudulent Expense Dialog remains the same
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[700], size: 24),
          const SizedBox(width: 8),
          Text('Mark as Fraudulent', style: TextStyle(color: Colors.red[700])),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense: ${widget.expense['expense_desc']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ₱${(widget.expense['expense_amt'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Reason for marking as fraudulent',
                hintText:
                    'Explain why this expense is considered fraudulent...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The expense will be marked as fraudulent and the user will be notified.',
                      style: TextStyle(fontSize: 12, color: Colors.red[600]),
                    ),
                  ),
                ],
              ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Mark as Fraudulent'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// Expense Details Dialog remains the same
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
    return '₱${amount.toStringAsFixed(2)}';
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
    final isMobile = MediaQuery.of(context).size.width < 768;
    final amount = (expense['expense_amt'] as num?)?.toDouble() ?? 0.0;
    final status = expense['status'] ?? 'Unknown';
    final hasReceipt = expense['has_receipt'] == true;
    final receiptImage = expense['receipt_image'] as String?;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 8),
          Text(
            'Expense Details',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expense Information Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Receipt Section
              Text(
                'Receipt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),

              if (hasReceipt && receiptImage != null) ...[
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      Uri.parse(
                        'data:image/jpeg;base64,$receiptImage',
                      ).data!.contentAsBytes(),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildReceiptPlaceholder(
                          icon: Icons.error,
                          message: 'Failed to load receipt image',
                          color: Colors.red,
                        );
                      },
                    ),
                  ),
                ),
              ] else if (hasReceipt) ...[
                _buildReceiptPlaceholder(
                  icon: Icons.receipt,
                  message: 'Receipt attached but preview unavailable',
                  color: Colors.blue,
                ),
              ] else ...[
                _buildReceiptPlaceholder(
                  icon: Icons.receipt_long_outlined,
                  message: 'No receipt attached',
                  color: Colors.grey,
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onMarkFraudulent(expense);
            },
            icon: const Icon(Icons.warning),
            label: const Text('Fraudulent'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Close'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildReceiptPlaceholder({
    required IconData icon,
    required String message,
    required MaterialColor color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: color[50],
        border: Border.all(color: color[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color[400], size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: color[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}