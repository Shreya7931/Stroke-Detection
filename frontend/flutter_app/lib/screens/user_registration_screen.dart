import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_app/screens/emergency_contacts_screen.dart';


class UserRegistrationScreen extends StatefulWidget {
  @override
  _UserRegistrationScreenState createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  File? _imageFile;
  final picker = ImagePicker();
  List<String> _emergencyContacts = [];

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Registration'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: CircleBorder(),
                  child: _imageFile == null
                      ? Icon(Icons.account_circle, size: 100)
                      : CircleAvatar(
                          radius: 50,
                          backgroundImage: FileImage(_imageFile!),
                        ),
                ),
                SizedBox(height: 10),
                TextButton.icon(
                  icon: Icon(Icons.camera_alt),
                  label: Text('Upload Photo'),
                  onPressed: _pickImage,
                ),
                SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: phoneController,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              } else if (value.length != 10) {
                                return 'Phone number must be 10 digits';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              } else if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                final contacts = await Navigator.push<List<String>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EmergencyContactsScreen(),
                                  ),
                                );
                                
                                if (contacts != null && contacts.length >= 2) {
                                  setState(() {
                                    _emergencyContacts = contacts;
                                  });
                                  // In a real app, you would save the user data here
                                  Navigator.pushReplacementNamed(context, '/home');
                                }
                              }
                            },
                            child: Text(
                              'Sign Up',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}