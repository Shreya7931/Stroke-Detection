import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _userName = '';
  String _userContact = '';
  String _emergencyContact1 = '';
  String _emergencyContact2 = '';
  String _emergencyContact3 = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background color
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text('User Registration'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Logo or title at the top
                Center(
                  child: Icon(
                    Icons.health_and_safety,
                    size: 80.0,
                    color: Colors.blueAccent,
                  ),
                ),
                SizedBox(height: 20),

                // User Name field
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    labelStyle: TextStyle(color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _userName = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // User Contact field
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Your Contact Number',
                    labelStyle: TextStyle(color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _userContact = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your contact number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // Emergency Contact 1
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact 1',
                    labelStyle: TextStyle(color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _emergencyContact1 = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the first emergency contact';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // Emergency Contact 2
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact 2',
                    labelStyle: TextStyle(color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _emergencyContact2 = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the second emergency contact';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // Emergency Contact 3
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact 3',
                    labelStyle: TextStyle(color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _emergencyContact3 = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the third emergency contact';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 30),

                // Register Button
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // Form is valid, navigate to the video capture screen
                        Navigator.pushNamed(context, '/videoCapture');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, // Changed from 'primary' to 'backgroundColor'
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Register',
                      style: TextStyle(fontSize: 18, color: Colors.white),
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
