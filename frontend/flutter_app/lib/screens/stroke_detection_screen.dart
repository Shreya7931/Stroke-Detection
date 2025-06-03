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
  Position? _currentPosition;

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
      _currentPosition = await _determinePosition();
      final hospitals = await fetchHospitalsFromOverpass(
        _currentPosition!.latitude, 
        _currentPosition!.longitude
      );
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

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services.');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable them in settings.');
    }

    // Get current position with high accuracy and fresh data
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: false,
        timeLimit: Duration(seconds: 30), // Add timeout
      );
      
      // Verify the position is recent (within last 5 minutes)
      final now = DateTime.now();
      final positionTime = position.timestamp;
      final timeDifference = now.difference(positionTime).inMinutes;
      
      if (timeDifference > 5) {
        // If cached position is too old, try to get a fresh one
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          forceAndroidLocationManager: true, // Force fresh location
          timeLimit: Duration(seconds: 15),
        );
      }
      
      return position;
    } catch (e) {
      // Fallback: try with medium accuracy if high accuracy fails
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        );
      } catch (e2) {
        // Last resort: get last known position if available
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          // Check if last known position is recent enough (within 1 hour)
          final timeDiff = DateTime.now().difference(lastKnown.timestamp).inHours;
          if (timeDiff < 1) {
            return lastKnown;
          }
        }
        throw Exception('Unable to get current location. Please check your GPS and try again.');
      }
    }
  }

  Future<List<Hospital>> fetchHospitalsFromOverpass(double lat, double lon) async {
    final radius = 1000; // Increased to 5km radius for better coverage
    final query = '''
    [out:json][timeout:25];
    (
      node["amenity"="hospital"](around:$radius,$lat,$lon);
      way["amenity"="hospital"](around:$radius,$lat,$lon);
      relation["amenity"="hospital"](around:$radius,$lat,$lon);
    );
    out center meta;
    ''';

    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    
    try {
      final response = await http.post(
        url, 
        body: {'data': query},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch hospital data: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      List elements = data['elements'] ?? [];

      List<Hospital> hospitals = elements.map<Hospital>((e) {
        final tags = e['tags'] ?? {};
        double? hospitalLat;
        double? hospitalLon;
        
        // Handle different element types (node, way, relation)
        if (e['lat'] != null && e['lon'] != null) {
          hospitalLat = e['lat']?.toDouble();
          hospitalLon = e['lon']?.toDouble();
        } else if (e['center'] != null) {
          hospitalLat = e['center']['lat']?.toDouble();
          hospitalLon = e['center']['lon']?.toDouble();
        }
        
        return Hospital(
          name: tags['name'] ?? 'Hospital',
          phone: tags['phone'] ?? tags['contact:phone'] ?? '108', // Use local emergency number
          lat: hospitalLat,
          lon: hospitalLon,
        );
      }).where((hospital) => hospital.lat != null && hospital.lon != null).toList();

      // Sort by distance from current location
      hospitals.sort((a, b) {
        double distanceA = Geolocator.distanceBetween(lat, lon, a.lat!, a.lon!);
        double distanceB = Geolocator.distanceBetween(lat, lon, b.lat!, b.lon!);
        return distanceA.compareTo(distanceB);
      });

      return hospitals.take(10).toList(); // Return top 10 closest hospitals
    } catch (e) {
      throw Exception('Error fetching hospitals: $e');
    }
  }

  Future<void> _callEmergency(String number) async {
    final url = 'tel:$number';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not make call to $number'))
      );
    }
  }

  Future<void> _openHospitalDirections(double? hospitalLat, double? hospitalLon) async {
    if (_currentPosition == null || hospitalLat == null || hospitalLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not determine location for directions'))
      );
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&destination=$hospitalLat,$hospitalLon'
      '&travelmode=driving'
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open directions'))
      );
    }
  }

  // Add method to refresh location
  Future<void> _refreshLocation() async {
    await _fetchNearbyHospitals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stroke Detection Result'),
        actions: widget.strokeDetected ? [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshLocation,
            tooltip: 'Refresh Location',
          ),
        ] : null,
      ),
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
                  SizedBox(height: 10),
                  if (_currentPosition != null)
                    Text('Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  SizedBox(height: 20),
                  Text('Emergency services have been notified',
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nearby Hospitals:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (!isLoading)
                        TextButton.icon(
                          onPressed: _refreshLocation,
                          icon: Icon(Icons.refresh, size: 16),
                          label: Text('Refresh'),
                        ),
                    ],
                  ),
                  SizedBox(height: 15),
                  if (isLoading)
                    Center(child: CircularProgressIndicator())
                  else if (error != null)
                    Column(
                      children: [
                        Text('Error: $error'),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _refreshLocation,
                          child: Text('Try Again'),
                        ),
                      ],
                    )
                  else if (nearbyHospitals.isEmpty)
                    Text('No nearby hospitals found. Please call emergency services.')
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: nearbyHospitals.length,
                        itemBuilder: (context, index) {
                          final hospital = nearbyHospitals[index];
                          double? distance;
                          if (_currentPosition != null && hospital.lat != null && hospital.lon != null) {
                            distance = Geolocator.distanceBetween(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                              hospital.lat!,
                              hospital.lon!,
                            );
                          }
                          
                          return Column(
                            children: [
                              ListTile(
                                leading: Icon(Icons.local_hospital, size: 40),
                                title: Text(hospital.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hospital.phone != '108') 
                                      Text(hospital.phone),
                                    if (distance != null)
                                      Text('${(distance / 1000).toStringAsFixed(1)} km away',
                                           style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.phone),
                                      onPressed: () => _callEmergency(hospital.phone),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.directions),
                                      onPressed: () => _openHospitalDirections(
                                        hospital.lat, 
                                        hospital.lon
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(),
                            ],
                          );
                        },
                      ),
                    ),
                  SizedBox(height: 30),
                  _EmergencyButton(
                    icon: Icons.emergency,
                    label: 'Call Ambulance (108)',
                    onPressed: () => _callEmergency('108'),
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
  final double? lat;
  final double? lon;

  Hospital({
    required this.name,
    required this.phone,
    this.lat,
    this.lon,
  });
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
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}