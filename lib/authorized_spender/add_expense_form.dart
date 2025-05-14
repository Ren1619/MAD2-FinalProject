import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../theme.dart';

class AddExpenseForm extends StatefulWidget {
  final String budgetId;
  final String budgetName;
  final double budgetAmount;
  final VoidCallback onExpenseAdded;

  const AddExpenseForm({
    super.key,
    required this.budgetId,
    required this.budgetName,
    required this.budgetAmount,
    required this.onExpenseAdded,
  });

  @override
  _AddExpenseFormState createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<AddExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  
  // For receipt handling
  File? _receiptImage;
  bool _hasReceipt = false;

  // Categories for expense
  final List<String> _categories = [
    'Office Supplies',
    'Travel',
    'Meals',
    'Software',
    'Hardware',
    'Services',
    'Marketing',
    'Events',
    'Other'
  ];
  String _selectedCategory = 'Office Supplies';

  // Payment methods
  final List<String> _paymentMethods = [
    'Corporate Card',
    'Personal Card (Reimbursement)',
    'Cash',
    'Invoice',
    'Bank Transfer'
  ];
  String _selectedPaymentMethod = 'Corporate Card';

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Handle image capture
  Future<void> _takePhoto() async {
    // In a real implementation, this would use the camera package
    // For this example, we'll simulate taking a photo
    setState(() {
      _hasReceipt = true;
    });
    
    ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      const SnackBar(content: Text('Receipt photo captured!')),
    );
  }
  
  // Handle image picking from gallery
  Future<void> _pickImage() async {
    // In a real implementation, this would use the image_picker package
    // For this example, we'll simulate picking an image
    setState(() {
      _hasReceipt = true;
    });
    
    ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      const SnackBar(content: Text('Receipt photo selected from gallery!')),
    );
  }

  // Remove selected image
  void _removeImage() {
    setState(() {
      _receiptImage = null;
      _hasReceipt = false;
    });
  }

  // Validate and submit the form
  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse amount
      final double amount = double.parse(_amountController.text);
      
      // Create expense data
      final expenseData = {
        'description': _descriptionController.text,
        'amount': amount,
        'category': _selectedCategory,
        'paymentMethod': _selectedPaymentMethod,
        'budgetId': widget.budgetId,
        'receipt': _hasReceipt ? 1 : 0,
        'date': DateTime.now().toIso8601String(),
        // In a real implementation, we would save the receipt image path
      };

      // Create expense
      bool success = await _databaseService.createExpense(expenseData);

      if (success) {
        widget.onExpenseAdded();
        Navigator.pop(context as BuildContext);
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          const SnackBar(content: Text('Expense added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          const SnackBar(content: Text('Failed to add expense')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense', style: TextStyle(color: AppTheme.primaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primaryColor),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Budget info
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget: ${widget.budgetName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Available Amount: \$${widget.budgetAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Expense fields
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Expense Description',
                  hintText: 'What is this expense for?',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter expense amount',
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  try {
                    double amount = double.parse(value);
                    if (amount <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    if (amount > widget.budgetAmount) {
                      return 'Amount exceeds available budget';
                    }
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Category dropdown
              DropdownButtonFormField(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedCategory,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value.toString();
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Payment method
              DropdownButtonFormField(
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: Icon(Icons.payment),
                ),
                value: _selectedPaymentMethod,
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value.toString();
                  });
                },
              ),
              
              const SizedBox(height: 24),
              
              // Receipt upload section
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt Upload',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (!_hasReceipt)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                              onPressed: _takePhoto,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                              onPressed: _pickImage,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text(
                                'Remove Receipt',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: _removeImage,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}