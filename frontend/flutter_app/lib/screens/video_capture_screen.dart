import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class VideoCaptureScreen extends StatefulWidget {
  @override
  _VideoCaptureScreenState createState() => _VideoCaptureScreenState();
}

class _VideoCaptureScreenState extends State<VideoCaptureScreen> {
  late CameraController _controller;
  late List<CameraDescription> cameras;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    cameras = await availableCameras();
    _controller = CameraController(cameras[0], ResolutionPreset.high);

    await _controller.initialize();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Face and Arm Drift Detection'),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 400,
            child: CameraPreview(_controller),
          ),
          ElevatedButton(
            onPressed: () {
              // Add logic to start video capture and process frames
              // For example, send frames to backend or process locally
            },
            child: Text('Start Capturing'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
