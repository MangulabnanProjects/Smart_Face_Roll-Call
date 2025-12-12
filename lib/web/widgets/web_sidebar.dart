import 'package:flutter/material.dart';

/// Web sidebar navigation widget
class WebSidebar extends StatelessWidget {
  final String selectedPage;
  final Function(String) onPageSelected;

  const WebSidebar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildMenuItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            value: 'dashboard',
          ),
          _buildMenuItem(
            icon: Icons.calendar_month, // Changed icon
            label: 'Manage', // Renamed from Analytics
            value: 'manage',
          ),
          _buildMenuItem(
            icon: Icons.people,
            label: 'Users',
            value: 'users',
          ),
          _buildMenuItem(
            icon: Icons.camera_alt,
            label: 'Images',
            value: 'images',
          ),
          _buildMenuItem(
            icon: Icons.settings,
            label: 'Settings',
            value: 'settings',
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Model Ready',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isSelected = selectedPage == value;
    return InkWell(
      onTap: () => onPageSelected(value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
