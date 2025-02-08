import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lottie/lottie.dart';
import '../painters/face_detector_painter.dart';

class EmotionDetectionScreen extends StatefulWidget {
  const EmotionDetectionScreen({super.key});

  @override
  State<EmotionDetectionScreen> createState() => _EmotionDetectionScreenState();
}

class _EmotionDetectionScreenState extends State<EmotionDetectionScreen> {
  // Face Detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // Device Orientation
  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // Processing States
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Emotion _currentEmotion = Emotion.unknown;

  // Camera Configuration
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;
  int _cameraIndex = -1;
  bool _changingCameraLens = false;

  // Camera Controls
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentExposureOffset = 0.0;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _stopLiveFeed();
    _canProcess = false;
    _faceDetector.close();
    super.dispose();
  }

  // Initialization Methods
  Future<void> _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    _setCameraIndex();
    if (_cameraIndex != -1) {
      await _startLiveFeed();
    }
  }

  void _setCameraIndex() {
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == _cameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }

    if (_cameraIndex == -1 && _cameras.isNotEmpty) {
      _cameraIndex = 0;
    }
  }

  // UI Building
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emotion Detector")),
      body: _liveFeedBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _switchLiveCamera,
        child: const Icon(Icons.flip_camera_android_outlined),
      ),
    );
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) {
      return Center(
        child: Text("No Camera Found!"),
      );
    } else if (_controller == null) {
      return Center(
        child: Text("Camera Controller Unavailable."),
      );
    } else if (_controller?.value.isInitialized == false) {
      return Center(
        child: Text("Camera Controller Not Initialized."),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCameraPreview(),
          _buildZoomControl(),
          const Divider(
            indent: 24,
            endIndent: 24,
          ),
          const SizedBox(height: 24),
          _emotionAnimation(),
          const SizedBox(height: 8),
          _emotionLabel(),
        ],
      ),
    );
  }

  // Camera Preview Widget
  Widget _buildCameraPreview() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: _changingCameraLens
          ? const Center(child: Text('Changing camera lens'))
          : _buildCameraFeed(),
    );
  }

  Widget _buildCameraFeed() {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _getCameraPreviewWidth(),
        height: _getCameraPreviewHeight(),
        child: CameraPreview(
          _controller!,
          child: _customPaint,
        ),
      ),
    );
  }

  double _getCameraPreviewWidth() {
    if(_controller!.value.usesAlternateResolutionMethod!){
      return _controller!.value.previewSize!.width;
    }
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? _controller!.value.previewSize!.height
        : _controller!.value.previewSize!.width;
  }

  double _getCameraPreviewHeight() {
    if(_controller!.value.usesAlternateResolutionMethod!){
      return _controller!.value.previewSize!.height;
    }
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? _controller!.value.previewSize!.width
        : _controller!.value.previewSize!.height;
  }

  // Camera Controls
  Widget _buildZoomControl() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Slider(
              value: _currentZoomLevel,
              min: _minAvailableZoom,
              max: _maxAvailableZoom,
              divisions: (_maxAvailableZoom / 0.1).floor(),
              onChanged: _onZoomChanged,
            ),
          ),
          _buildZoomLabel(),
        ],
      ),
    );
  }

  Widget _buildZoomLabel() {
    return SizedBox(
      width: 50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Text('${_currentZoomLevel.toStringAsFixed(1)}x'),
        ),
      ),
    );
  }

  Widget _buildExposureControl() {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: _currentExposureOffset,
            min: _minAvailableExposureOffset,
            max: _maxAvailableExposureOffset,
            onChanged: _onExposureChanged,
          ),
        ),
        _buildExposureLabel(),
      ],
    );
  }

  Widget _buildExposureLabel() {
    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Text('${_currentExposureOffset.toStringAsFixed(1)}x'),
        ),
      ),
    );
  }

  // Emotion Animation
  Widget _emotionAnimation() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildEmotionAnimationChild(),
    );
  }

  Widget _buildEmotionAnimationChild() {
    const double size = 100;
    final String animationPath = _getEmotionAnimationPath();

    return SizedBox(
      key: ValueKey(animationPath),
      height: size,
      width: size,
      child: Lottie.asset(
        animationPath,
        repeat: true,
        animate: true,
      ),
    );
  }

  Widget _emotionLabel() {
    return Text(
      switch (_currentEmotion) {
        Emotion.happy => 'Happy Face :)',
        Emotion.sad => 'Sad Face :(',
        Emotion.neutral => 'Neutral',
        Emotion.unknown => 'Scanning ...',
      },
      textAlign: TextAlign.center,
    );
  }

  String _getEmotionAnimationPath() {
    switch (_currentEmotion) {
      case Emotion.happy:
        return 'assets/happy.json';
      case Emotion.sad:
        return 'assets/sad.json';
      case Emotion.neutral:
        return 'assets/neutral.json';
      default:
        return 'assets/scanning.json';
    }
  }

  // Camera Control Methods
  Future<void> _onZoomChanged(double value) async {
    setState(() => _currentZoomLevel = value);
    await _controller?.setZoomLevel(value);
  }

  Future<void> _onExposureChanged(double value) async {
    setState(() => _currentExposureOffset = value);
    await _controller?.setExposureOffset(value);
  }

  // Camera Operations
  Future<void> _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _initializeCameraController(camera);
  }

  Future<void> _initializeCameraController(CameraDescription camera) async {
    try {
      await _controller?.initialize();

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Uses Alternate Mode: ${_controller!.value.usesAlternateResolutionMethod}"),
            duration: Duration(seconds: 15),
            action: SnackBarAction(
              label: "Okay",
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        ),
      );

      await _setupCameraParameters();
      await _startImageStream(camera);

      setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _setupCameraParameters() async {
    final minZoom = await _controller?.getMinZoomLevel() ?? 1.0;
    final maxZoom = await _controller?.getMaxZoomLevel() ?? 1.0;
    final minExposure = await _controller?.getMinExposureOffset() ?? 0.0;
    final maxExposure = await _controller?.getMaxExposureOffset() ?? 0.0;

    setState(() {
      _currentZoomLevel = minZoom;
      _minAvailableZoom = minZoom;
      _maxAvailableZoom = maxZoom;
      _currentExposureOffset = 0.0;
      _minAvailableExposureOffset = minExposure;
      _maxAvailableExposureOffset = maxExposure;
    });
  }

  Future<void> _startImageStream(CameraDescription camera) async {
    await _controller?.startImageStream(_processCameraImage);
    setState(() => _cameraLensDirection = camera.lensDirection);
  }

  Future<void> _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);

    _cameraIndex = (_cameraIndex + 1) % _cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();

    setState(() => _changingCameraLens = false);
  }

  // Image Processing
  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess || _isBusy) return;

    _isBusy = true;
    final faces = await _faceDetector.processImage(inputImage);

    _updateEmotionState(faces);
    //_updateCustomPaint(faces, inputImage);

    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _updateEmotionState(List<Face> faces) {
    if (faces.isEmpty) {
      setState(() => _currentEmotion = Emotion.unknown);
      return;
    }

    final Face face = faces.first;
    final double? smileProb = face.smilingProbability;

    if (smileProb != null) {
      setState(() {
        if (smileProb > 0.7) {
          _currentEmotion = Emotion.happy;
        } else if (smileProb < 0.05) {
          _currentEmotion = Emotion.sad;
        } else {
          _currentEmotion = Emotion.neutral;
        }
      });
    }
  }

  void _updateCustomPaint(List<Face> faces, InputImage inputImage) {
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = FaceDetectorPainter(
        faces,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      _customPaint = null;
    }
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage != null) {
      _processImage(inputImage);
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final rotation = _getInputImageRotation();
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (!_isImageFormatSupported(format)) return null;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  InputImageRotation? _getInputImageRotation() {
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }

      return InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    return null;
  }

  bool _isImageFormatSupported(InputImageFormat? format) {
    return format != null &&
        ((Platform.isAndroid && format == InputImageFormat.nv21) ||
            (Platform.isIOS && format == InputImageFormat.bgra8888));
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (var plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }
}

enum Emotion { happy, sad, neutral, unknown }
