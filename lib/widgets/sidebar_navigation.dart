import 'package:flutter/material.dart';
import '../theme.dart';

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
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMenuItems(context)),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryDarkColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App title and version
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 30,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Panel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Account Management', // Updated subtitle
                      style: TextStyle(color: Colors.blue[100], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 16),
            // User profile info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.blue[100]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName ?? 'Admin User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userEmail ?? 'admin@example.com',
                          style: TextStyle(
                            color: Colors.blue[100],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
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

  // Optimized menu items list using ListView.builder
  // In lib/widgets/sidebar_navigation.dart
  // Replace the _buildMenuItems method with this updated version:

  Widget _buildMenuItems(BuildContext context) {
    // Updated menu data to match your navigation structure
    final List<Map<String, dynamic>> menuSections = [
      {
        'title': 'Main',
        'items': [
          {'icon': Icons.manage_accounts, 'title': 'Accounts', 'index': 0},
          {
            'icon': Icons.account_balance_wallet,
            'title': 'Budgets',
            'index': 1,
          },
        ],
      },
      {
        'title': 'Monitoring',
        'items': [
          {'icon': Icons.history, 'title': 'Logs', 'index': 2},
          // Removed Analytics since it's not implemented
        ],
      },
      {
        'title': 'Settings',
        'items': [
          {
            'icon': Icons.settings,
            'title': 'Settings',
            'index': -1,
            'action': 'settings',
          },
          {
            'icon': Icons.help_outline,
            'title': 'Help & Support',
            'index': -1,
            'action': 'help',
          },
        ],
      },
    ];

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: menuSections.length * 2 - 1,
      itemBuilder: (context, index) {
        if (index % 2 == 0) {
          final sectionIndex = index ~/ 2;
          return _buildMenuSection(menuSections[sectionIndex]['title']);
        }

        final sectionIndex = index ~/ 2;
        final items = menuSections[sectionIndex]['items'] as List;

        return Column(
          children:
              items.map<Widget>((item) {
                return _buildDrawerItem(
                  context: context,
                  icon: item['icon'],
                  title: item['title'],
                  index: item['index'],
                  badge: item['badge'],
                  onTap:
                      item['action'] == 'settings'
                          ? () {
                            Navigator.pop(context);
                            _showSettingsDialog(context);
                          }
                          : item['action'] == 'help'
                          ? () {
                            Navigator.pop(context);
                            _showHelpDialog(context);
                          }
                          : null,
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildMenuSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    String? badge,
    VoidCallback? onTap,
  }) {
    final isSelected = index == selectedIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryLightColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        trailing:
            badge != null
                ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                : null,
        onTap:
            onTap ??
            () {
              onItemSelected(index);
              Navigator.pop(context);
            },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selected: isSelected,
        dense: true,
        visualDensity: const VisualDensity(vertical: -0.2),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(10),
      color: Colors.red[50],
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.pop(context);
          if (onLogout != null) {
            onLogout!();
          } else {
            // Default logout behavior
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Logout functionality not implemented'),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
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
                color: AppTheme.primaryColor,
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
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'v1.0.0 (Development Build)',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                ),
                child: const Text('Close'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );
  }

  // Help & Support dialog
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.help_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Help & Support',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHelpItem(
                  'Documentation',
                  'View the user manual and documentation',
                  Icons.book,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  'Contact Support',
                  'Reach out to our support team',
                  Icons.support_agent,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  'FAQs',
                  'Frequently asked questions',
                  Icons.question_answer,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  'Report a Bug',
                  'Let us know about any issues',
                  Icons.bug_report,
                  Colors.red,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                ),
                child: const Text('Close'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );
  }

  Widget _buildHelpItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () {},
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
            color: AppTheme.textPrimary,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          Switch(
            value: initialValue,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
