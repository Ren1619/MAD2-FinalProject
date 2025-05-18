import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import '../../utils/image_utils.dart';

class AddExpensePage extends StatefulWidget {
  final Map<String, dynamic> budget;

  const AddExpensePage({super.key, required this.budget});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  File? _receiptImage;
  String? _receiptBase64;
  bool _isLoading = false;
  bool _isProcessingImage = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _isProcessingImage = true);

    try {
      // For web and mobile, we'll simulate image picking
      // In a real app, you'd use image_picker package
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Receipt Image'),
              content: const Text(
                'In a real implementation, this would open the device camera or gallery to select a receipt image.\n\n'
                'For demonstration purposes, we\'ll simulate an image being selected.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _simulateImageSelection();
                  },
                  child: const Text('Simulate Selection'),
                ),
              ],
            ),
      );
    } catch (e) {
      _showErrorSnackBar('Error selecting image: $e');
    } finally {
      setState(() => _isProcessingImage = false);
    }
  }

  void _simulateImageSelection() {
    // Simulate image processing
    setState(() {
      _receiptBase64 = ImageUtils.getPlaceholderImageBase64();
      _isProcessingImage = false;
    });
    _showSuccessSnackBar('Receipt image selected successfully');
  }

  void _removeImage() {
    setState(() {
      _receiptImage = null;
      _receiptBase64 = null;
    });
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );

      final success = await budgetService.createExpense(
        budgetId: widget.budget['budget_id'],
        expenseDescription: _descriptionController.text.trim(),
        expenseAmount: double.parse(_amountController.text),
        receiptBase64: _receiptBase64,
      );

      if (success) {
        _showSuccessSnackBar(
          'Expense created successfully! It is now pending approval.',
        );
        Navigator.pop(context);
      } else {
        _showErrorSnackBar('Failed to create expense. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating expense: $e');
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

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final budgetAmount =
        (widget.budget['budget_amount'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (widget.budget['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final remainingAmount = budgetAmount - totalExpenses;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Add Expense',
        onMenuPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
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
                    colors: [Colors.green, Colors.green.shade700],
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
                        Icons.receipt_long,
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
                            'Add New Expense',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Budget: ${widget.budget['budget_name']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Budget Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryItem(
                              'Total Budget',
                              _formatCurrency(budgetAmount),
                              Icons.account_balance_wallet,
                              AppTheme.primaryColor,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              'Used',
                              _formatCurrency(totalExpenses),
                              Icons.trending_up,
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              'Remaining',
                              _formatCurrency(remainingAmount),
                              Icons.savings,
                              remainingAmount >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      if (remainingAmount < 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Warning: This budget has exceeded its allocated amount.',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Expense Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expense Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Expense Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: AppTheme.inputDecoration(
                          labelText: 'Expense Description',
                          hintText:
                              'Enter a detailed description of the expense',
                          prefixIcon: Icons.description,
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Expense description is required';
                          }
                          if (value!.trim().length < 5) {
                            return 'Please provide a more detailed description (at least 5 characters)';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Expense Amount
                      TextFormField(
                        controller: _amountController,
                        decoration: AppTheme.inputDecoration(
                          labelText: 'Expense Amount',
                          hintText: 'Enter expense amount (e.g., 125.50)',
                          prefixIcon: Icons.attach_money,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Expense amount is required';
                          }

                          final amount = double.tryParse(value!);
                          if (amount == null) {
                            return 'Please enter a valid amount';
                          }

                          if (amount <= 0) {
                            return 'Expense amount must be greater than zero';
                          }

                          if (amount > 1000000) {
                            return 'Expense amount cannot exceed \$1,000,000';
                          }

                          return null;
                        },
                        onChanged: (value) {
                          final amount = double.tryParse(value);
                          if (amount != null && amount > remainingAmount) {
                            // Show warning but don't prevent input
                            setState(() {});
                          }
                        },
                      ),

                      // Amount Warning
                      if (_amountController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final amount =
                                double.tryParse(_amountController.text) ?? 0.0;
                            if (amount > remainingAmount &&
                                remainingAmount > 0) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orange[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange[700],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'This expense exceeds the remaining budget by ${_formatCurrency(amount - remainingAmount)}',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Receipt Upload Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Receipt (Optional)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message:
                                'Adding a receipt helps with verification and approval',
                            child: Icon(
                              Icons.help_outline,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload a photo of your receipt for verification',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_receiptBase64 == null) ...[
                        // Upload Button
                        GestureDetector(
                          onTap: _isProcessingImage ? null : _pickImage,
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color:
                                  _isProcessingImage
                                      ? Colors.grey[100]
                                      : AppTheme.primaryLightColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _isProcessingImage
                                        ? Colors.grey[300]!
                                        : AppTheme.primaryColor.withOpacity(
                                          0.3,
                                        ),
                                style: BorderStyle.solid,
                                width: 2,
                              ),
                            ),
                            child:
                                _isProcessingImage
                                    ? const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 8),
                                          Text('Processing image...'),
                                        ],
                                      ),
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_upload,
                                          size: 48,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to upload receipt',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'JPG, PNG, or PDF • Max 10MB',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ] else ...[
                        // Image Preview
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: Colors.grey[200],
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Receipt Image Attached',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    onPressed: _removeImage,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Remove receipt',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Receipt attached successfully',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
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
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child:
                          _isLoading
                              ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                  Text('Creating Expense...'),
                                ],
                              )
                              : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save),
                                  SizedBox(width: 8),
                                  Text('Submit Expense'),
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
                            'Expense Submission Process',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Once submitted, the expense will be in "Pending" status\n'
                            '• Budget Managers will review and approve the expense\n'
                            '• Approved expenses will be reflected in the budget\n'
                            '• You will be notified of any status changes',
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

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
