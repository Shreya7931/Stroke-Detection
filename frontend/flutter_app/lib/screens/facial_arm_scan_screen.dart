import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:record/record.dart';
import 'stroke_detection_screen.dart';

class FacialArmScanScreen extends StatefulWidget {
  final List<String> emergencyContacts;
  const FacialArmScanScreen({required this.emergencyContacts});

  @override
  State<FacialArmScanScreen> createState() => _FacialArmScanScreenState();
}

class _FacialArmScanScreenState extends State<FacialArmScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final Record _audioRecorder = Record();
  bool _isUploading = false;
  bool _isRecording = false;
  String _serverUrl = "http://192.168.1.10:8000";
  List<double> _testResults = [];

  Future<void> _uploadVideo(String type) async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video == null) return;

    setState(() => _isUploading = true);
    try {
      var uri = Uri.parse("$_serverUrl/analyze-$type");
      var request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final bytes = await video.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: video.name,
          contentType: MediaType('video', 'mp4'),
        );
        request.files.add(multipartFile);
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', video.path));
      }

      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      var jsonResponse = json.decode(respStr);

      double score = type == 'face'
          ? jsonResponse['stroke_ratio'] ?? 0.0
          : 1 - (jsonResponse['symmetry_percentage'] ?? 0.0) / 100.0;

      _testResults.add(score);
      if (_testResults.length >= 2) await _sendCombinedAnalysis();
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _recordAndUploadSpeech() async {
    if (!_isRecording) {
      if (!await _audioRecorder.hasPermission()) {
        _showError("Microphone permission denied");
        return;
      }
      setState(() => _isRecording = true);
      await _audioRecorder.start();
    } else {
      setState(() => _isUploading = true);
      String? path = await _audioRecorder.stop();

      if (path == null) {
        setState(() {
          _isRecording = false;
          _isUploading = false;
        });
        return;
      }

      try {
        var uri = Uri.parse("$_serverUrl/analyze-speech");
        var request = http.MultipartRequest('POST', uri);
        request.files.add(await http.MultipartFile.fromPath('file', path));

        var response = await request.send();
        var respStr = await response.stream.bytesToString();
        var jsonResponse = json.decode(respStr);

        _testResults.add(jsonResponse['confidence'] ?? 0.0);
        await _sendCombinedAnalysis();
      } catch (e) {
        _showError(e.toString());
      } finally {
        setState(() {
          _isRecording = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _sendCombinedAnalysis() async {
    if (_testResults.length < 2) return;

    try {
      var uri = Uri.parse("$_serverUrl/detect-stroke");
      var request = http.MultipartRequest('POST', uri);
      request.fields['face_result'] = _testResults[0].toString();
      request.fields['arm_result'] = _testResults[1].toString();
      request.fields['speech_result'] = _testResults.length > 2 ? _testResults[2].toString() : "0.0";
      request.fields['contacts'] = json.encode(widget.emergencyContacts);

      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      var jsonResponse = json.decode(respStr);

      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => StrokeDetectedScreen(
      strokeDetected: jsonResponse['stroke_detected'] ?? false,
      emergencyContacts: widget.emergencyContacts,
    ),
  ),
);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $msg")));
  }

  Widget _buildTestCard(String title, VoidCallback onPressed, {bool isRecording = false}) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : onPressed,
                icon: Icon(isRecording ? Icons.stop : Icons.play_circle_fill),
                label: Text(isRecording ? "Stop Recording" : "Start"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("Stroke Detection Tests"),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                "Upload videos for face and arm tests, and record speech.",
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              if (_isUploading) ...[
                SizedBox(height: 20),
                CircularProgressIndicator(),
              ],
              _buildTestCard("Face Symmetry Test", () => _uploadVideo('face')),
              _buildTestCard("Arm Drift Test", () => _uploadVideo('arm')),
              _buildTestCard("Speech Test", _recordAndUploadSpeech, isRecording: _isRecording),
            ],
          ),
        ),
      ),
    );
  }
}
