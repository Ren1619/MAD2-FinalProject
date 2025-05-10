import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
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
          // Search and filter row with responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                // Mobile layout - stack vertically
                return Column(
                  children: [
                    const CustomSearchField(hintText: 'Search accounts...'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [_buildFilterButton(context)],
                    ),
                  ],
                );
              } else {
                // Desktop/tablet layout - row layout
                return Row(
                  children: [
                    Expanded(
                      child: const CustomSearchField(
                        hintText: 'Search accounts...',
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildFilterButton(context),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 20),

          // Account cards with responsive list
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - simplified cards
                  return ListView.builder(
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return _buildMobileAccountCard(context, account);
                    },
                  );
                } else if (constraints.maxWidth < 960) {
                  // Tablet layout - more detailed but still compact
                  return ListView.builder(
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return _buildTabletAccountCard(context, account);
                    },
                  );
                } else {
                  // Desktop layout - full details
                  return ListView.builder(
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return _buildDesktopAccountCard(context, account);
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Filter button Widget
  Widget _buildFilterButton(BuildContext context) {
    return PopupMenuButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Important for narrow screens
          children: [
            Icon(Icons.filter_list, color: Colors.blue[700]),
            const SizedBox(width: 4),
            Text('Filter', style: TextStyle(color: Colors.blue[700])),
          ],
        ),
      ),
      itemBuilder:
          (context) => [
            const PopupMenuItem(value: 'all', child: Text('All Accounts')),
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
            const PopupMenuItem(value: 'active', child: Text('Active')),
            const PopupMenuItem(value: 'inactive', child: Text('Inactive')),
          ],
      onSelected: (value) {
        // Filter logic would go here
      },
    );
  }

  // Mobile account card - simplified for small screens
  Widget _buildMobileAccountCard(
    BuildContext context,
    Map<String, String> account,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                const SizedBox(width: 12),
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
                      Text(
                        account['email']!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  itemBuilder: (context) => _buildMenuItems(account),
                  onSelected: (value) {
                    // Handle menu actions
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: RoleBadge(role: account['role']!)),
                const SizedBox(width: 8),
                StatusBadge(status: account['status']!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tablet account card - more details, still compact
  Widget _buildTabletAccountCard(
    BuildContext context,
    Map<String, String> account,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              flex: 2,
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
                  Text(
                    account['email']!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(child: RoleBadge(role: account['role']!)),
                  const SizedBox(width: 12),
                  StatusBadge(status: account['status']!),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    itemBuilder: (context) => _buildMenuItems(account),
                    onSelected: (value) {
                      // Handle menu actions
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Desktop account card - full details
  Widget _buildDesktopAccountCard(
    BuildContext context,
    Map<String, String> account,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              flex: 3,
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: RoleBadge(role: account['role']!),
              ),
            ),
            StatusBadge(status: account['status']!),
            const SizedBox(width: 12),
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
              itemBuilder: (context) => _buildMenuItems(account),
              onSelected: (value) {
                // Handle menu actions
              },
            ),
          ],
        ),
      ),
    );
  }

  // Common menu items for all layouts
  List<PopupMenuItem> _buildMenuItems(Map<String, String> account) {
    return [
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
        value: account['status'] == 'Active' ? 'deactivate' : 'activate',
        child: Row(
          children: [
            Icon(
              account['status'] == 'Active' ? Icons.block : Icons.check_circle,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(account['status'] == 'Active' ? 'Deactivate' : 'Activate'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }
}
