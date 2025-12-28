import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Menangani alur: Camera → Face Detection (ML Kit) → Crop+Resize → MobileFaceNet embedding.
/// Dibuat singleton supaya interpreter TFLite tidak berkali-kali diinisialisasi
/// (menghindari crash native saat dispose cepat).
class FaceRecognitionService {
  FaceRecognitionService._internal();
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;

  static const _modelAsset = 'assets/models/mobilefacenet.tflite';
  static const _inputImageSize = 112; // MobileFaceNet default input
  static const _embeddingSize = 192; // Output vektor embedding

  Interpreter? _interpreter;
  FaceDetector? _faceDetector;
  bool _warmedUp = false;

  bool _isRunning = false;

  bool get isReady => _interpreter != null && _faceDetector != null;

  Future<void> init() async {
    _faceDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableLandmarks: true,
        minFaceSize: 0.3,
      ),
    );

    if (_interpreter == null) {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(_modelAsset, options: options);
      _interpreter!.allocateTensors();
      await _warmUpModel();
    }
  }

  /// Pastikan interpreter & detector sudah siap dan sudah di-warmup.
  Future<void> warmUp() async {
    await init();
    await _warmUpModel();
  }

  Future<void> dispose() async {
    // Biarkan interpreter & faceDetector hidup agar tidak perlu warmup ulang.
  }

  Future<void> _warmUpModel() async {
    if (_warmedUp || _interpreter == null) return;
    // Input dummy bentuk [1,112,112,3] terisi nol untuk alokasi awal.
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputImageSize,
        (_) => List.generate(
          _inputImageSize,
          (_) => [0.0, 0.0, 0.0],
        ),
      ),
    );
    final output = List.generate(1, (_) => List.filled(_embeddingSize, 0.0));
    try {
      _interpreter!.run(input, output);
      _warmedUp = true;
    } catch (e) {
      debugPrint('[FaceRecognitionService] warmup failed: $e');
    }
  }

  /// Helper setup camera dengan resolusi medium & format YUV420.
  Future<CameraController> createCameraController(
    CameraDescription description,
  ) async {
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    return controller;
  }

  /// Jalankan pipeline di 1 frame CameraImage. Kembalikan embedding bila wajah terdeteksi.
  Future<FaceEmbeddingResult?> generateEmbeddingFromCameraImage(
    CameraImage image,
    int sensorOrientation,
  ) async {
    if (_isRunning) return null; // hindari overlap frame
    _isRunning = true;
    try {
      if (!isReady) await init();

      final rotation = _rotationFromDegrees(sensorOrientation);
      final inputImage = _inputImageFromCameraImage(image, rotation);

      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isEmpty) return null;
      final targetFace = faces.first;
      final rotatedSize = (rotation == InputImageRotation.rotation90deg ||
              rotation == InputImageRotation.rotation270deg)
          ? ui.Size(image.height.toDouble(), image.width.toDouble())
          : ui.Size(image.width.toDouble(), image.height.toDouble());

      final rgb = _convertCameraImage(image);
      final oriented = _applyRotation(rgb, rotation);
      final cropped = _cropFace(oriented, targetFace.boundingBox);
      if (cropped == null) return null;

      final embedding = _runMobileFaceNet(cropped);
      return FaceEmbeddingResult(
        embedding: embedding,
        face: targetFace,
        imageSize: rotatedSize,
        capturedAt: DateTime.now(),
      );
    } catch (e, s) {
      debugPrint('[FaceRecognitionService] error: $e\n$s');
      return null;
    } finally {
      _isRunning = false;
    }
  }

  /// Konversi CameraImage (YUV420) menjadi InputImage untuk ML Kit.
  InputImage _inputImageFromCameraImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    final bytes = _yuv420ToNv21(image);
    // ML Kit lebih stabil dengan NV21 pada Android
    final format = InputImageFormat.nv21;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// Konversi YUV420 → RGB (img package) agar bisa di-crop & resize.
  img.Image _convertCameraImage(CameraImage image) {
    final plane0 = image.planes[0];
    final plane1 = image.planes[1];
    final plane2 = image.planes[2];
    final uvPixelStride = plane1.bytesPerPixel ?? 1;

    final width = image.width;
    final height = image.height;
    final imgImage = img.Image(width, height);

    // Rumus konversi YUV420 → RGB, mengikuti sample resmi camera plugin.
    for (int y = 0; y < height; y++) {
      final uvRow = plane1.bytesPerRow * (y >> 1);
      for (int x = 0; x < width; x++) {
        final uvIndex = uvRow + (x >> 1) * uvPixelStride;
        final yVal = plane0.bytes[y * plane0.bytesPerRow + x];
        final uVal = plane1.bytes[uvIndex];
        final vVal = plane2.bytes[uvIndex];

        final r = (yVal + vVal * 1.402 - 179.456).clamp(0, 255).toInt();
        final g = (yVal - uVal * 0.344136 - vVal * 0.714136 + 135.45984)
            .clamp(0, 255)
            .toInt();
        final b = (yVal + uVal * 1.772 - 226.816).clamp(0, 255).toInt();

        imgImage.setPixelRgba(x, y, r, g, b);
      }
    }
    return imgImage;
  }

  img.Image _applyRotation(img.Image image, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return img.copyRotate(image, 90);
      case InputImageRotation.rotation180deg:
        return img.copyRotate(image, 180);
      case InputImageRotation.rotation270deg:
        return img.copyRotate(image, -90);
      case InputImageRotation.rotation0deg:
      default:
        return image;
    }
  }

  img.Image? _cropFace(img.Image image, ui.Rect boundingBox) {
    final x = boundingBox.left.clamp(0, image.width.toDouble()).toInt();
    final y = boundingBox.top.clamp(0, image.height.toDouble()).toInt();
    final w = boundingBox.width.clamp(0, image.width - x.toDouble()).toInt();
    final h = boundingBox.height.clamp(0, image.height - y.toDouble()).toInt();
    if (w == 0 || h == 0) return null;

    final cropped = img.copyCrop(image, x, y, w, h);
    return img.copyResize(
      cropped,
      width: _inputImageSize,
      height: _inputImageSize,
      interpolation: img.Interpolation.linear,
    );
  }

  List<double> _runMobileFaceNet(img.Image faceImage) {
    final flat = _imageToFloat32(faceImage);

    // Bentuk input 4D [1, 112, 112, 3] sesuai model MobileFaceNet
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputImageSize,
        (y) => List.generate(
          _inputImageSize,
          (x) {
            final base = (y * _inputImageSize + x) * 3;
            return [
              flat[base],
              flat[base + 1],
              flat[base + 2],
            ];
          },
        ),
      ),
    );

    final output = List.generate(1, (_) => List.filled(_embeddingSize, 0.0));
    _interpreter!.run(input, output);
    return output.first;
  }

  Float32List _imageToFloat32(img.Image image) {
    final buffer = Float32List(_inputImageSize * _inputImageSize * 3);
    int index = 0;

    for (int y = 0; y < _inputImageSize; y++) {
      for (int x = 0; x < _inputImageSize; x++) {
        final pixel = image.getPixel(x, y);

        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);

        buffer[index++] = (r / 127.5) - 1.0;
        buffer[index++] = (g / 127.5) - 1.0;
        buffer[index++] = (b / 127.5) - 1.0;
      }
    }

    return buffer; // ✅ FIX
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final writeBuffer = WriteBuffer();
    for (final plane in planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    return writeBuffer.done().buffer.asUint8List();
  }

  /// Konversi YUV_420_888 ke NV21 (VU interleaved) untuk ML Kit.
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final nv21 = Uint8List(width * height * 3 ~/ 2);
    int offset = 0;

    // Y plane
    for (int y = 0; y < height; y++) {
      final start = y * image.planes[0].bytesPerRow;
      nv21.setRange(offset, offset + width,
          image.planes[0].bytes.sublist(start, start + width));
      offset += width;
    }

    // VU interleaved
    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    for (int y = 0; y < uvHeight; y++) {
      for (int x = 0; x < uvWidth; x++) {
        final uvIndex = y * uvRowStride + x * uvPixelStride;
        final u = image.planes[1].bytes[uvIndex];
        final v = image.planes[2].bytes[uvIndex];
        nv21[offset++] = v;
        nv21[offset++] = u;
      }
    }
    return nv21;
  }

  InputImageRotation _rotationFromDegrees(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}

class FaceEmbeddingResult {
  FaceEmbeddingResult({
    required this.embedding,
    required this.face,
    required this.imageSize,
    required this.capturedAt,
  });

  final List<double> embedding;
  final Face face;
  final ui.Size imageSize;
  final DateTime capturedAt;
}
