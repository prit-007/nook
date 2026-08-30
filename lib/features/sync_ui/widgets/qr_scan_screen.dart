import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'qr_frame_decoder.dart';

/// Camera scanning is available on the `camera` plugin's supported platforms.
/// Desktop (Windows, Linux, macOS) instead generates its own QR for the mobile
/// to scan. Web is excluded: the web camera plugin has no image-stream support,
/// and sync is UDP-based so it doesn't run in a browser anyway.
bool get qrCameraSupported {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}

/// Full-screen camera QR scanner. Pops with the scanned raw value when a
/// barcode is detected.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  CameraController? _controller;
  bool _handled = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    final cameras = await availableCameras();
    if (!mounted) return;
    CameraDescription? camera;
    for (final c in cameras) {
      if (c.lensDirection == CameraLensDirection.back) {
        camera = c;
        break;
      }
    }
    camera ??= cameras.firstOrNull;
    if (camera == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera available on this device.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the camera.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {});
    await controller.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) {
    if (_handled) return;
    final frame = QrCameraFrame(
      format: image.format.group == ImageFormatGroup.yuv420
          ? QrPixelFormat.yuv420
          : QrPixelFormat.bgra8888,
      width: image.width,
      height: image.height,
      planes: [
        for (final plane in image.planes)
          QrCameraPlane(bytes: plane.bytes, bytesPerRow: plane.bytesPerRow),
      ],
    );
    final value = decodeQrFromFrame(frame);
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final next = _torchOn ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(next);
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Torch is best-effort; ignore unsupported devices.
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      controller.stopImageStream();
    }
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!),
          // Overlay with scan window guide
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // Instruction text
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point camera at the receiver\'s QR code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
