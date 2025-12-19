import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/services/api_service.dart';

/// Profile/Settings screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Sign out from Firebase
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          // Navigate to login screen and remove all previous routes
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/student-login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // Profile header with student data
          StreamBuilder<DocumentSnapshot>(
            stream: currentUser != null
                ? FirebaseFirestore.instance
                    .collection('Students')
                    .doc(currentUser.uid)
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              String fullName = 'Student';
              String subtitle = 'Loading...';

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                fullName = data['fullName'] ?? 'Student';
                final studentNumber = data['studentNumber'] ?? '';
                final email = data['email'] ?? '';
                subtitle = studentNumber.isNotEmpty ? studentNumber : email;
              } else if (!snapshot.hasData) {
                subtitle = 'Loading...';
              } else {
                subtitle = currentUser?.email ?? 'No email';
              }

              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fullName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const Divider(),
          
          // Menu items
          _buildMenuItem(Icons.cloud_upload, 'Server Settings', 'Configure IP', () async {
             final currentUrl = await ApiService.getBaseUrl();
             final controller = TextEditingController(text: currentUrl);
             if (mounted) {
               showDialog(
                 context: context,
                 builder: (context) => AlertDialog(
                   title: const Text('Server Connection'),
                   content: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Text('Enter the IP address of your Python server (e.g. 192.168.1.5:5000). Use 10.0.2.2:5000 for Emulator.'),
                       const SizedBox(height: 10),
                       TextField(
                         controller: controller,
                         decoration: const InputDecoration(
                           hintText: 'e.g. http://192.168.1.5:5000',
                           border: OutlineInputBorder(),
                         ),
                       ),
                     ],
                   ),
                   actions: [
                     TextButton(
                       onPressed: () => Navigator.pop(context),
                       child: const Text('Cancel'),
                     ),
                     TextButton(
                       onPressed: () async {
                         await ApiService.setBaseUrl(controller.text);
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Server URL updated')),
                         );
                       },
                       child: const Text('Save'),
                     ),
                   ],
                 ),
               );
             }
          }),
          _buildMenuItem(Icons.face, 'AI Model Status', 'bestyolov11.pt Integrated', () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('AI Model Information'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Model:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text('YOLOv11 - Best Face Recognition Model'),
                      const Text('File: bestyolov11.pt'),
                      const SizedBox(height: 16),
                      const Text(
                        'Trained Students:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      _buildStudentChip('gab'),
                      _buildStudentChip('rose'),
                      _buildStudentChip('lat'),
                      _buildStudentChip('ky'),
                      _buildStudentChip('ally'),
                      _buildStudentChip('khat'),
                      _buildStudentChip('nix'),
                      _buildStudentChip('ivan'),
                      _buildStudentChip('ken'),
                      _buildStudentChip('riana'),
                      _buildStudentChip('jc'),
                      _buildStudentChip('mc'),
                      const SizedBox(height: 16),
                      const Text(
                        'Status:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          const Text('Model Loaded and Ready'),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }),
          _buildMenuItem(Icons.info_outline, 'About', 'Version 1.0.0', () {}),
          
          const Divider(),

          _buildMenuItem(Icons.logout, 'Logout', '', _handleLogout, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildStudentChip(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
