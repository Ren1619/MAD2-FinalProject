import 'package:flutter/material.dart';

class SidebarNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String? userName;
  final String? userEmail;
  final VoidCallback? onLogout;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.userName,
    this.userEmail,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[700]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 30,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  userName ?? 'Admin User',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  userEmail ?? 'admin@example.com',
                  style: TextStyle(color: Colors.blue[100], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.manage_accounts,
            title: 'Accounts',
            index: 0,
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.account_balance_wallet,
            title: 'Budgets',
            index: 1,
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.history,
            title: 'Logs',
            index: 2,
          ),
          const Spacer(),
          Divider(color: Colors.grey[300]),
          _buildDrawerItem(
            context: context,
            icon: Icons.settings,
            title: 'Settings',
            index: -1,
            onTap: () {
              // Handle settings
              Navigator.pop(context);
              // Show settings dialog
              _showSettingsDialog(context);
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.logout,
            title: 'Logout',
            index: -1,
            onTap: () {
              Navigator.pop(context);
              if (onLogout != null) {
                onLogout!();
              } else {
                // Default logout behavior if no callback provided
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logout functionality not implemented'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    VoidCallback? onTap,
  }) {
    final isSelected = index == selectedIndex;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue[700] : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue[700] : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? Colors.blue[50] : null,
      onTap:
          onTap ??
          () {
            onItemSelected(index);
            Navigator.pop(context);
          },
    );
  }

  // Settings dialog
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Settings',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingsSection('Display Settings', [
                    _buildSettingsToggle('Dark Mode', false, (value) {
                      // Handle dark mode toggle
                    }),
                    _buildSettingsToggle('Compact View', false, (value) {
                      // Handle compact view toggle
                    }),
                  ]),
                  const SizedBox(height: 16),
                  _buildSettingsSection('Notifications', [
                    _buildSettingsToggle('Email Notifications', true, (value) {
                      // Handle email notifications toggle
                    }),
                    _buildSettingsToggle('Budget Alerts', true, (value) {
                      // Handle budget alerts toggle
                    }),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    'App Version',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'v1.0.0 (Development Build)',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: Colors.grey[700])),
              ),
            ],
          ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildSettingsToggle(
    String title,
    bool initialValue,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        Switch(
          value: initialValue,
          onChanged: onChanged,
          activeColor: Colors.blue[700],
        ),
      ],
    );
  }
}
