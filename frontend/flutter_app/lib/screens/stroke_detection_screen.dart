import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StrokeDetectedScreen extends StatefulWidget {
  final bool strokeDetected;
  final List<String> emergencyContacts;

  const StrokeDetectedScreen({required this.strokeDetected, required this.emergencyContacts});

  @override
  _StrokeDetectedScreenState createState() => _StrokeDetectedScreenState();
}

class _StrokeDetectedScreenState extends State<StrokeDetectedScreen> {
  List<Hospital> nearbyHospitals = [];
  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.strokeDetected) {
      _fetchNearbyHospitals();
    }
  }

  Future<void> _fetchNearbyHospitals() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      Position position = await _determinePosition();
      final hospitals = await fetchHospitalsFromOverpass(position.latitude, position.longitude);
      setState(() {
        nearbyHospitals = hospitals;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<List<Hospital>> fetchHospitalsFromOverpass(double lat, double lon) async {
    final radius = 5000; // 5 km radius
    final query = '''
    [out:json];
    node
      ["amenity"="hospital"]
      (around:$radius,$lat,$lon);
    out;
    ''';

    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    final response = await http.post(url, body: {'data': query});

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch hospital data');
    }

    final data = json.decode(response.body);
    List elements = data['elements'];

    return elements.map((e) {
      final tags = e['tags'] ?? {};
      return Hospital(
        name: tags['name'] ?? 'Unnamed Hospital',
        phone: tags['phone'] ?? '911', // fallback to 911 if no phone found
      );
    }).toList();
  }

  Future<void> _callEmergency(String number) async {
    final url = 'tel:$number';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stroke Detection Result')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: widget.strokeDetected
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning, size: 100, color: Colors.red),
                  SizedBox(height: 20),
                  Text('Stroke Detected!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Text('Emergency services have been notified',
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 30),
                  Text('Nearby Hospitals:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 15),
                  if (isLoading)
                    Center(child: CircularProgressIndicator())
                  else if (error != null)
                    Text('Error: $error')
                  else if (nearbyHospitals.isEmpty)
                    Text('No nearby hospitals found.')
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: nearbyHospitals.length,
                        itemBuilder: (context, index) {
                          final hospital = nearbyHospitals[index];
                          return _EmergencyButton(
                            icon: Icons.local_hospital,
                            label: hospital.name,
                            onPressed: () => _callEmergency(hospital.phone),
                          );
                        },
                      ),
                    ),
                  SizedBox(height: 30),
                  _EmergencyButton(
                    icon: Icons.emergency,
                    label: 'Call Ambulance',
                    onPressed: () => _callEmergency('911'),
                    isAmbulance: true,
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 100, color: Colors.green),
                    SizedBox(height: 20),
                    Text('No Stroke Detected',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    Text('Your test results appear normal',
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 30),
                    Text(
                      'If you still feel unwell, please consult a doctor.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class Hospital {
  final String name;
  final String phone;

  Hospital({required this.name, required this.phone});
}

class _EmergencyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isAmbulance;

  const _EmergencyButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isAmbulance = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(label, style: TextStyle(fontSize: 18)),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isAmbulance
              ? Colors.red
              : Theme.of(context).colorScheme.primary,
          minimumSize: Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
