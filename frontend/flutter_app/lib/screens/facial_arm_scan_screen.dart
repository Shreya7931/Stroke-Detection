import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'stroke_detection_screen.dart';

class FacialArmScanScreen extends StatefulWidget {
  @override
  _FacialArmScanScreenState createState() => _FacialArmScanScreenState();
}

class _FacialArmScanScreenState extends State<FacialArmScanScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _captureAndUploadVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);

    if (video != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse("http://192.168.1.10:8000/analyze-arm-symmetry/"),  // Use your IP here
        );
        request.files.add(await http.MultipartFile.fromPath('file', video.path));

        var response = await request.send();

        if (response.statusCode == 200) {
          print("Upload success!");
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StrokeDetectedScreen()),
          );
        } else {
          print("Upload failed with status ${response.statusCode}");
        }
      } catch (e) {
        print("Error uploading video: $e");
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Facial and Arm Scan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.face, size: 100),
              SizedBox(height: 20),
              _isUploading
                  ? Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Uploading video..."),
                      ],
                    )
                  : Column(
                      children: [
                        Text('Next, a 15-second video of your arms will be taken.'),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _captureAndUploadVideo,
                          child: Text('Capture Arm Video'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
