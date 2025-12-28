import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/face_recognition_service.dart';

/// Bottom sheet menampilkan preview kamera & otomatis mengambil 1 embedding wajah.
/// Hasil embedding dikembalikan via Navigator.pop(result).
class FaceCaptureSheet extends StatefulWidget {
  const FaceCaptureSheet({
    super.key,
    this.autoCloseOnCapture = true,
    this.onEmbedding,
  });

  final bool autoCloseOnCapture;
  final ValueChanged<List<double>>? onEmbedding;

  @override
  State<FaceCaptureSheet> createState() => _FaceCaptureSheetState();
}

class _FaceCaptureSheetState extends State<FaceCaptureSheet> {
  final _faceService = FaceRecognitionService();
  CameraController? _controller;
  String _status = 'Memuat kamera...';
  bool _streaming = false;
  bool _processing = false;
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
      setState(() {
        _controller = ctrl;
        _status = 'Arahkan wajah Anda ke kamera';
      });
      // beri waktu sesaat agar kamera stabil sebelum mulai stream
      Future.delayed(const Duration(milliseconds: 150), _startCapture);
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

  Future<void> _startCapture() async {
    if (_controller == null || _streaming || _processing) return;
    _streaming = true;
    try {
      await _stopStream();
      await _controller!.startImageStream((image) async {
        if (_processing) return;
        _processing = true;
        final result = await _faceService.generateEmbeddingFromCameraImage(
          image,
          _controller!.description.sensorOrientation,
        );
        if (result == null) {
          if (mounted) {
            setState(() {
              _status = 'Wajah belum terdeteksi, sejajarkan wajah';
              _lastFaceRect = null;
              _lastImageSize = null;
            });
          }
          _processing = false;
          return;
        }
        if (mounted) {
          setState(() {
            _lastFaceRect = result.face.boundingBox;
            _lastImageSize = result.imageSize;
          });
        }
        await _controller!.stopImageStream();
        _streaming = false;
        if (!mounted) return;
        if (widget.autoCloseOnCapture) {
          Navigator.of(context).pop(result.embedding);
        } else {
          widget.onEmbedding?.call(result.embedding);
          // restart capture untuk percobaan berikutnya
          _processing = false;
          Future.delayed(const Duration(milliseconds: 120), _startCapture);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal menangkap wajah: $e');
    } finally {
      _processing = false;
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
            Text(
              'Verifikasi Wajah',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Tutup'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: ready ? _startCapture : null,
                  child: const Text('Coba Lagi'),
                ),
              ],
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
        aspectRatio: 1, // ✅ selalu kotak
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover, // ✅ jaga proporsi (tidak gepeng)
                child: SizedBox(
                  // previewSize biasanya landscape → dibalik
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
