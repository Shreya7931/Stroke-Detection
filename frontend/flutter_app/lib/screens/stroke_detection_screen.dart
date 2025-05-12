import 'package:flutter/material.dart';

class StrokeDetectedScreen extends StatelessWidget {
  final bool strokeDetected = true; // Simulate stroke detection

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stroke Detection Result')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: strokeDetected
            ? Column(
                children: [
                  Text('Stroke Detected! Please Choose a Hospital:',
                      style: TextStyle(fontSize: 18)),
                  ElevatedButton(onPressed: () {}, child: Text('Hospital 1')),
                  ElevatedButton(onPressed: () {}, child: Text('Hospital 2')),
                  ElevatedButton(onPressed: () {}, child: Text('Hospital 3')),
                  SizedBox(height: 20),
                  ElevatedButton(onPressed: () {}, child: Text('Call Ambulance')),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
                    SizedBox(height: 20),
                    Text('No Stroke Detected', style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),
      ),
    );
  }
}
