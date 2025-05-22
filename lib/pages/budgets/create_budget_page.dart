import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

class CreateBudgetPage extends StatefulWidget {
  const CreateBudgetPage({super.key});

  @override
  State<CreateBudgetPage> createState() => _CreateBudgetPageState();
}

class _CreateBudgetPageState extends State<CreateBudgetPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _budgetNameController = TextEditingController();
  final _budgetAmountController = TextEditingController();
  final _budgetDescriptionController = TextEditingController();
  final _searchController = TextEditingController();

  // Focus nodes for keyboard navigation
  final _budgetNameFocus = FocusNode();
  final _budgetAmountFocus = FocusNode();
  final _budgetDescriptionFocus = FocusNode();
  final _searchFocus = FocusNode();

  // Animation controller for step transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentStep = 0;
  final List<String> _stepTitles = [
    'Budget Details',
    'Authorized Spenders',
    'Review & Create'
  ];

  List<Map<String, dynamic>> _availableSpenders = [];
  List<Map<String, dynamic>> _filteredSpenders = [];
  List<String> _selectedSpenderIds = [];
  bool _isLoading = false;
  bool _isLoadingSpenders = true;
  String _searchQuery = '';
  
  // For budget amount formatting
  double? _budgetAmount;
  final _currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadAvailableSpenders();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
    
    // Add listener to search controller
    _searchController.addListener(_filterSpenders);
    
    // Add listener to budget amount controller for currency formatting
    _budgetAmountController.addListener(_formatCurrency);
  }
  
  void _formatCurrency() {
    String text = _budgetAmountController.text;
    if (text.isEmpty) {
      _budgetAmount = null;
      return;
    }
    
    // Remove all non-numeric characters
    String numericOnly = text.replaceAll(RegExp(r'[^0-9.]'), '');
    
    if (numericOnly.isEmpty) {
      _budgetAmount = null;
      return;
    }
    
    try {
      // Parse the numeric value
      final value = double.parse(numericOnly);
      _budgetAmount = value;
      
      // Only update if the text is different to avoid recursive updates
      final formatted = _currencyFormatter.format(value).replaceAll(',', '');
      if (text != formatted && !text.endsWith('.')) {
        // Remember cursor position
        final cursorPos = _budgetAmountController.selection.start;
        
        _budgetAmountController.text = formatted;
        
        // Restore cursor position
        if (cursorPos != null && cursorPos >= 0) {
          final newPos = math.min(cursorPos, formatted.length);
          _budgetAmountController.selection = TextSelection.fromPosition(
            TextPosition(offset: newPos),
          );
        }
      }
    } catch (e) {
      // If parsing fails, leave as is
      _budgetAmount = null;
    }
  }

  void _filterSpenders() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredSpenders = List.from(_availableSpenders);
      } else {
        _filteredSpenders = _availableSpenders.where((spender) {
          final name = (spender['name'] ?? '').toLowerCase();
          final email = (spender['email'] ?? '').toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _budgetNameController.dispose();
    _budgetAmountController.dispose();
    _budgetDescriptionController.dispose();
    _searchController.dispose();
    
    _budgetNameFocus.dispose();
    _budgetAmountFocus.dispose();
    _budgetDescriptionFocus.dispose();
    _searchFocus.dispose();
    
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSpenders() async {
    setState(() => _isLoadingSpenders = true);

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      final spenders = await budgetService.getAvailableAuthorizedSpenders();

      setState(() {
        _availableSpenders = spenders;
        _filteredSpenders = spenders;
        _isLoadingSpenders = false;
      });
    } catch (e) {
      setState(() => _isLoadingSpenders = false);
      _showErrorSnackBar('Error loading available spenders: $e');
    }
  }

  Future<void> _createBudget() async {
    if (!_formKey.currentState!.validate()) {
      // If validation fails, go back to the step with errors
      if (_currentStep == 2) {
        _goToStep(0); // Go back to budget details
      }
      return;
    }

    if (_selectedSpenderIds.isEmpty) {
      _showErrorSnackBar('Please select at least one authorized spender');
      _goToStep(1); // Go to spenders step
      return;
    }

    setState(() => _isLoading = true);

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );
      
      // Parse amount correctly (remove currency symbol)
      final amountString = _budgetAmountController.text.replaceAll(RegExp(r'[^\d.]'), '');
      final amount = double.parse(amountString);

      final success = await budgetService.createBudget(
        budgetName: _budgetNameController.text.trim(),
        budgetAmount: amount,
        budgetDescription: _budgetDescriptionController.text.trim(),
        authorizedSpenderIds: _selectedSpenderIds,
      );

      if (success) {
        _showSuccessSnackBar(
          'Budget created successfully! It is now pending approval.',
        );
        // Return true to indicate successful creation
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar('Failed to create budget. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating budget: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
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
  
  void _goToStep(int step) {
    // Save the form if moving forward
    if (step > _currentStep) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }
    
    // Handle animation
    _animationController.reset();
    
    setState(() {
      _currentStep = step;
    });
    
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    
    // Determine if we're on mobile, tablet, or desktop
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;
    
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Create New Budget',
        onMenuPressed: () => Navigator.pop(context),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: Text(isMobile ? '' : 'Cancel'),
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingSpenders
          ? const Center(
              child: LoadingIndicator(
                message: 'Loading authorized spenders...',
                useCustomIndicator: true,
              ),
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Step indicator
                  _buildStepIndicator(isMobile),
                  
                  // Form content
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: isDesktop
                          ? _buildDesktopLayout()
                          : isTablet
                              ? _buildTabletLayout()
                              : _buildMobileLayout(),
                    ),
                  ),
                  
                  // Navigation buttons
                  _buildNavigationButtons(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildStepIndicator(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: isMobile
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _stepTitles.length,
                (index) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentStep
                        ? AppTheme.primaryColor
                        : index < _currentStep
                            ? AppTheme.primaryColor.withOpacity(0.5)
                            : Colors.grey[300],
                  ),
                ),
              ),
            )
          : Row(
              children: List.generate(
                _stepTitles.length,
                (index) => Expanded(
                  child: Row(
                    children: [
                      // Circle with number
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentStep
                              ? AppTheme.primaryColor
                              : index < _currentStep
                                  ? AppTheme.primaryColor.withOpacity(0.5)
                                  : Colors.grey[300],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index <= _currentStep ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Step title
                      Text(
                        _stepTitles[index],
                        style: TextStyle(
                          fontWeight: index == _currentStep ? FontWeight.bold : FontWeight.normal,
                          color: index == _currentStep ? AppTheme.primaryColor : Colors.grey[600],
                        ),
                      ),
                      // Line connector
                      if (index < _stepTitles.length - 1)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            height: 2,
                            color: index < _currentStep
                                ? AppTheme.primaryColor
                                : Colors.grey[300],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _goToStep(_currentStep - 1),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
            if (_currentStep > 0 && _currentStep < _stepTitles.length - 1)
              const SizedBox(width: 16),
              
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isLoading 
                    ? null 
                    : () {
                        if (_currentStep < _stepTitles.length - 1) {
                          _goToStep(_currentStep + 1);
                        } else {
                          _createBudget();
                        }
                      },
                icon: Icon(_currentStep < _stepTitles.length - 1 ? Icons.arrow_forward : Icons.save),
                label: Text(_currentStep < _stepTitles.length - 1 ? 'Continue' : 'Create Budget'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column (main content)
          Expanded(
            flex: 3,
            child: _buildCurrentStepContent(isDesktop: true),
          ),
          
          const SizedBox(width: 24),
          
          // Right column (help/info panel)
          Expanded(
            flex: 1,
            child: _buildInfoPanel(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCurrentStepContent(isTablet: true),
          const SizedBox(height: 20),
          _buildInfoPanel(isTablet: true),
        ],
      ),
    );
  }
  
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCurrentStepContent(),
          const SizedBox(height: 16),
          _buildInfoPanel(isMobile: true),
        ],
      ),
    );
  }
  
  Widget _buildCurrentStepContent({bool isDesktop = false, bool isTablet = false}) {
    switch (_currentStep) {
      case 0:
        return _buildBudgetDetailsStep(isDesktop: isDesktop, isTablet: isTablet);
      case 1:
        return _buildAuthorizedSpendersStep(isDesktop: isDesktop, isTablet: isTablet);
      case 2:
        return _buildReviewStep(isDesktop: isDesktop, isTablet: isTablet);
      default:
        return Container();
    }
  }
  
  Widget _buildBudgetDetailsStep({bool isDesktop = false, bool isTablet = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.description,
              title: 'Budget Details',
              subtitle: 'Enter the basic information about your budget',
            ),
            const SizedBox(height: 24),
            
            // Budget name
            _buildInputField(
              controller: _budgetNameController,
              label: 'Budget Name',
              hint: 'Enter a descriptive name for the budget',
              iconData: Icons.title,
              focusNode: _budgetNameFocus,
              nextFocus: _budgetAmountFocus,
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Budget name is required';
                }
                if (value!.trim().length < 3) {
                  return 'Budget name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            // In desktop/tablet, show amount and description side by side
            if (isDesktop || isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Budget amount (left)
                  Expanded(
                    child: _buildInputField(
                      controller: _budgetAmountController,
                      label: 'Budget Amount',
                      hint: 'Enter budget amount',
                      iconData: Icons.attach_money,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      focusNode: _budgetAmountFocus,
                      nextFocus: _budgetDescriptionFocus,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Budget amount is required';
                        }
                        
                        if (_budgetAmount == null) {
                          return 'Please enter a valid number';
                        }
                        
                        if (_budgetAmount! <= 0) {
                          return 'Budget amount must be greater than zero';
                        }
                        
                        if (_budgetAmount! > 10000000) {
                          return 'Budget amount cannot exceed \$10,000,000';
                        }
                        
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // Budget description (right)
                  Expanded(
                    flex: 2,
                    child: _buildInputField(
                      controller: _budgetDescriptionController,
                      label: 'Budget Description',
                      hint: 'Describe the purpose and scope of this budget',
                      iconData: Icons.description,
                      maxLines: 4,
                      focusNode: _budgetDescriptionFocus,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Budget description is required';
                        }
                        if (value!.trim().length < 10) {
                          return 'Please provide a more detailed description (at least 10 characters)';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  // Budget amount
                  _buildInputField(
                    controller: _budgetAmountController,
                    label: 'Budget Amount',
                    hint: 'Enter budget amount',
                    iconData: Icons.attach_money,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    focusNode: _budgetAmountFocus,
                    nextFocus: _budgetDescriptionFocus,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Budget amount is required';
                      }
                      
                      if (_budgetAmount == null) {
                        return 'Please enter a valid number';
                      }
                      
                      if (_budgetAmount! <= 0) {
                        return 'Budget amount must be greater than zero';
                      }
                      
                      if (_budgetAmount! > 10000000) {
                        return 'Budget amount cannot exceed \$10,000,000';
                      }
                      
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Budget description
                  _buildInputField(
                    controller: _budgetDescriptionController,
                    label: 'Budget Description',
                    hint: 'Describe the purpose and scope of this budget',
                    iconData: Icons.description,
                    maxLines: 4,
                    focusNode: _budgetDescriptionFocus,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Budget description is required';
                      }
                      if (value!.trim().length < 10) {
                        return 'Please provide a more detailed description (at least 10 characters)';
                      }
                      return null;
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAuthorizedSpendersStep({bool isDesktop = false, bool isTablet = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.people,
              title: 'Authorized Spenders',
              subtitle: 'Select users who will be authorized to create expenses under this budget',
              trailing: Text(
                '${_selectedSpenderIds.length} selected',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              trailingBackgroundColor: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            
            // Search field
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            
            // Select/deselect all buttons
            if (_availableSpenders.isNotEmpty)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedSpenderIds = _availableSpenders
                            .map((spender) => spender['account_id'] as String)
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Select All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedSpenderIds.clear();
                      });
                    },
                    icon: const Icon(Icons.deselect, size: 18),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            
            // No spenders message
            if (_availableSpenders.isEmpty)
              _buildEmptySpendersMessage(),
            
            // Spenders grid/list
            if (_availableSpenders.isNotEmpty)
              isDesktop
                ? _buildSpendersGrid()
                : _buildSpendersList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSpendersGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredSpenders.length,
      itemBuilder: (context, index) {
        final spender = _filteredSpenders[index];
        final isSelected = _selectedSpenderIds.contains(spender['account_id']);
        
        return _buildSpenderCard(spender, isSelected);
      },
    );
  }
  
  Widget _buildSpendersList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredSpenders.length,
      itemBuilder: (context, index) {
        final spender = _filteredSpenders[index];
        final isSelected = _selectedSpenderIds.contains(spender['account_id']);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildSpenderCard(spender, isSelected),
        );
      },
    );
  }
  
  Widget _buildEmptySpendersMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No authorized spenders available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your administrator to create Authorized Spender accounts.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpenderCard(Map<String, dynamic> spender, bool isSelected) {
    return Material(
      color: isSelected ? AppTheme.primaryLightColor : Colors.grey[50],
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedSpenderIds.remove(spender['account_id']);
            } else {
              _selectedSpenderIds.add(spender['account_id']);
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value ?? false) {
                        _selectedSpenderIds.add(spender['account_id']);
                      } else {
                        _selectedSpenderIds.remove(spender['account_id']);
                      }
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: isSelected 
                    ? AppTheme.primaryColor.withOpacity(0.2) 
                    : Colors.grey[300],
                child: Text(
                  (spender['name'] ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spender['name'] ?? 'Unknown User',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spender['email'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.8) 
                            : AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (spender['contact_number']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        spender['contact_number'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected 
                              ? AppTheme.primaryColor.withOpacity(0.8) 
                              : AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildReviewStep({bool isDesktop = false, bool isTablet = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.fact_check,
              title: 'Review Budget Details',
              subtitle: 'Please review the information below before creating the budget',
            ),
            const SizedBox(height: 24),
            
            // Budget Information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildReviewItem(
                    icon: Icons.title,
                    label: 'Budget Name',
                    value: _budgetNameController.text,
                  ),
                  const Divider(height: 24),
                  
                  _buildReviewItem(
                    icon: Icons.attach_money,
                    label: 'Budget Amount',
                    value: _budgetAmountController.text,
                  ),
                  const Divider(height: 24),
                  
                  _buildReviewItem(
                    icon: Icons.description,
                    label: 'Budget Description',
                    value: _budgetDescriptionController.text,
                    isMultiLine: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Selected Spenders
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Selected Spenders (${_selectedSpenderIds.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Show selected spenders
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSpenders
                        .where((spender) => 
                            _selectedSpenderIds.contains(spender['account_id']))
                        .map((spender) => Chip(
                          avatar: CircleAvatar(
                            backgroundColor: AppTheme.primaryLightColor,
                            child: Text(
                              (spender['name'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          label: Text(spender['name'] ?? 'Unknown User'),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ))
                        .toList(),
                  ),
                  
                  if (_selectedSpenderIds.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              'Please select at least one authorized spender',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Processing information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Steps',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Once created, the budget will be in "Pending for Approval" status. Budget Managers will review and approve it before expenses can be created.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReviewItem({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiLine = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _goToStep(0),
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
  
  Widget _buildInfoPanel({bool isTablet = false, bool isMobile = false}) {
    final contentPadding = isMobile ? 16.0 : 20.0;
    
    Widget content;
    
    switch (_currentStep) {
      case 0:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(
              icon: Icons.title,
              title: 'Budget Name',
              description: 'Choose a clear and descriptive name that identifies the purpose of the budget.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              icon: Icons.attach_money,
              title: 'Budget Amount',
              description: 'The total amount allocated for this budget. Expenses cannot exceed this amount.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              icon: Icons.description,
              title: 'Budget Description',
              description: 'Provide detailed information about the purpose, scope, and intended use of this budget.',
            ),
          ],
        );
        break;
        
      case 1:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(
              icon: Icons.people,
              title: 'Authorized Spenders',
              description: 'Select users who will be able to create and manage expenses for this budget.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              icon: Icons.security,
              title: 'Access Control',
              description: 'Only selected users will be able to create expenses against this budget.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              icon: Icons.search,
              title: 'Search',
              description: 'Use the search field to find specific users by name or email.',
            ),
          ],
        );
        break;
        
      case 2:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(
              icon: Icons.approval,
              title: 'Approval Process',
              description: 'After creation, the budget will require approval from a Budget Manager before it can be used.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              icon: Icons.access_time,
              title: 'Processing Time',
              description: 'Budget approval times may vary. You will be notified when your budget is approved or if revisions are required.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              icon: Icons.edit,
              title: 'Revisions',
              description: 'If your budget is marked for revision, you can update it and resubmit for approval.',
            ),
          ],
        );
        break;
        
      default:
        content = Container();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(contentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Helpful Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            content,
            
            if (isTablet || isMobile) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildBudgetProcessInfo(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildBudgetProcessInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Creation Process',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          _buildProcessStep(
            number: 1,
            description: 'Create budget with details and authorized spenders',
            isComplete: _currentStep > 0,
          ),
          _buildProcessStep(
            number: 2,
            description: 'Budget Manager reviews and approves the budget',
            isComplete: false,
          ),
          _buildProcessStep(
            number: 3,
            description: 'Authorized spenders can create expenses',
            isComplete: false,
            isLast: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildProcessStep({
    required int number,
    required String description,
    required bool isComplete,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circle with number
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete ? Colors.green : Colors.blue[700],
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text(
                    number.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        // Description and connector
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 13,
                ),
              ),
              if (!isLast)
                Container(
                  margin: const EdgeInsets.only(left: 11),
                  width: 2,
                  height: 20,
                  color: isComplete ? Colors.green : Colors.blue[200],
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryLightColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? trailingBackgroundColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryLightColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) 
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: trailingBackgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: trailing,
          ),
      ],
    );
  }
  
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData iconData,
    TextInputType? keyboardType,
    int maxLines = 1,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(iconData),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      focusNode: focusNode,
      validator: validator,
      onFieldSubmitted: nextFocus != null ? (_) {
        FocusScope.of(context).requestFocus(nextFocus);
      } : null,
    );
  }
}

// Custom loading indicator
class LoadingIndicator extends StatelessWidget {
  final String message;
  final bool useCustomIndicator;
  
  const LoadingIndicator({
    Key? key,
    required this.message,
    this.useCustomIndicator = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (useCustomIndicator) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom loading animation
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer circle
                  RotatingCircle(
                    duration: const Duration(seconds: 2),
                    clockwise: true,
                    width: 80,
                    height: 80,
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                  
                  // Middle circle
                  RotatingCircle(
                    duration: const Duration(seconds: 3),
                    clockwise: false,
                    width: 60,
                    height: 60,
                    color: AppTheme.primaryColor.withOpacity(0.5),
                  ),
                  
                  // Inner circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      );
    }
    
    // Simple default loading indicator
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Rotating circle animation for loading indicator
class RotatingCircle extends StatefulWidget {
  final Duration duration;
  final bool clockwise;
  final double width;
  final double height;
  final Color color;

  const RotatingCircle({
    Key? key,
    required this.duration,
    required this.clockwise,
    required this.width,
    required this.height,
    required this.color,
  }) : super(key: key);

  @override
  State<RotatingCircle> createState() => _RotatingCircleState();
}

class _RotatingCircleState extends State<RotatingCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: widget.clockwise 
              ? _controller.value * 2 * math.pi 
              : -_controller.value * 2 * math.pi,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color,
                width: 4,
              ),
            ),
          ),
        );
      },
    );
  }
}

