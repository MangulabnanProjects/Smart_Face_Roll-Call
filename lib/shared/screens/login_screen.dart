import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

/// Login/Signup screen for admin authentication
/// Works on both mobile and web platforms
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  final _instructorCodeController = TextEditingController();
  
  bool _isLogin = true;
  bool _useInstructorCodeLogin = true; // Default to Instructor ID login
  bool _isLoading = false;
  String? _errorMessage;
  
  // Signup specific state
  XFile? _selectedImage;
  String? _generatedInstructorCode;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _instructorCodeController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _submit() async {
    // If showing code, just switch to login
    if (_generatedInstructorCode != null) {
      setState(() {
        _isLogin = true;
        _useInstructorCodeLogin = true; // Return to ID login
        _generatedInstructorCode = null;
        _selectedImage = null;
        _emailController.clear();
        _passwordController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
        _instructorCodeController.clear();
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        // LOGIN FLOW
        if (_useInstructorCodeLogin) {
           // Login via Instructor Code
           // Login via Instructor Code
           final code = _instructorCodeController.text.trim();
           if (code.isEmpty) throw 'Please enter an Instructor ID';
           
           // Real Firestore Login
           await _authService.signInWithInstructorCode(code);
        } else {
           // Standard Email/Pass Login
           await _authService.signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        }

         // Navigate to main screen on success
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Sign up Flow
        await Future.delayed(const Duration(seconds: 2)); 
        final random = Random();
        final code = '2026-${1000 + random.nextInt(9000)}';
        
        setState(() {
          _generatedInstructorCode = code;
          _isLoading = false;
        });
        
        // Register Auth Data
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          instructorCode: code,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: _generatedInstructorCode != null 
                  ? _buildSuccessView() 
                  : _buildFormView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
        const SizedBox(height: 24),
        Text(
          'Registration Successful!',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Your Instructor Code is:',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        SelectableText(
          _generatedInstructorCode!,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please save this code for your records.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          child: const Text('Go to Login'),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            _isLogin 
               ? (_useInstructorCodeLogin ? 'Instructor Login' : 'Admin Login') 
               : 'Instructor Sign Up',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // SIGNUP or LOGIN FIELDS
          if (!_isLogin) ...[
             // SIGNUP FIELDS (Photo, Name, Email, Password)
             Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _selectedImage != null ? NetworkImage(_selectedImage!.path) : null,
                    child: _selectedImage == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: IconButton(
                      icon: const CircleAvatar(
                        radius: 16, backgroundColor: Colors.blue,
                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // First Name Field
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            // Last Name Field
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
             TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              obscureText: true,
              validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
            ),
          ] else ...[
            // LOGIN FIELDS
            if (_useInstructorCodeLogin) ...[
              TextFormField(
                controller: _instructorCodeController,
                decoration: const InputDecoration(
                  labelText: 'Instructor ID',
                  hintText: 'e.g. 2026-XXXX',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => v!.isEmpty ? 'Please enter code' : null,
              ),
            ] else ...[
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                obscureText: true,
                validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
              ),
            ],
          ],

          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
            ),
            const SizedBox(height: 16),
          ],

          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isLogin ? 'Login' : 'Sign Up'),
          ),
          const SizedBox(height: 16),

          // Toggles
          if (_isLogin)
             TextButton(
              onPressed: () => setState(() => _useInstructorCodeLogin = !_useInstructorCodeLogin),
              child: Text(_useInstructorCodeLogin ? 'Use Email & Password' : 'Use Instructor ID'),
            ),

          TextButton(
            onPressed: () {
              setState(() {
                _isLogin = !_isLogin;
                _errorMessage = null;
                _selectedImage = null;
                _generatedInstructorCode = null;
              });
            },
            child: Text(
              _isLogin
                  ? 'Access for Instructors? Create Account'
                  : 'Already have an account? Log in',
            ),
          ),
        ],
      ),
    );
  }
}
