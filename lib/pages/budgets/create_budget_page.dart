import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';

class CreateBudgetPage extends StatefulWidget {
  const CreateBudgetPage({super.key});

  @override
  State<CreateBudgetPage> createState() => _CreateBudgetPageState();
}

class _CreateBudgetPageState extends State<CreateBudgetPage> {
  final _formKey = GlobalKey<FormState>();
  final _budgetNameController = TextEditingController();
  final _budgetAmountController = TextEditingController();
  final _budgetDescriptionController = TextEditingController();

  List<Map<String, dynamic>> _availableSpenders = [];
  List<String> _selectedSpenderIds = [];
  bool _isLoading = false;
  bool _isLoadingSpenders = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableSpenders();
  }

  @override
  void dispose() {
    _budgetNameController.dispose();
    _budgetAmountController.dispose();
    _budgetDescriptionController.dispose();
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
        _isLoadingSpenders = false;
      });
    } catch (e) {
      setState(() => _isLoadingSpenders = false);
      _showErrorSnackBar('Error loading available spenders: $e');
    }
  }

  Future<void> _createBudget() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSpenderIds.isEmpty) {
      _showErrorSnackBar('Please select at least one authorized spender');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );

      final success = await budgetService.createBudget(
        budgetName: _budgetNameController.text.trim(),
        budgetAmount: double.parse(_budgetAmountController.text),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Create New Budget',
        onMenuPressed: () => Navigator.pop(context),
      ),
      body:
          _isLoadingSpenders
              ? const LoadingIndicator(
                message: 'Loading authorized spenders...',
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryDarkColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Create Budget',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Define budget parameters and assign authorized spenders',
                                    style: TextStyle(
                                      color: AppTheme.primaryLightColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Budget Information Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Budget Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Budget Name
                              TextFormField(
                                controller: _budgetNameController,
                                decoration: AppTheme.inputDecoration(
                                  labelText: 'Budget Name',
                                  hintText:
                                      'Enter a descriptive name for the budget',
                                  prefixIcon: Icons.title,
                                ),
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

                              // Budget Amount
                              TextFormField(
                                controller: _budgetAmountController,
                                decoration: AppTheme.inputDecoration(
                                  labelText: 'Budget Amount',
                                  hintText:
                                      'Enter budget amount (e.g., 10000.00)',
                                  prefixIcon: Icons.attach_money,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (value) {
                                  if (value?.trim().isEmpty ?? true) {
                                    return 'Budget amount is required';
                                  }

                                  final amount = double.tryParse(value!);
                                  if (amount == null) {
                                    return 'Please enter a valid number';
                                  }

                                  if (amount <= 0) {
                                    return 'Budget amount must be greater than zero';
                                  }

                                  if (amount > 10000000) {
                                    return 'Budget amount cannot exceed \$10,000,000';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Budget Description
                              TextFormField(
                                controller: _budgetDescriptionController,
                                decoration: AppTheme.inputDecoration(
                                  labelText: 'Budget Description',
                                  hintText:
                                      'Describe the purpose and scope of this budget',
                                  prefixIcon: Icons.description,
                                ),
                                maxLines: 4,
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
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Authorized Spenders Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Authorized Spenders',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_selectedSpenderIds.length} selected',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Select users who will be authorized to create expenses under this budget',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (_availableSpenders.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
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
                                )
                              else
                                Column(
                                  children:
                                      _availableSpenders.map((spender) {
                                        final isSelected = _selectedSpenderIds
                                            .contains(spender['account_id']);

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? AppTheme.primaryLightColor
                                                    : Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isSelected
                                                      ? AppTheme.primaryColor
                                                      : Colors.grey[200]!,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: CheckboxListTile(
                                            value: isSelected,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value ?? false) {
                                                  _selectedSpenderIds.add(
                                                    spender['account_id'],
                                                  );
                                                } else {
                                                  _selectedSpenderIds.remove(
                                                    spender['account_id'],
                                                  );
                                                }
                                              });
                                            },
                                            title: Text(
                                              spender['name'] ?? 'Unknown User',
                                              style: TextStyle(
                                                fontWeight:
                                                    isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                color:
                                                    isSelected
                                                        ? AppTheme.primaryColor
                                                        : AppTheme.textPrimary,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  spender['email'] ?? '',
                                                  style: TextStyle(
                                                    color:
                                                        isSelected
                                                            ? AppTheme
                                                                .primaryColor
                                                                .withOpacity(
                                                                  0.8,
                                                                )
                                                            : AppTheme
                                                                .textSecondary,
                                                  ),
                                                ),
                                                if (spender['contact_number']
                                                        ?.isNotEmpty ??
                                                    false)
                                                  Text(
                                                    spender['contact_number'],
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          isSelected
                                                              ? AppTheme
                                                                  .primaryColor
                                                                  .withOpacity(
                                                                    0.8,
                                                                  )
                                                              : AppTheme
                                                                  .textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            activeColor: AppTheme.primaryColor,
                                            dense: true,
                                          ),
                                        );
                                      }).toList(),
                                ),

                              if (_availableSpenders.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedSpenderIds =
                                              _availableSpenders
                                                  .map(
                                                    (spender) =>
                                                        spender['account_id']
                                                            as String,
                                                  )
                                                  .toList();
                                        });
                                      },
                                      child: const Text('Select All'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedSpenderIds.clear();
                                        });
                                      },
                                      child: const Text('Clear All'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(color: AppTheme.primaryColor),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _createBudget,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Creating Budget...'),
                                        ],
                                      )
                                      : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.save),
                                          SizedBox(width: 8),
                                          Text('Create Budget'),
                                        ],
                                      ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Info Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Budget Creation Process',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '• Once created, the budget will be in "Pending for Approval" status\n'
                                    '• Budget Managers will review and approve the budget\n'
                                    '• Authorized spenders can only create expenses after approval\n'
                                    '• You can view and track your budget status in the budgets section',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[600],
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
              ),
    );
  }
}
