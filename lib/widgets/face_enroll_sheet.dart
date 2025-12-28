import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/face_api_service.dart';
import '../services/face_recognition_service.dart';

/// Bottom sheet untuk registrasi wajah (enroll) dengan menangkap beberapa frame.
class FaceEnrollSheet extends StatefulWidget {
  const FaceEnrollSheet({super.key, required this.userId});

  final String userId;

  @override
  State<FaceEnrollSheet> createState() => _FaceEnrollSheetState();
}

class _FaceEnrollSheetState extends State<FaceEnrollSheet> {
  final _faceService = FaceRecognitionService();
  final _faceApi = FaceApiService();

  CameraController? _controller;
  String _status = 'Ambil minimal 3 frame wajah';
  bool _busy = false;
  final List<List<double>> _embeddings = [];
  ui.Rect? _lastFaceRect;
  ui.Size? _lastImageSize;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      await _faceService.warmUp();
      final ctrl = await _faceService.createCameraController(front);
      if (!mounted) return;
      setState(() => _controller = ctrl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal membuka kamera: $e');
    }
  }

  Future<void> _stopStream() async {
    try {
      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
    } catch (_) {}
  }

  Future<void> _captureFrame() async {
    if (_controller == null || _busy) return;
    _busy = true;
    try {
      await _stopStream();
      bool captured = false;
      Timer? timeout;
      timeout = Timer(const Duration(seconds: 6), () async {
        if (captured) return;
        await _stopStream();
        captured = true;
        if (mounted) {
          setState(() {
            _busy = false;
            _status = 'Wajah belum terdeteksi. Coba lagi.';
          });
        }
      });
      await _controller!.startImageStream((image) async {
        if (captured) return;
        final result = await _faceService.generateEmbeddingFromCameraImage(
          image,
          _controller!.description.sensorOrientation,
        );
        if (result == null) {
          if (mounted) {
            setState(
              () => _status = 'Wajah belum terdeteksi, posisikan lebih jelas',
            );
          }
          return;
        }
        _lastFaceRect = result.face.boundingBox;
        _lastImageSize = result.imageSize;
        captured = true;
        timeout?.cancel();
        await _stopStream();
        _embeddings.add(result.embedding);
        if (mounted) {
          setState(() {
            _status = 'Frame ke-${_embeddings.length} tersimpan';
          });
        }
        _busy = false;
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Gagal menangkap frame: $e');
      _busy = false;
    }
  }

  Future<void> _submitEnroll() async {
    if (_embeddings.length < 3 || _busy) return;
    setState(() => _busy = true);
    try {
      await _stopStream();
      await _faceApi.enrollFace(userId: widget.userId, embeddings: _embeddings);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Enroll gagal: $e');
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _stopStream();
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller?.value.isInitialized == true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const Text(
              'Registrasi Wajah',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (ready)
              _CameraPreviewWithBox(
                controller: _controller!,
                faceRect: _lastFaceRect,
                imageSize: _lastImageSize,
              )
            else
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : _captureFrame,
                  child: const Text('Ambil Frame'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                  ),
                  onPressed:
                      _embeddings.length < 3 || _busy ? null : _submitEnroll,
                  child: const Text('Kirim Enroll'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Frame terkumpul: ${_embeddings.length}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPreviewWithBox extends StatelessWidget {
  const _CameraPreviewWithBox({
    required this.controller,
    this.faceRect,
    this.imageSize,
  });

  final CameraController controller;
  final ui.Rect? faceRect;
  final ui.Size? imageSize;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    final isFront =
        controller.description.lensDirection == CameraLensDirection.front;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1, // ✅ kotak, bukan rasio kamera
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover, // ✅ crop, bukan gepeng
                child: SizedBox(
                  width: previewSize.height,
                  height: previewSize.width,
                  child: isFront
                      ? Transform.scale(
                          scaleX: -1,
                          child: CameraPreview(controller),
                        )
                      : CameraPreview(controller),
                ),
              ),

              if (faceRect != null && imageSize != null)
                CustomPaint(painter: _FaceBoxPainter(faceRect!, imageSize!)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceBoxPainter extends CustomPainter {
  _FaceBoxPainter(this.faceRect, this.imageSize);

  final ui.Rect faceRect;
  final ui.Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final rect = Rect.fromLTRB(
      faceRect.left * scaleX,
      faceRect.top * scaleY,
      faceRect.right * scaleX,
      faceRect.bottom * scaleY,
    );
    canvas.drawRect(rect, paint);
    canvas.drawCircle(rect.center, rect.shortestSide / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceBoxPainter oldDelegate) {
    return oldDelegate.faceRect != faceRect ||
        oldDelegate.imageSize != imageSize;
  }
}
