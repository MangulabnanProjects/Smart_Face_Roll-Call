import 'dart:math';
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _generatedStudentNumber; // Store generated student number to show after signup
  
  // New: Class and Instructor selection
  String? _selectedClassId;
  List<String> _selectedInstructorIds = []; // Changed to list for multiple selection
  
  // New: Birthday
  DateTime? _selectedBirthday;
  
  // New: Student Identity Selection
  String? _selectedIdentity;
  final List<String> _studentIdentities = [
    'Gab',
    'Rose',
    'Lat',
    'Ky',
    'Ally',
    'Khat',
    'Nix',
    'Ivan',
    'Ken',
    'Riana',
    'JC',
    'MC',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Generate a unique student number in format 2026-XXXX
  /// Ensures no collision with existing students or instructors
  Future<String> _generateUniqueStudentNumber() async {
    final random = Random();
    
    while (true) {
      final code = '2026-${1000 + random.nextInt(9000)}';
      
      // Check if code exists in Students collection
      final studentQuery = await FirebaseFirestore.instance
          .collection('Students')
          .where('studentNumber', isEqualTo: code)
          .limit(1)
          .get();
      
      if (studentQuery.docs.isNotEmpty) continue;
      
      // Check if code exists in Instructor_Information collection
      final instructorQuery = await FirebaseFirestore.instance
          .collection('Instructor_Information')
          .where('Instructor_ID', isEqualTo: code)
          .limit(1)
          .get();
      
      if (instructorQuery.docs.isNotEmpty) continue;
      
      // Code is unique!
      return code;
    }
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
    
    // Check identity is selected
    if (_selectedIdentity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your identity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate unique student number
      final studentNumber = await _generateUniqueStudentNumber();
      
      // Create Firebase Auth user
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Create student document in Firestore
      final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      await FirebaseFirestore.instance
          .collection('Students')
          .doc(credential.user!.uid)
          .set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'fullName': fullName,
        'studentNumber': studentNumber,
        'email': _emailController.text.trim(),
        'password': _passwordController.text, // Store password for Student ID login
        'phoneNumber': _phoneController.text.trim(),
        'birthday': _selectedBirthday != null ? Timestamp.fromDate(_selectedBirthday!) : null,
        'identity': _selectedIdentity, // Store selected identity for attendance
        'classId': _selectedClassId ?? '', // Assign to selected class
        'instructorIds': _selectedInstructorIds, // Array of instructor IDs
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign out the user so they must login with student number
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        setState(() {
          _generatedStudentNumber = studentNumber;
        });
        
        // Show popup dialog with student ID
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
                  const SizedBox(width: 12),
                  const Text(
                    'Account Created!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your Student ID has been generated:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200, width: 2),
                    ),
                    child: SelectableText(
                      studentNumber,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please remember this ID to login',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'OK, Got It!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        
        // Redirect to login page
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
                              // First Name
                              TextFormField(
                                controller: _firstNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'First Name',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your first name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Last Name
                              TextFormField(
                                controller: _lastNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'Last Name',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your last name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Removed Student Number field - now auto-generated

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
                                maxLength: 11,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: '09123456789',
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  counterText: '', // Hide character counter
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  if (value.length != 11) {
                                    return 'Phone number must be exactly 11 digits';
                                  }
                                  if (!value.startsWith('09')) {
                                    return 'Phone number must start with 09';
                                  }
                                  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                    return 'Phone number must contain only digits';
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

                              // Student Identity Selection
                              DropdownButtonFormField<String>(
                                value: _selectedIdentity,
                                decoration: InputDecoration(
                                  labelText: 'Select Your Identity',
                                  prefixIcon: const Icon(Icons.person_pin),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                hint: const Text('Choose your identity'),
                                items: _studentIdentities.map((identity) {
                                  return DropdownMenuItem<String>(
                                    value: identity,
                                    child: Text(identity),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => _selectedIdentity = value);
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select your identity';
                                  }
                                  return null;
                                },
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
