import 'package:flutter/material.dart';

class SidebarNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
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
                  'admin@example.com',
                  style: TextStyle(color: Colors.blue[100], fontSize: 14),
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
            index: 2
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
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.logout,
            title: 'Logout',
            index: -1,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/login');
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
      onTap: onTap ?? () {
        onItemSelected(index);
        Navigator.pop(context);
      },
    );
  }
}