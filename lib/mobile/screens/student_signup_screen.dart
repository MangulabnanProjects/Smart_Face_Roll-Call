import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MobileStudentSignupScreen extends StatefulWidget {
  const MobileStudentSignupScreen({super.key});

  @override
  State<MobileStudentSignupScreen> createState() => _MobileStudentSignupScreenState();
}

class _MobileStudentSignupScreenState extends State<MobileStudentSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _studentNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // New: Class and Instructor selection
  String? _selectedClassId;
  List<String> _selectedInstructorIds = []; // Changed to list for multiple selection
  
  // New: Birthday
  DateTime? _selectedBirthday;

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check birthday is selected
    if (_selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your birthday'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Check at least one instructor is selected
    if (_selectedInstructorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one instructor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create Firebase Auth user
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Create student document in Firestore
      await FirebaseFirestore.instance
          .collection('Students')
          .doc(credential.user!.uid)
          .set({
        'fullName': _fullNameController.text.trim(),
        'studentNumber': _studentNumberController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'birthday': _selectedBirthday != null ? Timestamp.fromDate(_selectedBirthday!) : null,
        'classId': _selectedClassId ?? '', // Assign to selected class
        'instructorIds': _selectedInstructorIds, // Array of instructor IDs
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign out the user so they must login with student number
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please login with your student number.'),
            backgroundColor: Colors.green,
          ),
        );
        // Redirect to login page instead of home
        Navigator.pushReplacementNamed(context, '/student-login');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      if (e.code == 'weak-password') {
        message = 'The password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade600,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Header
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign up to get started',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Signup form card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Full Name
                              TextFormField(
                                controller: _fullNameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Student Number
                              TextFormField(
                                controller: _studentNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Student Number',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your student number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Phone Number
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Birthday
                              InkWell(
                                onTap: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime(2000),
                                    firstDate: DateTime(1950),
                                    lastDate: DateTime.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: Colors.blue.shade600,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedBirthday = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Birthday',
                                    prefixIcon: const Icon(Icons.cake_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    errorText: _selectedBirthday == null ? 'Please select your birthday' : null,
                                  ),
                                  child: Text(
                                    _selectedBirthday != null
                                        ? DateFormat('MMMM d, y').format(_selectedBirthday!)
                                        : 'Select your birthday',
                                    style: TextStyle(
                                      color: _selectedBirthday != null ? Colors.black87 : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Multi-Instructor Selection
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('Instructor_Information')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const CircularProgressIndicator();
                                  }

                                  final instructors = snapshot.data!.docs;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12, bottom: 8),
                                        child: Text(
                                          'Select Instructor(s) *',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(12),
                                          color: Colors.grey.shade50,
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: instructors.map((doc) {
                                            final data = doc.data() as Map<String, dynamic>;
                                            String name = data['Full_Name'] ?? 
                                                         data['fullName'] ?? 
                                                         '${data['First_Name'] ?? ''} ${data['Last_Name'] ?? ''}'.trim();
                                            if (name.isEmpty) name = 'Unknown Instructor';
                                            
                                            final isSelected = _selectedInstructorIds.contains(doc.id);
                                            
                                            return FilterChip(
                                              label: Text(name),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setState(() {
                                                  if (selected) {
                                                    _selectedInstructorIds.add(doc.id);
                                                  } else {
                                                    _selectedInstructorIds.remove(doc.id);
                                                    _selectedClassId = null; // Reset class when instructors change
                                                  }
                                                });
                                              },
                                              selectedColor: Colors.blue.shade100,
                                              checkmarkColor: Colors.blue.shade700,
                                              labelStyle: TextStyle(
                                                color: isSelected ? Colors.blue.shade700 : Colors.black87,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      if (_selectedInstructorIds.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 12, top: 8),
                                          child: Text(
                                            'Please select at least one instructor',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Class Selection (grouped by class name with instructor names)
                              StreamBuilder<QuerySnapshot>(
                                stream: _selectedInstructorIds.isNotEmpty
                                    ? FirebaseFirestore.instance
                                        .collection('ClassGroups')
                                        .snapshots()
                                    : null,
                                builder: (context, snapshot) {
                                  if (_selectedInstructorIds.isEmpty) {
                                    return DropdownButtonFormField<String>(
                                      value: null,
                                      decoration: InputDecoration(
                                        labelText: 'Select Class',
                                        prefixIcon: const Icon(Icons.class_),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      items: const [],
                                      onChanged: null,
                                      hint: const Text('Select instructor(s) first'),
                                    );
                                  }

                                  if (!snapshot.hasData) {
                                    return const LinearProgressIndicator();
                                  }

                                  // Filter classes by selected instructors and group by class name
                                  final allClasses = snapshot.data!.docs;
                                  final Map<String, List<Map<String, dynamic>>> groupedClasses = {};
                                  
                                  for (var doc in allClasses) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final instructorId = data['instructorId'];
                                    
                                    if (_selectedInstructorIds.contains(instructorId)) {
                                      final className = data['name'] ?? 'Unknown Class';
                                      
                                      if (!groupedClasses.containsKey(className)) {
                                        groupedClasses[className] = [];
                                      }
                                      
                                      groupedClasses[className]!.add({
                                        'classId': doc.id,
                                        'instructorId': instructorId,
                                        'data': data,
                                      });
                                    }
                                  }

                                  if (groupedClasses.isEmpty) {
                                    return DropdownButtonFormField<String>(
                                      value: null,
                                      decoration: InputDecoration(
                                        labelText: 'Select Class',
                                        prefixIcon: const Icon(Icons.class_),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      items: const [],
                                      onChanged: null,
                                      hint: const Text('No classes available'),
                                    );
                                  }

                                  // Build dropdown items with instructor names
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('Instructor_Information')
                                        .snapshots(),
                                    builder: (context, instructorSnapshot) {
                                      final instructorMap = <String, String>{};
                                      if (instructorSnapshot.hasData) {
                                        for (var doc in instructorSnapshot.data!.docs) {
                                          final data = doc.data() as Map<String, dynamic>;
                                          String name = data['Full_Name'] ?? 
                                                       data['fullName'] ?? 
                                                       '${data['First_Name'] ?? ''} ${data['Last_Name'] ?? ''}'.trim();
                                          if (name.isEmpty) name = 'Unknown';
                                          instructorMap[doc.id] = name;
                                        }
                                      }

                                      return DropdownButtonFormField<String>(
                                        value: _selectedClassId,
                                        decoration: InputDecoration(
                                          labelText: 'Select Class',
                                          prefixIcon: const Icon(Icons.class_),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        items: groupedClasses.entries.map((entry) {
                                          final className = entry.key;
                                          final classes = entry.value;
                                          
                                          // Get instructor names for this class
                                          final instructorNames = classes
                                              .map((c) => instructorMap[c['instructorId']] ?? 'Unknown')
                                              .toSet()
                                              .join(', ');
                                          
                                          // Use first class ID as the value
                                          final classId = classes.first['classId'];
                                          
                                          return DropdownMenuItem<String>(
                                            value: classId,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  className,
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                                ),
                                                if (instructorNames.isNotEmpty)
                                                  Text(
                                                    instructorNames,
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() => _selectedClassId = value);
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please select a class';
                                          }
                                          return null;
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Signup button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign Up',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
