import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/screens/facial_arm_scan_screen.dart';

class EmergencyContactsScreen extends StatefulWidget {
  @override
  _EmergencyContactsScreenState createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<TextEditingController> _contactControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    for (var controller in _contactControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency Contacts'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Please add at least 2 emergency contacts who can be notified in case of stroke detection.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _buildContactField(1),
              SizedBox(height: 16),
              _buildContactField(2),
              Spacer(),
              ElevatedButton(
                onPressed: _saveContacts,
                child: Text(
                  'Save Contacts',
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
    );
  }

  Widget _buildContactField(int index) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contact $index',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _contactControllers[index - 1],
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.phone),
                prefixText: '+',
                hintText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a phone number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveContacts() {
    List<String> contacts = [];
    for (var controller in _contactControllers) {
      if (controller.text.isNotEmpty) {
        contacts.add('+${controller.text}');
      }
    }

    if (contacts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least 2 emergency contacts'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FacialArmScanScreen(emergencyContacts: contacts),
      ),
    );
  }
}
