import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/vpn_controller.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'widgets/orientation_gate.dart';

/// Camera screen that scans a QR code and pops itself with the decoded
/// payload. Pops `null` if the user backs out without scanning.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.controller});

  /// Optional — used by the [OrientationGate] to pop the route when
  /// the device rotates into landscape while in auto-rotate mode (QR
  /// scanning has no TV variant, so we hand the user back to home).
  final VpnController? controller;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      _handled = true;
      Navigator.of(context).pop<String>(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scaffold = _buildScaffold(context, l);
    final controller = widget.controller;
    if (controller == null) return scaffold;
    return OrientationGate(controller: controller, child: scaffold);
  }

  Widget _buildScaffold(BuildContext context, AppLocalizations l) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          l.qrScanTitle,
          style: VoidType.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Colors.white,
          ),
        ),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final isOn = state.torchState == TorchState.on;
              return IconButton(
                tooltip: isOn ? l.qrFlashlightOff : l.qrFlashlightOn,
                onPressed: () => _scannerController.toggleTorch(),
                icon: Icon(
                  isOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
              );
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: _onDetect,
        errorBuilder: (context, error) => _ScannerError(
          error: error,
          onRetry: () => _scannerController.start(),
        ),
        overlayBuilder: (context, constraints) =>
            IgnorePointer(child: _ScannerViewport()),
      ),
    );
  }
}

class _ScannerViewport extends StatelessWidget {
  const _ScannerViewport();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _ViewportPainter()),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset + 48,
          child: Center(
            child: Text(
              l.qrScanAlignHint,
              style: VoidType.mono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewportPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide * 0.72;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: shortest,
      height: shortest,
    );

    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    final overlay = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final cornerLength = shortest * 0.1;

    void drawCorner(Offset anchor, double dx, double dy) {
      canvas.drawLine(
        anchor,
        anchor.translate(dx * cornerLength, 0),
        cornerPaint,
      );
      canvas.drawLine(
        anchor,
        anchor.translate(0, dy * cornerLength),
        cornerPaint,
      );
    }

    drawCorner(rect.topLeft, 1, 1);
    drawCorner(rect.topRight, -1, 1);
    drawCorner(rect.bottomLeft, 1, -1);
    drawCorner(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ViewportPainter oldDelegate) => false;
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final code = error.errorCode;
    final isPermission = code == MobileScannerErrorCode.permissionDenied;
    final isUnsupported = code == MobileScannerErrorCode.unsupported;

    final String message;
    if (isPermission) {
      message = l.qrPermissionMessage;
    } else if (isUnsupported) {
      message = l.qrUnsupportedMessage;
    } else {
      final detail = error.errorDetails?.message;
      message = detail == null || detail.isEmpty
          ? l.qrCameraFailedCode(code.name)
          : l.qrCameraFailedDetail(detail);
    }

    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography, size: 56, color: Colors.white70),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 24),
            if (!isUnsupported)
              FilledButton(onPressed: () => onRetry(), child: Text(l.retry)),
          ],
        ),
      ),
    );
  }
}
