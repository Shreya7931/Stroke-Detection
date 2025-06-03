import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:record/record.dart';
import 'package:camera/camera.dart';
import 'stroke_detection_screen.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
class FacialArmScanScreen extends StatefulWidget {
  final List<String> emergencyContacts;
  const FacialArmScanScreen({required this.emergencyContacts});

  @override
  State<FacialArmScanScreen> createState() => _FacialArmScanScreenState();
}

class _FacialArmScanScreenState extends State<FacialArmScanScreen> 
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final Record _audioRecorder = Record();
  bool _isUploading = false;
  bool _isRecording = false;
  String _serverUrl = "http://localhost:8000";
  List<double> _testResults = [];

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isArmTestRunning = false;
  bool _armTestCompleted = false;
  bool _isFaceTestRunning = false;
  bool _faceTestCompleted = false;
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
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Stop any ongoing operations before disposing
    _isArmTestRunning = false;
    _isFaceTestRunning = false;
    
    // Dispose camera controller safely
    _cameraController?.dispose().catchError((e) {
      print("Error disposing camera: $e");
    });
    
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Camera will be disposed and re-initialized when app resumes
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // Improved camera initialization with better error handling
  Future<void> _initializeCamera() async {
    try {
      // Dispose existing controller first
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }
      
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
        
        // Add a small delay to ensure camera is fully ready
        await Future.delayed(Duration(milliseconds: 500));
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print("Camera initialization error: $e");
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
      _showError("Camera initialization failed: $e");
    }
  }

  // Add method to refresh camera between tests
  Future<void> _refreshCamera() async {
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
    
    // Small delay to let UI update
    await Future.delayed(Duration(milliseconds: 100));
    
    await _initializeCamera();
  }

  // Modified _ensureCameraReady method
  Future<void> _ensureCameraReady() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.hasError) {
      await _refreshCamera();
    }
    
    // Double check after refresh
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception("Camera failed to initialize");
    }
  }

  // Debug method to understand camera state
  void _debugCameraState() {
    print("=== Camera Debug Info ===");
    print("Camera initialized: $_isCameraInitialized");
    print("Camera controller null: ${_cameraController == null}");
    if (_cameraController != null) {
      print("Camera value initialized: ${_cameraController!.value.isInitialized}");
      print("Camera aspect ratio: ${_cameraController!.value.aspectRatio}");
      print("Camera preview size: ${_cameraController!.value.previewSize}");
      print("Has error: ${_cameraController!.value.hasError}");
      if (_cameraController!.value.hasError) {
        print("Error: ${_cameraController!.value.errorDescription}");
      }
    }
    print("Arm test running: $_isArmTestRunning");
    print("Face test running: $_isFaceTestRunning");
    print("========================");
  }

  // Improved camera preview widget
  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                "Initializing camera...",
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _refreshCamera,
                child: Text("Retry Camera"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraController!.value.isInitialized || _cameraController!.value.hasError) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, color: Colors.white, size: 48),
              SizedBox(height: 16),
              Text(
                "Camera error or not ready",
                style: TextStyle(color: Colors.white),
              ),
              if (_cameraController!.value.hasError)
                Text(
                  _cameraController!.value.errorDescription ?? "Unknown error",
                  style: TextStyle(color: Colors.red[300], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _refreshCamera,
                child: Text("Retry Camera"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: OverflowBox(
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  // Updated face test method
 Future<void> _startFaceSymmetryTest() async {
  try {
    setState(() {
      _isFaceTestRunning = true;
      _faceTestStatus = "Preparing camera...";
      _faceTestResult = null;
    });

    await _ensureCameraReady();
    
    setState(() {
      _faceTestStatus = "Get ready... Please look directly at the camera for 5 seconds.";
    });

    // Capture frames for 5 seconds
    List<Uint8List> capturedFrames = [];
    final startTime = DateTime.now();
    final frameInterval = Duration(milliseconds: 200); // 5 FPS
    
    while (DateTime.now().difference(startTime).inSeconds < 5) {
      if (!_isFaceTestRunning) break; // Allow cancellation
      
      try {
        if (kIsWeb) {
          // Web-specific capture
          final image = await _cameraController!.takePicture();
          final bytes = await image.readAsBytes();
          capturedFrames.add(bytes);
        } else {
          // Mobile capture
          final frame = await _cameraController!.takePicture();
          capturedFrames.add(await frame.readAsBytes());
        }
        await Future.delayed(frameInterval);
      } catch (e) {
        print("Error capturing frame: $e");
      }
    }

    if (capturedFrames.isEmpty) {
      _showError("No frames captured");
      return;
    }

    setState(() {
      _faceTestStatus = "Analyzing facial symmetry...";
    });

    // Create multipart request
    var uri = Uri.parse("$_serverUrl/analyze-face/");
    var request = http.MultipartRequest('POST', uri);
    
    // Add all frames
    for (var i = 0; i < capturedFrames.length; i++) {
      final frameBytes = capturedFrames[i];
      request.files.add(http.MultipartFile.fromBytes(
        'frames',
        frameBytes,
        filename: 'frame_$i.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonResponse = json.decode(responseData);
    
    bool strokeDetected = jsonResponse['stroke_detected'] ?? false;
    double avgSymmetry = jsonResponse['avg_symmetry']?.toDouble() ?? 0.0;
    
    setState(() {
      _faceTestResult = strokeDetected ? 1.0 : 0.0;
      _faceTestStatus = "Facial symmetry analysis completed: "
          "${(avgSymmetry * 100).toStringAsFixed(1)}% symmetry "
          "${strokeDetected ? '(ASYMMETRICAL - Potential Issue)' : '(SYMMETRICAL - Normal)'}";
      _faceTestCompleted = true;
    });
    
    _testResults.add(_faceTestResult!);
    if (_testResults.length >= 2) await _sendCombinedAnalysis();
    
  } catch (e) {
    _showError("Face test error: $e");
  } finally {
    setState(() => _isFaceTestRunning = false);
    _refreshCamera();
  }
}

Future<void> _startArmDriftTest() async {
  try {
    setState(() {
      _isArmTestRunning = true;
      _armTestStatus = "Preparing camera...";
      _armTestResult = null;
    });

    await _ensureCameraReady();
    
    setState(() {
      _armTestStatus = "Get ready... Please raise and hold your arms steady for 15 seconds.";
    });

    // Capture frames for 15 seconds
    List<Uint8List> capturedFrames = [];
    final startTime = DateTime.now();
    final frameInterval = Duration(milliseconds: 300); // ~3 FPS
    
    while (DateTime.now().difference(startTime).inSeconds < 15) {
      if (!_isArmTestRunning) break;
      
      try {
        if (kIsWeb) {
          final image = await _cameraController!.takePicture();
          final bytes = await image.readAsBytes();
          capturedFrames.add(bytes);
        } else {
          final frame = await _cameraController!.takePicture();
          capturedFrames.add(await frame.readAsBytes());
        }
        await Future.delayed(frameInterval);
      } catch (e) {
        print("Error capturing frame: $e");
      }
    }

    if (capturedFrames.isEmpty) {
      _showError("No frames captured");
      return;
    }

    setState(() {
      _armTestStatus = "Analyzing arm drift...";
    });

    var uri = Uri.parse("$_serverUrl/analyze-arm/");
    var request = http.MultipartRequest('POST', uri);
    
    for (var i = 0; i < capturedFrames.length; i++) {
      request.files.add(http.MultipartFile.fromBytes(
        'frames',
        capturedFrames[i],
        filename: 'frame_$i.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonResponse = json.decode(responseData);
    
    bool strokeDetected = jsonResponse['stroke_detected'] ?? false;
    double symmetryPercentage = jsonResponse['symmetry_percentage']?.toDouble() ?? 0.0;
    
    setState(() {
      _armTestResult = strokeDetected ? 1.0 : 0.0;
      _armTestStatus = "Arm drift analysis completed: "
          "${symmetryPercentage.toStringAsFixed(1)}% symmetry "
          "${strokeDetected ? '(ASYMMETRICAL - Potential Issue)' : '(SYMMETRICAL - Normal)'}";
      _armTestCompleted = true;
    });
    
    _testResults.add(_armTestResult!);
    if (_testResults.length >= 2) await _sendCombinedAnalysis();
    
  } catch (e) {
    _showError("Arm test error: $e");
  } finally {
    setState(() => _isArmTestRunning = false);
    _refreshCamera();
  }
}
// Updated combined analysis method
Future<void> _sendCombinedAnalysis() async {
  if (_testResults.length < 2) return;

  try {
    var uri = Uri.parse("$_serverUrl/detect-stroke/");
    var request = http.MultipartRequest('POST', uri);
    
    // Send boolean results as strings
    bool faceStrokeDetected = _testResults[0] > 0.5;
    bool armStrokeDetected = _testResults[1] > 0.5;
    bool speechStrokeDetected = _testResults.length > 2 ? _testResults[2] > 0.5 : false;
    
    request.fields['face_stroke_detected'] = faceStrokeDetected.toString();
    request.fields['arm_stroke_detected'] = armStrokeDetected.toString();
    request.fields['speech_stroke_detected'] = speechStrokeDetected.toString();

    for (int i = 0; i < widget.emergencyContacts.length; i++) {
      request.fields['emergency_contacts'] = widget.emergencyContacts[i];
    }

    print("Sending to backend:");
    print("Face: $faceStrokeDetected, Arm: $armStrokeDetected, Speech: $speechStrokeDetected");

    var response = await request.send();
    var respStr = await response.stream.bytesToString();
    var jsonResponse = json.decode(respStr);

    print("Backend response: $jsonResponse");

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
    _showError("Combined analysis error: $e");
    print("Error in _sendCombinedAnalysis: $e");
  }
}

  Widget _buildTestCard(String title, VoidCallback onPressed, {bool isRecording = false}) {
  bool isFaceTest = title.contains("Facial Symmetry");
  bool isArmTest = title.contains("Arm Drift Test");
  
  String buttonLabel = "Start";
  IconData buttonIcon = Icons.play_circle_fill;
  Color? cardColor = Colors.white;

  if (isFaceTest) {
    if (_faceTestCompleted) {
      buttonLabel = "Test Completed";
      buttonIcon = Icons.check_circle_outline;
      cardColor = (_faceTestResult! > 0.5) ? Colors.red[50] : Colors.green[50];
    } else if (_isFaceTestRunning) {
      buttonLabel = "Running...";
      buttonIcon = Icons.hourglass_top;
    }
  } else if (isArmTest) {
    if (_armTestCompleted) {
      buttonLabel = "Test Completed";
      buttonIcon = Icons.check_circle_outline;
      cardColor = (_armTestResult! > 0.5) ? Colors.red[50] : Colors.green[50];
    } else if (_isArmTestRunning) {
      buttonLabel = "Running...";
      buttonIcon = Icons.hourglass_top;
    }
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
          
          // Add example images for face test
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
          
          // Add example images for arm test
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
                style: TextStyle(
                  color: _faceTestResult != null && _faceTestResult! > 0.5 
                      ? Colors.red[800] : Colors.blue[800]
                ),
              ),
            ),
          
          if (isArmTest && _armTestStatus.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                _armTestStatus,
                style: TextStyle(
                  color: _armTestResult != null && _armTestResult! > 0.5 
                      ? Colors.red[800] : Colors.blue[800]
                ),
              ),
            ),
          
          SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              onPressed: (_isUploading || 
                        (isArmTest && (_armTestCompleted || _isArmTestRunning)) ||
                        (isFaceTest && (_faceTestCompleted || _isFaceTestRunning)))
                  ? null
                  : onPressed,
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

  Widget _buildTestingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isArmTestRunning ? _armTestStatus : _faceTestStatus,
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12),
        
        // Improved camera preview
        _buildCameraPreview(),
        
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isArmTestRunning = false;
              _isFaceTestRunning = false;
              _armTestStatus = "";
              _faceTestStatus = "";
            });
            // Refresh camera after canceling
            _refreshCamera();
          },
          child: Text(_isArmTestRunning ? "Cancel Arm Test" : "Cancel Face Test"),
        ),
      ],
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
        child: (_isArmTestRunning || _isFaceTestRunning)
            ? _buildTestingView()
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTestCard("Facial Symmetry (Live Camera for 5 Seconds)", _startFaceSymmetryTest),
                    _buildTestCard(
                      "Arm Drift Test (Raise Arm and Hold for 15 Seconds)",
                      _startArmDriftTest,
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
      _isFaceTestRunning = false;
    });
  }
}