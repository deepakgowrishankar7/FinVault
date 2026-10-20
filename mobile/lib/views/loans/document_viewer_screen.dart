import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/fin_theme.dart';

/// Full In-App PDF Viewer with interactive zoom gestures, page scrolling, and sharing
class FinPdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const FinPdfViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final file = File(filePath);
    final exists = file.existsSync();

    return Scaffold(
      backgroundColor: isDark ? FinTheme.bgDark : FinTheme.bgLight,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (exists)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: "Share Document",
              onPressed: () {
                Share.shareXFiles([XFile(filePath)], text: "FinVault Document: $title");
              },
            ),
        ],
      ),
      body: !exists
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      "File not found on device storage:\n$filePath",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : PdfPreview(
              build: (format) => file.readAsBytesSync(),
              pdfFileName: title,
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              maxPageWidth: 720,
              loadingWidget: const Center(child: CircularProgressIndicator()),
              onError: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: FinTheme.danger),
                      const SizedBox(height: 12),
                      Text(
                        "Could not render PDF preview in-app:\n$error",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text("Share / Open Externally"),
                        onPressed: () {
                          Share.shareXFiles([XFile(filePath)], text: "FinVault Document: $title");
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// In-App Image Viewer with pinch-to-zoom, pan gestures, double-tap zoom, zoom buttons, and share
class FinImageViewerDialog extends StatefulWidget {
  final String imagePath;
  final String title;

  const FinImageViewerDialog({
    super.key,
    required this.imagePath,
    required this.title,
  });

  static Future<void> show(BuildContext context, {required String imagePath, required String title}) {
    return showDialog(
      context: context,
      builder: (ctx) => FinImageViewerDialog(imagePath: imagePath, title: title),
    );
  }

  @override
  State<FinImageViewerDialog> createState() => _FinImageViewerDialogState();
}

class _FinImageViewerDialogState extends State<FinImageViewerDialog> {
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(Offset localPosition) {
    if (_currentScale > 1.05) {
      setState(() {
        _currentScale = 1.0;
        _transformController.value = Matrix4.identity();
      });
    } else {
      final zoomed = Matrix4.identity()
        ..translate(-localPosition.dx * 1.5, -localPosition.dy * 1.5)
        ..scale(2.5);
      setState(() {
        _currentScale = 2.5;
        _transformController.value = zoomed;
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale * 1.4).clamp(1.0, 6.0);
      _transformController.value = Matrix4.identity()..scale(_currentScale);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale / 1.4).clamp(1.0, 6.0);
      _transformController.value = Matrix4.identity()..scale(_currentScale);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final file = File(widget.imagePath);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.image, size: 20, color: FinTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: "Close",
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Gesture Interactive Zoom Area
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
                maxWidth: 720,
              ),
              color: Colors.black,
              child: GestureDetector(
                onDoubleTapDown: (details) => _handleDoubleTap(details.localPosition),
                child: InteractiveViewer(
                  transformationController: _transformController,
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.5,
                  maxScale: 6.0,
                  onInteractionEnd: (details) {
                    setState(() {
                      _currentScale = _transformController.value.getMaxScaleOnAxis();
                    });
                  },
                  child: Center(
                    child: file.existsSync()
                        ? Image.file(
                            file,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text("Could not render image file", style: TextStyle(color: Colors.white)),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text("Image file does not exist", style: TextStyle(color: Colors.white)),
                          ),
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Zoom toolbar and Share Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                // Zoom Controls
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 20),
                  tooltip: "Zoom Out",
                  onPressed: _zoomOut,
                ),
                InkWell(
                  onTap: _resetZoom,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${_currentScale.toStringAsFixed(1)}x",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 20),
                  tooltip: "Zoom In",
                  onPressed: _zoomIn,
                ),
                const Spacer(),

                // Share / Save Button
                ElevatedButton.icon(
                  onPressed: () {
                    if (file.existsSync()) {
                      Share.shareXFiles([XFile(widget.imagePath)], text: "FinVault Document: ${widget.title}");
                    }
                  },
                  icon: const Icon(Icons.share, size: 15),
                  label: const Text("Share / Save", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper method to present both In-App Viewing and Sharing for PDF or other documents
class FinDocumentHelper {
  static bool isImagePath(String pathOrName) {
    final lower = pathOrName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  static bool isPdfPath(String pathOrName) {
    return pathOrName.toLowerCase().endsWith('.pdf');
  }

  static String getDocDisplayName(String pathOrName) {
    final sep = pathOrName.contains('/') ? '/' : '\\';
    final name = pathOrName.split(sep).last;
    return name.replaceFirst(RegExp(r'^\d+_'), '');
  }

  static void openDocumentWithOptions(
    BuildContext context, {
    required String docPath,
    required String displayName,
  }) {
    if (isImagePath(docPath)) {
      FinImageViewerDialog.show(context, imagePath: docPath, title: displayName);
      return;
    }

    if (isPdfPath(docPath) || isPdfPath(displayName)) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showModalBottomSheet(
        context: context,
        backgroundColor: isDark ? const Color(0xFF1E2638) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              "Choose to view in-app or share document",
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FinTheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.visibility_outlined, color: FinTheme.primary),
                    ),
                    title: const Text("Open & View In-App", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Read PDF with zoom in/out gestures and full pages", style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FinPdfViewerScreen(
                            filePath: docPath,
                            title: displayName,
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, color: Colors.green),
                    ),
                    title: const Text("Share Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Send via WhatsApp, Drive, Bluetooth or other apps", style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.pop(ctx);
                      final file = File(docPath);
                      if (file.existsSync()) {
                        Share.shareXFiles([XFile(docPath)], text: "FinVault Document: $displayName");
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("File not found on storage: $displayName")),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    // Default for other file formats
    final file = File(docPath);
    if (file.existsSync()) {
      Share.shareXFiles([XFile(docPath)], text: "FinVault Document: $displayName");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File not found on storage: $displayName")),
      );
    }
  }
}
