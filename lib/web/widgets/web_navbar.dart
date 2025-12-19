import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Web navbar widget for the dashboard
class WebNavbar extends StatefulWidget {
  const WebNavbar({super.key});

  @override
  State<WebNavbar> createState() => _WebNavbarState();
}

class _WebNavbarState extends State<WebNavbar> {
  String _displayName = 'Instructor';

  @override
  void initState() {
    super.initState();
    _loadInstructorName();
  }

  Future<void> _loadInstructorName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Instructor_Information')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final lastName = data?['Last_Name'] ?? '';
        final firstName = data?['First_Name'] ?? '';
        
        if (lastName.isNotEmpty && firstName.isNotEmpty) {
          setState(() {
            _displayName = '$lastName, $firstName';
          });
        } else if (data?['Full_Name'] != null) {
          // Fallback for old data without separate fields
          setState(() {
            _displayName = data!['Full_Name'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading instructor name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo/Branding
          const Icon(Icons.analytics, size: 32, color: Colors.blue),
          const SizedBox(width: 12),
          Text(
            'Attendance Dashboard',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),

          // User menu
          PopupMenuButton<String>(
            icon: Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 8),
                Text(
                   _displayName,
                   style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.of(context).pushReplacementNamed('/login');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$value clicked')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
