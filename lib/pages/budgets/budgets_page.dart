import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import 'budget_details_page.dart';
import 'create_budget_page.dart';
import 'dart:math' as math;
import 'dart:async';

class BudgetsPage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final Map<String, dynamic>? userData;
  const BudgetsPage({super.key, this.onOpenDrawer, this.userData});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Controllers
  late TabController _tabController;
  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;
  late AnimationController _refreshAnimationController;
  late Animation<double> _fabScaleAnimation;

  // State variables
  Map<String, dynamic>? _userData;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _showFloatingHeader = false;
  bool _isDisposed = false;

  // Cache timestamp
  DateTime? _lastRefreshTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  // Budget lists by status
  Map<String, List<Map<String, dynamic>>> _budgetsByStatus = {
    'Pending for Approval': [],
    'Active': [],
    'Completed': [],
    'For Revision': [],
  };

  // Search and filter state
  String _searchQuery = '';
  Timer? _searchDebouncer;
  Map<String, List<Map<String, dynamic>>> _filteredBudgets = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadInitialData();
  }

  void _initializeControllers() {
    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    // FAB animation controller
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabScaleAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );

    // Refresh animation controller
    _refreshAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    // Show FAB after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed && mounted) {
        _fabAnimationController.forward();
      }
    });
  }

  void _scrollListener() {
    if (_isDisposed || !mounted) return;

    try {
      final showHeader =
          _scrollController.hasClients && _scrollController.offset > 200;
      if (showHeader != _showFloatingHeader) {
        if (mounted) {
          setState(() {
            _showFloatingHeader = showHeader;
          });
        }
      }
    } catch (e) {
      debugPrint('Scroll listener error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebouncer?.cancel();
    _tabController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isDisposed || !mounted) return;

    // Check if we have cached data
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) < _cacheValidity &&
        _budgetsByStatus['Active']!.isNotEmpty) {
      setState(() => _isInitialLoading = false);
      return;
    }

    await _loadUserData();
    await _loadBudgets();

    if (!mounted || _isDisposed) return;

    setState(() => _isInitialLoading = false);
  }

  Future<void> _loadUserData() async {
    if (_isDisposed || !mounted) return;

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final userData = await authService.currentUser;

      if (!mounted || _isDisposed) return;

      setState(() {
        _userData = userData;
      });
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showErrorSnackBar('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadBudgets() async {
    if (_userData == null || _isDisposed || !mounted) return;

    try {
      if (!_isRefreshing) {
        setState(() => _isInitialLoading = true);
      }

      // Direct Firestore access with timeout
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final companyId = _userData!['company_id'];

      // Get all budgets for the company with timeout
      final snapshot = await firestore
          .collection('budgets')
          .where('company_id', isEqualTo: companyId)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (!mounted || _isDisposed) return;

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

        if (budgetsByStatus.containsKey(status)) {
          budgetsByStatus[status]!.add(data);
        }
      }

      // Sort budgets by creation date (newest first)
      budgetsByStatus.forEach((status, budgets) {
        budgets.sort((a, b) {
          try {
            final aDate = a['created_at']?.toDate() ?? DateTime(1970);
            final bDate = b['created_at']?.toDate() ?? DateTime(1970);
            return bDate.compareTo(aDate);
          } catch (_) {
            return 0;
          }
        });
      });

      if (!mounted || _isDisposed) return;

      setState(() {
        _budgetsByStatus = budgetsByStatus;
        _filteredBudgets = Map.from(budgetsByStatus);
        _isInitialLoading = false;
        _isRefreshing = false;
        _lastRefreshTime = DateTime.now();
      });
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialLoading = false;
          _isRefreshing = false;
        });
        _showErrorSnackBar('Error loading budgets: $e');
      }
    }
  }

  Future<void> _refreshBudgets() async {
    if (_isDisposed || !mounted || _isRefreshing) return;

    setState(() => _isRefreshing = true);

    // Start refresh animation
    _refreshAnimationController.repeat();

    // Haptic feedback
    HapticFeedback.mediumImpact();

    await _loadBudgets();

    // Stop animation
    _refreshAnimationController.stop();
    _refreshAnimationController.reset();

    if (mounted && !_isDisposed) {
      _showSuccessSnackBar('Budget list updated');
    }
  }

  void _filterBudgets(String query) {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _isDisposed) return;

      setState(() {
        _searchQuery = query.toLowerCase();

        if (_searchQuery.isEmpty) {
          _filteredBudgets = Map.from(_budgetsByStatus);
        } else {
          _filteredBudgets = {};
          _budgetsByStatus.forEach((status, budgets) {
            _filteredBudgets[status] =
                budgets.where((budget) {
                  final name = (budget['budget_name'] ?? '').toLowerCase();
                  final description =
                      (budget['budget_description'] ?? '').toLowerCase();
                  final creatorName =
                      (budget['created_by_name'] ?? '').toLowerCase();

                  return name.contains(_searchQuery) ||
                      description.contains(_searchQuery) ||
                      creatorName.contains(_searchQuery);
                }).toList();
          });
        }
      });
    });
  }

  void _showCreateBudgetPage() {
    if (_isDisposed || !mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const CreateBudgetPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          );
        },
      ),
    ).then((result) {
      if (result == true && mounted && !_isDisposed) {
        setState(() => _isRefreshing = true);

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_isDisposed) {
            _loadBudgets().then((_) {
              if (mounted && !_isDisposed) {
                _tabController.animateTo(0);
                _showSuccessSnackBar('Budget created successfully');
              }
            });
          }
        });
      }
    });
  }

  void _viewBudgetDetails(Map<String, dynamic> budget) {
    if (_isDisposed || !mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                BudgetDetailsPage(budget: budget),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) {
      if (mounted && !_isDisposed) {
        _loadBudgets();
      }
    });
  }

  Future<void> _approveBudget(Map<String, dynamic> budget) async {
    if (_isDisposed || !mounted) return;

    // Optimistic update
    setState(() {
      _budgetsByStatus['Pending for Approval']!.remove(budget);
      _budgetsByStatus['Active']!.insert(0, {
        ...budget,
        'status': 'Active',
        'updated_at': DateTime.now(),
      });
      _filteredBudgets = Map.from(_budgetsByStatus);
    });

    HapticFeedback.lightImpact();

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      final success = await budgetService.updateBudgetStatus(
        budget['budget_id'],
        'Active',
      );

      if (mounted && !_isDisposed) {
        if (success) {
          _showSuccessSnackBar('Budget approved successfully');
        } else {
          // Revert optimistic update
          setState(() {
            _budgetsByStatus['Active']!.removeWhere(
              (b) => b['budget_id'] == budget['budget_id'],
            );
            _budgetsByStatus['Pending for Approval']!.insert(0, budget);
            _filteredBudgets = Map.from(_budgetsByStatus);
          });
          _showErrorSnackBar('Failed to approve budget');
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        // Revert optimistic update
        setState(() {
          _budgetsByStatus['Active']!.removeWhere(
            (b) => b['budget_id'] == budget['budget_id'],
          );
          _budgetsByStatus['Pending for Approval']!.insert(0, budget);
          _filteredBudgets = Map.from(_budgetsByStatus);
        });
        _showErrorSnackBar('Error approving budget: $e');
      }
    }
  }

  Future<void> _markForRevision(Map<String, dynamic> budget) async {
    if (_isDisposed || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => RevisionNotesDialog(
            budget: budget,
            onRevisionMarked: () {
              Navigator.pop(context);
              if (mounted && !_isDisposed) {
                _loadBudgets();
              }
            },
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (_isDisposed || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (_isDisposed || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  bool _canCreateBudgets() {
    return _userData?['role'] == 'Financial Planning and Budgeting Officer';
  }

  bool _canApproveBudgets() {
    return _userData?['role'] == 'Budget Manager';
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

      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isDisposed) {
      return const Scaffold(body: Center(child: Text('Page disposed')));
    }

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    if (_isInitialLoading && !_isRefreshing) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        appBar: _buildAppBar(isMobile),
        body: _buildLoadingSkeleton(isMobile, isTablet, isDesktop),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: _buildAppBar(isMobile),
      floatingActionButton: _buildFloatingActionButton(isMobile),
      body: _buildBody(isDesktop, isTablet, isMobile),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return CustomAppBar(
      title: 'Budget Management',
      onMenuPressed: widget.onOpenDrawer,
      userData: widget.userData,
      actions: [
        if (!isMobile)
          Container(
            width: 200,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: TextField(
              onChanged: _filterBudgets,
              decoration: InputDecoration(
                hintText: 'Search budgets...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        IconButton(
          icon: AnimatedRotation(
            turns: _isRefreshing ? 1 : 0,
            duration: const Duration(seconds: 1),
            child: const Icon(Icons.refresh),
          ),
          onPressed: _isRefreshing ? null : _refreshBudgets,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget? _buildFloatingActionButton(bool isMobile) {
    if (isMobile && _canCreateBudgets()) {
      return ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: _showCreateBudgetPage,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add),
          label: const Text('Create Budget'),
          tooltip: 'Create Budget',
        ),
      );
    }
    return null;
  }

  Widget _buildLoadingSkeleton(bool isMobile, bool isTablet, bool isDesktop) {
    return Column(
      children: [
        // Tab bar skeleton
        Container(
          height: 48,
          color: Colors.white,
          child: Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Content skeleton
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 2 : 1,
                childAspectRatio: isDesktop ? 1.6 : (isTablet ? 2.5 : 2),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: 6,
              itemBuilder:
                  (context, index) => Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 150,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 80,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Container(
                                width: 60,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
      ],
    );
  }

  Widget _buildBody(bool isDesktop, bool isTablet, bool isMobile) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshBudgets,
          child: Builder(
            builder: (context) {
              try {
                if (isDesktop) {
                  return _buildDesktopLayout();
                } else if (isTablet) {
                  return _buildTabletLayout();
                } else {
                  return _buildMobileLayout();
                }
              } catch (e) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text('Error loading budgets: $e'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBudgets,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),

        // Floating header for mobile and tablet when scrolled
        if (_showFloatingHeader && !isDesktop) _buildFloatingHeader(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar with stats
        Container(
          width: 280,
          height: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserRoleCard(),
              const SizedBox(height: 20),

              // Search field for desktop
              TextField(
                onChanged: _filterBudgets,
                decoration: InputDecoration(
                  hintText: 'Search budgets...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Budget Statistics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _buildDesktopStatCards(),
              const SizedBox(height: 20),

              const Divider(),
              const SizedBox(height: 20),

              // Last refresh indicator
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Last refreshed: ${_lastRefreshTime != null ? "${_lastRefreshTime!.hour}:${_lastRefreshTime!.minute.toString().padLeft(2, '0')}" : "Never"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              const Spacer(),

              // Action buttons at bottom of sidebar
              if (_canCreateBudgets())
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showCreateBudgetPage,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Budget'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _refreshBudgets,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Budgets'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right main content area with tabs
        Expanded(
          child: Column(
            children: [
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      text:
                          'Pending (${_filteredBudgets['Pending for Approval']?.length ?? 0})',
                    ),
                    Tab(
                      text:
                          'Active (${_filteredBudgets['Active']?.length ?? 0})',
                    ),
                    Tab(
                      text:
                          'Completed (${_filteredBudgets['Completed']?.length ?? 0})',
                    ),
                    Tab(
                      text:
                          'For Revision (${_filteredBudgets['For Revision']?.length ?? 0})',
                    ),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDesktopBudgetList('Pending for Approval'),
                    _buildDesktopBudgetList('Active'),
                    _buildDesktopBudgetList('Completed'),
                    _buildDesktopBudgetList('For Revision'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopStatCards() {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder:
              (context, value, child) => Transform.scale(
                scale: value,
                child: _buildDesktopStatCard(
                  'Pending for Approval',
                  _budgetsByStatus['Pending for Approval']!.length,
                  Colors.orange,
                ),
              ),
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder:
              (context, value, child) => Transform.scale(
                scale: value,
                child: _buildDesktopStatCard(
                  'Active',
                  _budgetsByStatus['Active']!.length,
                  Colors.green,
                ),
              ),
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder:
              (context, value, child) => Transform.scale(
                scale: value,
                child: _buildDesktopStatCard(
                  'Completed',
                  _budgetsByStatus['Completed']!.length,
                  Colors.blue,
                ),
              ),
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder:
              (context, value, child) => Transform.scale(
                scale: value,
                child: _buildDesktopStatCard(
                  'For Revision',
                  _budgetsByStatus['For Revision']!.length,
                  Colors.red,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildDesktopStatCard(String title, int count, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_getIconForStatus(title), color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$count budget${count != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'Pending for Approval':
        return Icons.hourglass_top;
      case 'Active':
        return Icons.check_circle;
      case 'Completed':
        return Icons.task_alt;
      case 'For Revision':
        return Icons.edit_note;
      default:
        return Icons.info;
    }
  }

  Widget _buildDesktopBudgetList(String status) {
    final budgets = _filteredBudgets[status] ?? [];

    if (budgets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBudgets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 500,
            padding: const EdgeInsets.all(24),
            child: EmptyStateWidget(
              message: _getEmptyStateMessage(status),
              icon: _getIconForStatus(status),
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
      child: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeOutCubic,
            builder:
                (context, value, child) => Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: _buildDesktopBudgetCard(budgets[index], status),
                  ),
                ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopBudgetCard(Map<String, dynamic> budget, String status) {
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

    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _viewBudgetDetails(budget),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with budget name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      budget['budget_name'] ?? 'Unnamed Budget',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(status: status),
                ],
              ),

              // Description
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  budget['budget_description'] ?? 'No description',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Budget info in two columns
              Row(
                children: [
                  // Column 1: Budget amount and expenses
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDesktopInfoItem(
                          'Budget Amount',
                          _formatCurrency(budgetAmount),
                          Icons.account_balance_wallet,
                        ),
                        const SizedBox(height: 8),
                        _buildDesktopInfoItem(
                          'Total Expenses',
                          _formatCurrency(totalExpenses),
                          Icons.receipt,
                        ),
                      ],
                    ),
                  ),

                  // Column 2: Remaining and expense count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDesktopInfoItem(
                          'Remaining',
                          _formatCurrency(remainingAmount),
                          Icons.savings,
                        ),
                        const SizedBox(height: 8),
                        _buildDesktopInfoItem(
                          'Expenses Count',
                          expenseCount.toString(),
                          Icons.list_alt,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Progress bar for Active and Completed budgets
              if (status == 'Active' || status == 'Completed')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Budget Usage',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '${(percentageUsed * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: percentageUsed.clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder:
                            (context, value, child) => LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progressColor,
                              ),
                              minHeight: 8,
                            ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // Footer with created by and action buttons
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(budget['created_at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons for budget managers
                  if (status == 'Pending for Approval' && _canApproveBudgets())
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () => _approveBudget(budget),
                          tooltip: 'Approve',
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(8),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_note,
                            color: Colors.orange,
                          ),
                          onPressed: () => _markForRevision(budget),
                          tooltip: 'Mark for Revision',
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),

                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () => _viewBudgetDetails(budget),
                    tooltip: 'View Details',
                    color: AppTheme.primaryColor,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor.withOpacity(0.7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildTabletHeader(),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primaryColor,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                    isScrollable: true,
                    tabs: [
                      Tab(
                        text:
                            'Pending (${_filteredBudgets['Pending for Approval']?.length ?? 0})',
                      ),
                      Tab(
                        text:
                            'Active (${_filteredBudgets['Active']?.length ?? 0})',
                      ),
                      Tab(
                        text:
                            'Completed (${_filteredBudgets['Completed']?.length ?? 0})',
                      ),
                      Tab(
                        text:
                            'For Revision (${_filteredBudgets['For Revision']?.length ?? 0})',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabletBudgetList('Pending for Approval'),
          _buildTabletBudgetList('Active'),
          _buildTabletBudgetList('Completed'),
          _buildTabletBudgetList('For Revision'),
        ],
      ),
    );
  }

  Widget _buildTabletHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          _buildUserRoleCard(),
          const SizedBox(height: 20),

          // Search field
          TextField(
            onChanged: _filterBudgets,
            decoration: InputDecoration(
              hintText: 'Search budgets...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildTabletStatCard(
                'Pending for Approval',
                _budgetsByStatus['Pending for Approval']!.length,
                Colors.orange,
              ),
              _buildTabletStatCard(
                'Active',
                _budgetsByStatus['Active']!.length,
                Colors.green,
              ),
              _buildTabletStatCard(
                'Completed',
                _budgetsByStatus['Completed']!.length,
                Colors.blue,
              ),
              _buildTabletStatCard(
                'For Revision',
                _budgetsByStatus['For Revision']!.length,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
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
    );
  }

  Widget _buildTabletStatCard(String title, int count, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder:
          (context, value, child) => Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getIconForStatus(title), color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count budget${count != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTabletBudgetList(String status) {
    final budgets = _filteredBudgets[status] ?? [];

    if (budgets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBudgets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 500,
            padding: const EdgeInsets.all(24),
            child: EmptyStateWidget(
              message: _getEmptyStateMessage(status),
              icon: _getIconForStatus(status),
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
        padding: const EdgeInsets.all(20),
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeOutCubic,
            builder:
                (context, value, child) => Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _buildBudgetCard(budgets[index], status, false),
                  ),
                ),
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildMobileHeader(),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primaryColor,
                    indicatorWeight: 3,
                    isScrollable: true,
                    tabs: [
                      Tab(
                        text:
                            'Pending (${_filteredBudgets['Pending for Approval']?.length ?? 0})',
                      ),
                      Tab(
                        text:
                            'Active (${_filteredBudgets['Active']?.length ?? 0})',
                      ),
                      Tab(
                        text:
                            'Completed (${_filteredBudgets['Completed']?.length ?? 0})',
                      ),
                      Tab(
                        text:
                            'For Revision (${_filteredBudgets['For Revision']?.length ?? 0})',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMobileBudgetList('Pending for Approval'),
          _buildMobileBudgetList('Active'),
          _buildMobileBudgetList('Completed'),
          _buildMobileBudgetList('For Revision'),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          _buildUserRoleCard(),
          const SizedBox(height: 16),

          // Search field
          TextField(
            onChanged: _filterBudgets,
            decoration: InputDecoration(
              hintText: 'Search budgets...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMobileStatCard(
                  'Pending',
                  _budgetsByStatus['Pending for Approval']!.length,
                  Colors.orange,
                ),
                const SizedBox(width: 12),
                _buildMobileStatCard(
                  'Active',
                  _budgetsByStatus['Active']!.length,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildMobileStatCard(
                  'Completed',
                  _budgetsByStatus['Completed']!.length,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildMobileStatCard(
                  'For Revision',
                  _budgetsByStatus['For Revision']!.length,
                  Colors.red,
                ),
              ],
            ),
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
    );
  }

  Widget _buildMobileStatCard(String title, int count, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder:
          (context, value, child) => Transform.scale(
            scale: value,
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildMobileBudgetList(String status) {
    final budgets = _filteredBudgets[status] ?? [];

    if (budgets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBudgets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 500,
            padding: const EdgeInsets.all(24),
            child: EmptyStateWidget(
              message: _getEmptyStateMessage(status),
              icon: _getIconForStatus(status),
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
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeOutCubic,
            builder:
                (context, value, child) => Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _buildBudgetCard(budgets[index], status, true),
                  ),
                ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetCard(
    Map<String, dynamic> budget,
    String status,
    bool isMobile,
  ) {
    final budgetAmount = (budget['budget_amount'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (budget['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final remainingAmount = budgetAmount - totalExpenses;
    final percentageUsed =
        budgetAmount > 0 ? (totalExpenses / budgetAmount) : 0.0;

    Color progressColor = Colors.green;
    if (percentageUsed > 0.8) {
      progressColor = Colors.red;
    } else if (percentageUsed > 0.6) {
      progressColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: InkWell(
        onTap: () => _viewBudgetDetails(budget),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      budget['budget_name'] ?? 'Unnamed Budget',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(status: status),
                ],
              ),

              if (budget['budget_description'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  budget['budget_description'],
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Budget amounts
              if (isMobile) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildMobileInfoItem(
                            'Budget',
                            _formatCurrency(budgetAmount),
                            Icons.account_balance_wallet,
                          ),
                          const SizedBox(height: 12),
                          _buildMobileInfoItem(
                            'Expenses',
                            _formatCurrency(totalExpenses),
                            Icons.receipt,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _buildMobileInfoItem(
                            'Remaining',
                            _formatCurrency(remainingAmount),
                            Icons.savings,
                          ),
                          if (status == 'Active' || status == 'Completed') ...[
                            const SizedBox(height: 12),
                            _buildMobileInfoItem(
                              'Usage',
                              '${(percentageUsed * 100).toStringAsFixed(1)}%',
                              Icons.pie_chart,
                              valueColor: progressColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
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
                        (budget['expense_count'] as int? ?? 0).toString(),
                        Icons.list_alt,
                      ),
                    ),
                  ],
                ),
              ],

              // Progress bar
              if (status == 'Active' || status == 'Completed') ...[
                const SizedBox(height: 16),
                if (!isMobile) ...[
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
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percentageUsed.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, child) => LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                          minHeight: isMobile ? 6 : 8,
                        ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Footer
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(budget['created_at']),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),

                  if (status == 'Pending for Approval' &&
                      _canApproveBudgets()) ...[
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _approveBudget(budget),
                      tooltip: 'Approve',
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.orange),
                      onPressed: () => _markForRevision(budget),
                      tooltip: 'Mark for Revision',
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(8),
                    ),
                  ],

                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _viewBudgetDetails(budget),
                    color: AppTheme.primaryColor,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),

              // Action buttons for tablet (non-mobile) pending budgets
              if (!isMobile &&
                  status == 'Pending for Approval' &&
                  _canApproveBudgets()) ...[
                const SizedBox(height: 16),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (!isMobile) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _viewBudgetDetails(budget),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileInfoItem(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor.withOpacity(0.7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildUserRoleCard() {
    final role = _userData?['role'] ?? 'Unknown';
    final userName =
        '${_userData?['f_name'] ?? ''} ${_userData?['l_name'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            child: Icon(_getRoleIcon(role), color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: $role',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (_canApproveBudgets())
            Tooltip(
              message: 'Approve Budgets',
              child: Icon(Icons.approval, color: AppTheme.primaryColor),
            ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Budget Manager':
        return Icons.account_balance;
      case 'Financial Planning and Budgeting Officer':
        return Icons.trending_up;
      case 'Authorized Spender':
        return Icons.shopping_cart;
      default:
        return Icons.person;
    }
  }

  String _getEmptyStateMessage(String status) {
    switch (status) {
      case 'Pending for Approval':
        return _canCreateBudgets()
            ? 'No budgets pending approval.\nCreate a new budget to get started.'
            : 'No budgets pending approval.\nBudgets will appear here when created by Financial Officers.';
      case 'Active':
        return 'No active budgets found.\nApproved budgets will appear here.';
      case 'Completed':
        return 'No completed budgets found.\nBudgets that have been fully utilized will appear here.';
      case 'For Revision':
        return 'No budgets marked for revision.\nBudgets that need changes will appear here.';
      default:
        return 'No budgets found.';
    }
  }

  Widget _buildFloatingHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            isScrollable: true,
            tabs: [
              Tab(
                text:
                    'Pending (${_filteredBudgets['Pending for Approval']?.length ?? 0})',
              ),
              Tab(text: 'Active (${_filteredBudgets['Active']?.length ?? 0})'),
              Tab(
                text:
                    'Completed (${_filteredBudgets['Completed']?.length ?? 0})',
              ),
              Tab(
                text:
                    'For Revision (${_filteredBudgets['For Revision']?.length ?? 0})',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced status badge with proper colors and icons
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText = status;

    switch (status) {
      case 'Pending for Approval':
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        icon = Icons.hourglass_top;
        displayText = 'Pending';
        break;
      case 'Active':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
      case 'Completed':
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        icon = Icons.task_alt;
        break;
      case 'For Revision':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        icon = Icons.edit_note;
        displayText = 'Revision';
        break;
      default:
        backgroundColor = Colors.grey.shade50;
        textColor = Colors.grey.shade800;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const EmptyStateWidget({
    Key? key,
    required this.message,
    required this.icon,
    this.onActionPressed,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: AppTheme.primaryColor),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            message.split('\n')[0],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (message.contains('\n')) ...[
            const SizedBox(height: 8),
            Text(
              message.split('\n').sublist(1).join('\n'),
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          if (onActionPressed != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onActionPressed,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// RevisionNotesDialog remains mostly the same
class RevisionNotesDialog extends StatefulWidget {
  final Map<String, dynamic> budget;
  final VoidCallback onRevisionMarked;

  const RevisionNotesDialog({
    Key? key,
    required this.budget,
    required this.onRevisionMarked,
  }) : super(key: key);

  @override
  State<RevisionNotesDialog> createState() => _RevisionNotesDialogState();
}

class _RevisionNotesDialogState extends State<RevisionNotesDialog> {
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _markForRevision() async {
    if (!mounted) return;

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

      if (!mounted) return;

      if (success) {
        widget.onRevisionMarked();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Budget marked for revision')),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Failed to mark budget for revision')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 8,
      child: Container(
        width: isMobile ? double.infinity : 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mark Budget for Revision',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Budget info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          widget.budget['budget_name'] ?? 'Unnamed Budget',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notes field
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Revision Notes',
                hintText:
                    'Enter reasons for revision or suggestions for improvement...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.comment),
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 8),

            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This budget will be moved to "For Revision" status and the creator will be notified.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _markForRevision,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isLoading
                          ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Processing...'),
                            ],
                          )
                          : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.edit_note, size: 18),
                              SizedBox(width: 8),
                              Text('Mark for Revision'),
                            ],
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Simple timeout exception class
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
