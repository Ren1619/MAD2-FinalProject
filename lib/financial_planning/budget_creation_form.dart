import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/uuid_generator.dart';

class BudgetCreationForm extends StatefulWidget {
  final VoidCallback onBudgetCreated;
  final VoidCallback onCancel;
  final Map<String, dynamic>? existingBudget; // Optional parameter for editing

  const BudgetCreationForm({
    super.key,
    required this.onBudgetCreated,
    required this.onCancel,
    this.existingBudget,
  });

  @override
  _BudgetCreationFormState createState() => _BudgetCreationFormState();
}

class _BudgetCreationFormState extends State<BudgetCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetPurposeController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  int _currentStep = 0;

  // Selected values
  String _selectedDepartment = 'Marketing';
  String _selectedQuarter = 'Q1 2025';
  String _selectedCategory = 'Operational';
  final List<Map<String, dynamic>> _selectedSpenders = [];

  // Form data
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  // Lists for dropdown fields
  final List<String> _departments = [
    'Marketing',
    'Sales',
    'Research & Development',
    'Engineering',
    'Operations',
    'Human Resources',
    'Finance',
    'IT',
    'Customer Support',
    'Administration',
  ];

  final List<String> _fiscalQuarters = [
    'Q1 2025',
    'Q2 2025',
    'Q3 2025',
    'Q4 2025',
    'Q1 2026',
  ];

  final List<String> _budgetCategories = [
    'Operational',
    'Capital Expenditure',
    'Project-Based',
    'Strategic Initiative',
    'Research & Development',
    'Marketing Campaign',
    'Training & Development',
    'Technology Investment',
    'Facilities',
    'Other',
  ];

  // List of all eligible authorized spenders
  List<Map<String, dynamic>> _availableSpenders = [];
  bool _isLoadingSpenders = false;

  @override
  void initState() {
    super.initState();
    _loadAuthorizedSpenders();

    // If existing budget is provided, populate the form fields
    if (widget.existingBudget != null) {
      _nameController.text = widget.existingBudget!['name'] ?? '';
      _budgetPurposeController.text = widget.existingBudget!['purpose'] ?? '';
      _amountController.text =
          (widget.existingBudget!['budget'] ?? 0.0).toString();
      _descriptionController.text = widget.existingBudget!['description'] ?? '';

      // Extract department from budget name if possible
      final name = widget.existingBudget!['name'] ?? '';
      for (final department in _departments) {
        if (name.contains(department)) {
          _selectedDepartment = department;
          break;
        }
      }

      // Extract quarter from budget name if possible
      for (final quarter in _fiscalQuarters) {
        if (name.contains(quarter)) {
          _selectedQuarter = quarter;
          break;
        }
      }

      // Extract category if available
      _selectedCategory = widget.existingBudget!['category'] ?? 'Operational';

      // Load authorized spenders if available
      final spenders = widget.existingBudget!['authorizedSpenders'];
      if (spenders != null && spenders is List) {
        for (var spender in spenders) {
          if (spender is Map<String, dynamic>) {
            _selectedSpenders.add(spender);
          }
        }
      }
    }
  }

  Future<void> _loadAuthorizedSpenders() async {
    setState(() {
      _isLoadingSpenders = true;
    });

    try {
      // In a real app, you would filter users by the role "Authorized Spender"
      final users = await _databaseService.fetchUsers();

      // Filter users with role "Authorized Spender"
      _availableSpenders =
          users
              .where((user) => user['role'] == AuthService.ROLE_SPENDER)
              .toList();
    } catch (e) {
      print('Error loading authorized spenders: $e');
    } finally {
      setState(() {
        _isLoadingSpenders = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _budgetPurposeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Validate the budget amount
  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a budget amount';
    }

    try {
      final amount = double.parse(value);
      if (amount <= 0) {
        return 'Amount must be greater than zero';
      }
    } catch (e) {
      return 'Please enter a valid number';
    }

    return null;
  }

  // Handle form submission
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final double budgetAmount = double.parse(_amountController.text);
      final String budgetName = _nameController.text;

      // Prepare the list of authorized spenders (just keep IDs)
      final List<String> spenderIds =
          _selectedSpenders.map((spender) => spender['id'] as String).toList();

      // If editing an existing budget
      if (widget.existingBudget != null) {
        final updatedBudget = {
          'id': widget.existingBudget!['id'],
          'name': budgetName,
          'purpose': _budgetPurposeController.text,
          'department': _selectedDepartment,
          'quarter': _selectedQuarter,
          'category': _selectedCategory,
          'budget': budgetAmount,
          'description': _descriptionController.text,
          'authorizedSpenders': spenderIds,
          // Status and other fields remain unchanged
        };

        // Update the budget
        await _databaseService.updateBudget(updatedBudget);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget updated successfully')),
        );
      } else {
        // Create a new budget
        final budget = {
          'name': budgetName,
          'purpose': _budgetPurposeController.text,
          'department': _selectedDepartment,
          'quarter': _selectedQuarter,
          'category': _selectedCategory,
          'budget': budgetAmount,
          'description': _descriptionController.text,
          'authorizedSpenders': spenderIds,
        };

        await _databaseService.createBudget(budget);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget created successfully')),
        );
      }

      widget.onBudgetCreated();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Move to the next step in the stepper
  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep += 1;
      });
    } else {
      _submitForm();
    }
  }

  // Move to the previous step in the stepper
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    } else {
      widget.onCancel();
    }
  }

  // Add a new authorized spender
  void _addSpender(Map<String, dynamic> spender) {
    if (_selectedSpenders.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 authorized spenders allowed')),
      );
      return;
    }

    // Check if spender is already added
    if (_selectedSpenders.any((s) => s['id'] == spender['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This spender is already added')),
      );
      return;
    }

    setState(() {
      _selectedSpenders.add(spender);
    });
  }

  // Remove an authorized spender
  void _removeSpender(String spenderId) {
    setState(() {
      _selectedSpenders.removeWhere((s) => s['id'] == spenderId);
    });
  }

  // Show dialog to select authorized spenders
  void _showSpenderSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Authorized Spender'),
          content:
              _isLoadingSpenders
                  ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                  : SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: ListView.builder(
                      itemCount: _availableSpenders.length,
                      itemBuilder: (context, index) {
                        final spender = _availableSpenders[index];
                        final bool isSelected = _selectedSpenders.any(
                          (s) => s['id'] == spender['id'],
                        );

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              spender['name'][0],
                              style: TextStyle(color: Colors.blue[800]),
                            ),
                          ),
                          title: Text(spender['name']),
                          subtitle: Text(spender['email']),
                          trailing:
                              isSelected
                                  ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green[700],
                                  )
                                  : null,
                          enabled: !isSelected,
                          onTap:
                              isSelected
                                  ? null
                                  : () {
                                    Navigator.pop(context);
                                    _addSpender(spender);
                                  },
                        );
                      },
                    ),
                  ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.existingBudget != null
              ? 'Edit Budget Request'
              : 'Create Budget Request',
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[800]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onCancel,
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: _nextStep,
          onStepCancel: _previousStep,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child:
                        _isLoading && _currentStep == 2
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(_currentStep == 2 ? 'Submit' : 'Next'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Basic Info'),
              content: _buildBasicInfoStep(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Details'),
              content: _buildDetailsStep(),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Authorized Spenders'),
              content: _buildSpendersStep(),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Budget Name
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Budget Name',
            hintText: 'Enter a descriptive name for this budget',
            prefixIcon: Icon(Icons.title),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a budget name';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Budget Purpose
        TextFormField(
          controller: _budgetPurposeController,
          decoration: const InputDecoration(
            labelText: 'Budget Purpose',
            hintText: 'What is this budget for?',
            prefixIcon: Icon(Icons.assignment),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the budget purpose';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Department Dropdown
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Department',
            prefixIcon: Icon(Icons.business),
          ),
          value: _selectedDepartment,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedDepartment = value;
              });
            }
          },
          items:
              _departments.map((department) {
                return DropdownMenuItem<String>(
                  value: department,
                  child: Text(department),
                );
              }).toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a department';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Budget Amount
        TextFormField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: 'Budget Amount',
            hintText: 'Enter total budget amount',
            prefixIcon: Icon(Icons.attach_money),
            prefixText: '\$ ',
          ),
          keyboardType: TextInputType.number,
          validator: _validateAmount,
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fiscal Quarter
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Fiscal Quarter',
            prefixIcon: Icon(Icons.calendar_today),
          ),
          value: _selectedQuarter,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedQuarter = value;
              });
            }
          },
          items:
              _fiscalQuarters.map((quarter) {
                return DropdownMenuItem<String>(
                  value: quarter,
                  child: Text(quarter),
                );
              }).toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a fiscal quarter';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Budget Category
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Budget Category',
            prefixIcon: Icon(Icons.category),
          ),
          value: _selectedCategory,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
              });
            }
          },
          items:
              _budgetCategories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a budget category';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Detailed Description',
            hintText:
                'Provide a detailed description including goals and justification',
            alignLabelWithHint: true,
          ),
          maxLines: 5,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please provide a description';
            }
            if (value.length < 20) {
              return 'Description should be at least 20 characters';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Tips for a good budget description
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tips for a Good Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• Clearly state the purpose and goals of this budget\n'
                '• Include specific deliverables or outcomes\n'
                '• Explain why this budget is necessary\n'
                '• Mention any relevant timeframes or deadlines\n'
                '• Include any important assumptions or constraints',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpendersStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instruction text
        Text(
          'Add up to 3 authorized spenders for this budget',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),

        const SizedBox(height: 16),

        // Add spender button
        if (_selectedSpenders.length < 3)
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Add Authorized Spender'),
            onPressed: _showSpenderSelectionDialog,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
          ),

        const SizedBox(height: 20),

        // Selected spenders list
        if (_selectedSpenders.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No authorized spenders added yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add up to 3 spenders who can use this budget',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedSpenders.length,
            itemBuilder: (context, index) {
              final spender = _selectedSpenders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      spender['name'][0],
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                  ),
                  title: Text(spender['name']),
                  subtitle: Text(spender['email']),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => _removeSpender(spender['id']),
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 20),

        // Information about authorized spenders
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'About Authorized Spenders',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Authorized spenders can submit expenses against this budget. '
                'They will be notified when this budget is approved. '
                'A budget can have up to 3 authorized spenders.',
                style: TextStyle(color: Colors.amber[800]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
