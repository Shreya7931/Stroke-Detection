import 'package:flutter/material.dart';
import 'facial_arm_scan_screen.dart'; // Ensure this import points to your facial and arm scan screen

class EmergencyContactsScreen extends StatefulWidget {
  @override
  _EmergencyContactsScreenState createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _formKey = GlobalKey<FormState>();

  final family1NameController = TextEditingController();
  final family1RelationController = TextEditingController();
  final family1PhoneController = TextEditingController();

  final doctorNameController = TextEditingController();
  final doctorPhoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Emergency Contacts')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text('Family Member 1', style: TextStyle(fontSize: 18)),
                TextFormField(
                  controller: family1NameController,
                  decoration: InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: family1RelationController,
                  decoration: InputDecoration(labelText: 'Relation'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the relation';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: family1PhoneController,
                  decoration: InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the phone number';
                    } else if (value.length != 10) {
                      return 'Phone number must be 10 digits';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Text('Family Doctor', style: TextStyle(fontSize: 18)),
                TextFormField(
                  controller: doctorNameController,
                  decoration: InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the doctor\'s name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: doctorPhoneController,
                  decoration: InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the phone number';
                    } else if (value.length != 10) {
                      return 'Phone number must be 10 digits';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Navigate to facial and arm scan screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FacialArmScanScreen(),
                        ),
                      );
                    }
                  },
                  child: Text('Submit'),
                ), // ✅ closed ElevatedButton
              ], // ✅ closed Column children
            ), // ✅ closed Column
          ), // ✅ closed Form
        ), // ✅ closed SingleChildScrollView
      ), // ✅ closed Padding
    ); // ✅ closed Scaffold
  }
}
