import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// Supporting Proof Document Viewer Modal
/// Directly mirroring `CorrectionDocumentModal.jsx` from Attendance-Web.
class CorrectionDocumentModal extends StatefulWidget {
  final String url;
  final String? fileName;
  final int? fileSize;

  const CorrectionDocumentModal({
    super.key,
    required this.url,
    this.fileName,
    this.fileSize,
  });

  static Future<void> show(
    BuildContext context, {
    required String url,
    String? fileName,
    int? fileSize,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: true,
      builder: (context) => CorrectionDocumentModal(
        url: url,
        fileName: fileName,
        fileSize: fileSize,
      ),
    );
  }

  @override
  State<CorrectionDocumentModal> createState() => _CorrectionDocumentModalState();
}

class _CorrectionDocumentModalState extends State<CorrectionDocumentModal> {
  int _quarterTurns = 0;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  String _resolveFullUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '${ApiConstants.baseUrl}$path';
  }

  String _getFileExtension(String url) {
    try {
      final clean = url.split('?').first.toLowerCase();
      final dotIndex = clean.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < clean.length - 1) {
        return clean.substring(dotIndex + 1);
      }
    } catch (_) {}
    return '';
  }

  bool _isImage(String ext) {
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg'].contains(ext);
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openExternalFile(String fullUrl, String name) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = _getFileExtension(fullUrl);
      final safeName = name.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final targetPath = '${tempDir.path}${Platform.pathSeparator}$safeName${ext.isNotEmpty && !safeName.endsWith('.$ext') ? '.$ext' : ''}';

      final file = File(targetPath);
      if (!await file.exists()) {
        final dio = Dio();
        await dio.download(
          fullUrl,
          targetPath,
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
          },
        );
      }

      final result = await OpenFilex.open(targetPath);
      if (result.type != ResultType.done && mounted) {
        context.showToast('Could not open file: ${result.message}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        context.showToast('Failed to download or open: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final fullUrl = _resolveFullUrl(widget.url);
    final ext = _getFileExtension(fullUrl);
    final isImageFile = _isImage(ext);
    final isPdf = ext == 'pdf';
    final isDoc = ['doc', 'docx'].contains(ext);
    final isSheet = ['xls', 'xlsx', 'csv'].contains(ext);

    final resolvedName = widget.fileName ?? fullUrl.split('?').first.split('/').last;
    final formattedSize = _formatSize(widget.fileSize);

    final Color badgeColor = isImageFile
        ? const Color(0xFF6366F1)
        : (isPdf
            ? const Color(0xFFEF4444)
            : (isDoc ? const Color(0xFF3B82F6) : const Color(0xFF10B981)));

    final String typeLabel = isImageFile
        ? 'IMAGE PROOF'
        : (isPdf
            ? 'PDF DOCUMENT'
            : (isDoc ? 'WORD DOCUMENT' : (isSheet ? 'SPREADSHEET' : 'DOCUMENT')));

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: isTablet ? 32 : 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 720 : double.infinity,
            maxHeight: size.height * 0.86,
          ),
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Bar with File Metadata & Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isImageFile
                            ? Icons.image_rounded
                            : (isPdf
                                ? Icons.picture_as_pdf_rounded
                                : (isDoc ? Icons.article_rounded : Icons.insert_drive_file_rounded)),
                        color: badgeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                typeLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: badgeColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  ext.toUpperCase(),
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$resolvedName ${formattedSize.isNotEmpty ? '• $formattedSize' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Actions: Rotate (if image), Open/Download, Close
                    if (isImageFile)
                      IconButton(
                        tooltip: 'Rotate 90°',
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 18),
                        ),
                        onPressed: () {
                          setState(() {
                            _quarterTurns = (_quarterTurns + 1) % 4;
                          });
                        },
                      ),

                    IconButton(
                      tooltip: 'Open in external app',
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: _isDownloading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: _downloadProgress > 0 ? _downloadProgress : null,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                      ),
                      onPressed: _isDownloading ? null : () => _openExternalFile(fullUrl, resolvedName),
                    ),

                    const SizedBox(width: 4),

                    IconButton(
                      tooltip: 'Close preview',
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),

                // Main Viewer Body
                Flexible(
                  child: isImageFile
                      ? _buildImageViewer(fullUrl)
                      : _buildDocumentViewer(fullUrl, resolvedName, badgeColor, isPdf, isDoc, isSheet),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageViewer(String fullUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        width: double.infinity,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(
            child: RotatedBox(
              quarterTurns: _quarterTurns,
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
                errorWidget: (context, url, error) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_rounded, size: 48, color: Colors.white38),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load image proof',
                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentViewer(
    String fullUrl,
    String name,
    Color badgeColor,
    bool isPdf,
    bool isDoc,
    bool isSheet,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : (isDoc ? Icons.article_rounded : (isSheet ? Icons.table_chart_rounded : Icons.insert_drive_file_rounded)),
              size: 36,
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'This supporting proof is a ${isPdf ? "PDF Document" : "document file"}. Tap below to open and inspect with your default system application.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white60,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isDownloading ? null : () => _openExternalFile(fullUrl, name),
            style: ElevatedButton.styleFrom(
              backgroundColor: badgeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(
              _isDownloading
                  ? 'Downloading (${(_downloadProgress * 100).toInt()}%)...'
                  : 'Open Document',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
