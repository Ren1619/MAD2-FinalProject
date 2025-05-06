import 'package:flutter/material.dart';
import './create_account_dialog.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data for accounts
    final accounts = [
      {
        'name': 'John Doe',
        'email': 'john.doe@example.com',
        'role': 'Budget Manager',
        'status': 'Active',
      },
      {
        'name': 'Jane Smith',
        'email': 'jane.smith@example.com',
        'role': 'Authorized Spender',
        'status': 'Active',
      },
      {
        'name': 'Mike Johnson',
        'email': 'mike@example.com',
        'role': 'Authorized Spender',
        'status': 'Inactive',
      },
      {
        'name': 'Sarah Williams',
        'email': 'sarah@example.com',
        'role': 'Authorized Spender',
        'status': 'Active',
      },
      {
        'name': 'Robert Brown',
        'email': 'robert@example.com',
        'role': 'Financial Planning and Analysis Manager',
        'status': 'Active',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and filter row
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search accounts...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              PopupMenuButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text('Filter', style: TextStyle(color: Colors.blue[700])),
                    ],
                  ),
                ),
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'all',
                        child: Text('All Accounts'),
                      ),
                      const PopupMenuItem(
                        value: 'budget_manager',
                        child: Text('Budget Managers'),
                      ),
                      const PopupMenuItem(
                        value: 'fp_manager',
                        child: Text('Financial Planning Managers'),
                      ),
                      const PopupMenuItem(
                        value: 'spender',
                        child: Text('Authorized Spenders'),
                      ),
                      const PopupMenuItem(
                        value: 'active',
                        child: Text('Active'),
                      ),
                      const PopupMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                onSelected: (value) {
                  // Filter logic would go here
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Account cards
          Expanded(
            child: ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            account['name']!.substring(0, 1),
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                account['email']!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                account['role'] == 'Budget Manager'
                                    ? Colors.blue[50]
                                    : account['role'] ==
                                        'Financial Planning and Analysis Manager'
                                    ? Colors.purple[50]
                                    : Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            account['role']!,
                            style: TextStyle(
                              color:
                                  account['role'] == 'Budget Manager'
                                      ? Colors.blue[700]
                                      : account['role'] ==
                                          'Financial Planning and Analysis Manager'
                                      ? Colors.purple[700]
                                      : Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                account['status'] == 'Active'
                                    ? Colors.green[50]
                                    : Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            account['status']!,
                            style: TextStyle(
                              color:
                                  account['status'] == 'Active'
                                      ? Colors.green[700]
                                      : Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        PopupMenuButton(
                          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                          itemBuilder:
                              (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'reset',
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_reset, size: 18),
                                      SizedBox(width: 8),
                                      Text('Reset Password'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value:
                                      account['status'] == 'Active'
                                          ? 'deactivate'
                                          : 'activate',
                                  child: Row(
                                    children: [
                                      Icon(
                                        account['status'] == 'Active'
                                            ? Icons.block
                                            : Icons.check_circle,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        account['status'] == 'Active'
                                            ? 'Deactivate'
                                            : 'Activate',
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                          onSelected: (value) {
                            // Handle menu actions
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
