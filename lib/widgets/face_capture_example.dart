import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/face_api_service.dart';
import '../services/face_recognition_service.dart';

/// Contoh minimal alur enrollment & verifikasi wajah.
/// - Tekan "Ambil Frame Enroll" 3–5 kali → embedding dikirim ke backend.
/// - Tekan "Verifikasi Sekali" untuk kirim 1 embedding + lokasi (isi lat/lng sesuai GPS Anda).
class FaceCaptureExample extends StatefulWidget {
  const FaceCaptureExample({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<FaceCaptureExample> createState() => _FaceCaptureExampleState();
}

class _FaceCaptureExampleState extends State<FaceCaptureExample> {
  final _faceService = FaceRecognitionService();
  final _faceApi = FaceApiService();

  CameraController? _controller;
  bool _busy = false;
  String _status = 'Siap';

  final List<List<double>> _enrollmentEmbeddings = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    await _faceService.init();
    final ctrl = await _faceService.createCameraController(front);
    if (!mounted) return;
    setState(() => _controller = ctrl);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  Future<void> _captureEnrollFrame() async {
    if (_controller == null || _busy) return;
    _busy = true;
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    await _controller!.startImageStream((image) async {
      final result = await _faceService.generateEmbeddingFromCameraImage(
        image,
        _controller!.description.sensorOrientation,
      );
      if (result == null) {
        setState(() => _status = 'Arahkan wajah ke kamera...');
        return; // belum ketemu wajah
      }

      _enrollmentEmbeddings.add(result.embedding);
      _status = 'Frame enroll ${_enrollmentEmbeddings.length}';

      // Contoh kirim segera setelah dapat >=3 frame
      if (_enrollmentEmbeddings.length >= 3) {
        await _faceApi.enrollFace(
          userId: widget.userId,
          embeddings: _enrollmentEmbeddings,
        );
        _status = 'Enroll terkirim (${_enrollmentEmbeddings.length} frame)';
      }

      await _controller!.stopImageStream();
      _busy = false;
      if (mounted) setState(() {});
    });
  }

  Future<void> _verifyOnce() async {
    if (_controller == null || _busy) return;
    _busy = true;
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    await _controller!.startImageStream((image) async {
      final result = await _faceService.generateEmbeddingFromCameraImage(
        image,
        _controller!.description.sensorOrientation,
      );
      if (result == null) return;

      await _controller!.stopImageStream();
      final res = await _faceApi.verifyFace(
        userId: widget.userId,
        embedding: result.embedding,
        latitude: -6.200000, // TODO: ganti dengan GPS nyata
        longitude: 106.816666,
      );
      _status = 'Verify response: ${res.statusCode}';
      _busy = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Face Recognition')),
      body: Column(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          const SizedBox(height: 12),
          Text(_status),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _busy ? null : _captureEnrollFrame,
                child: const Text('Ambil Frame Enroll'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _busy ? null : _verifyOnce,
                child: const Text('Verifikasi Sekali'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
