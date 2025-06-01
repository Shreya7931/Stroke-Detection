import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:record/record.dart';
import 'package:camera/camera.dart';
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
  String _serverUrl = "http://192.168.42.65:8000";
  List<double> _testResults = [];

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isArmTestRunning = false;
  bool _armTestCompleted = false;
  double? _armTestResult;
  double? _faceTestResult;

  String _armTestStatus = "";
  String _faceTestStatus = "";

  // Image paths for examples
  final String normalFaceImage = 'assets/images/normal_face.png';
  final String droopedFaceImage = 'assets/images/drooped_face.png';
  final String symmetricalArmsImage = 'assets/images/symmetrical_arms.png';
  final String asymmetricalArmsImage = 'assets/images/asymmetrical_arms.png';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        CameraDescription selectedCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      _showError("Camera initialization failed: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _uploadFaceVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video == null) return;

    setState(() {
      _isUploading = true;
      _faceTestStatus = "Analyzing facial symmetry...";
    });
    
    try {
      var uri = Uri.parse("$_serverUrl/analyze-face");
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

      double score = jsonResponse['stroke_ratio']?.toDouble() ?? 0.0;
      _faceTestResult = score;
      _testResults.add(score);
      
      setState(() {
        _faceTestStatus = "Facial symmetry analysis completed: ${(score * 100).toStringAsFixed(1)}%";
      });
      
      if (_testResults.length >= 2) await _sendCombinedAnalysis();
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _startArmDriftTest() async {
    if (!_isCameraInitialized) {
      _showError("Camera not initialized");
      return;
    }

    setState(() {
      _isArmTestRunning = true;
      _armTestCompleted = false;
      _armTestStatus = "Get ready... Please raise and hold your arms steady for 15 seconds.";
      _armTestResult = null;
    });

    await Future.delayed(Duration(seconds: 15));

    setState(() {
      _armTestStatus = "Analyzing arm drift...";
    });

    try {
      var uri = Uri.parse("$_serverUrl/analyze-arm/");
      var response = await http.post(uri);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);

        var symmetryRaw = jsonResponse['symmetry_percentage'] ?? 0.0;
        double symmetryPercentage = symmetryRaw is int ? symmetryRaw.toDouble() : symmetryRaw;

        double score = 1 - (symmetryPercentage / 100.0);
        _armTestResult = score;
        _testResults.add(score);
        
        setState(() {
          _armTestStatus = "Arm drift analysis completed: ${(symmetryPercentage).toStringAsFixed(1)}% symmetry";
          _armTestCompleted = true;
        });
        
        if (_testResults.length >= 2) await _sendCombinedAnalysis();
      } else {
        _showError("Arm test failed: ${response.body}");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isArmTestRunning = false;
      });
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

        double score = jsonResponse['confidence']?.toDouble() ?? 0.0;
        _testResults.add(score);
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

      for (int i = 0; i < widget.emergencyContacts.length; i++) {
        request.fields['emergency_contacts[$i]'] = widget.emergencyContacts[i];
      }

      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      var jsonResponse = json.decode(respStr);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StrokeDetectedScreen(
            strokeDetected: true, //jsonResponse['stroke_detected'] ?? false,
            emergencyContacts: widget.emergencyContacts,
          ),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  Widget _buildTestCard(String title, VoidCallback onPressed, {bool isRecording = false}) {
    bool isFaceTest = title.contains("Facial Symmetry");
    bool isArmTest = title.contains("Arm Drift Test");
    
    String buttonLabel = "Start";
    IconData buttonIcon = Icons.play_circle_fill;
    Color? cardColor = Colors.white;

    if (isArmTest) {
      if (_armTestCompleted) {
        buttonLabel = "Test Completed";
        buttonIcon = Icons.check_circle_outline;
        cardColor = Colors.green[50];
      } else if (_isArmTestRunning) {
        buttonLabel = "Running...";
        buttonIcon = Icons.hourglass_top;
      }
    } else if (isFaceTest && _faceTestResult != null) {
      buttonLabel = "Test Completed";
      buttonIcon = Icons.check_circle_outline;
      cardColor = Colors.green[50];
    } else if (isRecording) {
      buttonLabel = "Stop Recording";
      buttonIcon = Icons.stop;
    }

    return Card(
      color: cardColor,
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
            
            if (isFaceTest) ...[
              Text("Examples:", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text("Normal Face", style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      Image.asset(
                        normalFaceImage,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text("Drooped Face", style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      Image.asset(
                        droopedFaceImage,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
            
            if (isArmTest) ...[
              Text("Examples:", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text("Symmetrical Arms", style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      Image.asset(
                        symmetricalArmsImage,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text("Asymmetrical Arms", style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      Image.asset(
                        asymmetricalArmsImage,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
            
            if (isFaceTest && _faceTestStatus.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  _faceTestStatus,
                  style: TextStyle(color: Colors.blue[800]),
                ),
              ),
            
            if (isArmTest && _armTestStatus.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  _armTestStatus,
                  style: TextStyle(color: Colors.blue[800]),
                ),
              ),
            
            if (isFaceTest && _faceTestResult != null)
              Text(
                "Symmetry Score: ${(100 - (_faceTestResult! * 100)).toStringAsFixed(1)}%",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            
            if (isArmTest && _armTestResult != null)
              Text(
                "Symmetry Score: ${(100 - (_armTestResult! * 100)).toStringAsFixed(1)}%",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            
            SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: (_isUploading || 
                          (isArmTest && (_armTestCompleted || _isArmTestRunning)) ||
                          (isFaceTest && _faceTestResult != null))
                    ? null
                    : (_isUploading ? null : onPressed),
                icon: Icon(buttonIcon),
                label: Text(buttonLabel),
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
        child: _isArmTestRunning
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _armTestStatus,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  _isCameraInitialized && _cameraController != null
                      ? AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        )
                      : Center(child: CircularProgressIndicator()),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isArmTestRunning = false;
                        _armTestStatus = "";
                        _armTestCompleted = false;
                      });
                    },
                    child: Text("Cancel Arm Test"),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTestCard("Facial Symmetry (Video Scan)", _uploadFaceVideo),
                    _buildTestCard(
                      "Arm Drift Test (Raise Arm and Hold for 15 Seconds)",
                      _startArmDriftTest,
                    ),
                    _buildTestCard(
                      "Speech Test",
                      _recordAndUploadSpeech,
                      isRecording: _isRecording,
                    ),
                    if (_isUploading)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $msg")));
    setState(() {
      _isUploading = false;
      _isArmTestRunning = false;
    });
  }
}