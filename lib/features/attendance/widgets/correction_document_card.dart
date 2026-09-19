import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/features/attendance/widgets/correction_document_modal.dart';

/// Supporting proof & document card, mirroring `CorrectionDocumentCard.jsx` from Attendance-Web.
class CorrectionDocumentCard extends StatelessWidget {
  final String? attachmentUrl;
  final String? fileName;
  final int? fileSize;
  final bool isDark;

  const CorrectionDocumentCard({
    super.key,
    required this.attachmentUrl,
    this.fileName,
    this.fileSize,
    required this.isDark,
  });

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

  bool _isImageFile(String ext) {
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg'].contains(ext);
  }

  String _extractFileName(String url) {
    try {
      final clean = url.split('?').first;
      final segments = clean.split('/');
      if (segments.isNotEmpty && segments.last.isNotEmpty) {
        return segments.last;
      }
    } catch (_) {}
    return 'Attached Document';
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = attachmentUrl?.trim();
    final hasAttachment = rawUrl != null && rawUrl.isNotEmpty;

    final cardBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    if (!hasAttachment) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.attachment_rounded,
              size: 16,
              color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              'No supporting document or proof attached',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    final fullUrl = _resolveFullUrl(rawUrl);
    final ext = _getFileExtension(fullUrl);
    final isImage = _isImageFile(ext);
    final isPdf = ext == 'pdf';
    final isDoc = ['doc', 'docx'].contains(ext);
    final isSheet = ['xls', 'xlsx', 'csv'].contains(ext);

    final resolvedFileName = fileName ?? _extractFileName(fullUrl);
    final badgeLabel = ext.isNotEmpty ? ext.toUpperCase() : 'FILE';

    final badgeColor = isImage
        ? const Color(0xFF6366F1)
        : (isPdf
            ? const Color(0xFFEF4444)
            : (isDoc ? const Color(0xFF3B82F6) : const Color(0xFF10B981)));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isImage
                      ? Icons.image_outlined
                      : (isPdf
                          ? Icons.picture_as_pdf_outlined
                          : (isDoc ? Icons.description_outlined : Icons.insert_drive_file_outlined)),
                  size: 14,
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Supporting Proof / Attachment',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  badgeLabel,
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // File Card Content
          Row(
            children: [
              // Thumbnail or Icon Box
              GestureDetector(
                onTap: () {
                  CorrectionDocumentModal.show(
                    context,
                    url: fullUrl,
                    fileName: resolvedFileName,
                    fileSize: fileSize,
                  );
                },
                child: isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: fullUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 52,
                            height: 52,
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 52,
                            height: 52,
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                            child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                        ),
                        child: Center(
                          child: Icon(
                            isPdf
                                ? Icons.picture_as_pdf
                                : (isDoc ? Icons.article : (isSheet ? Icons.table_chart : Icons.insert_drive_file)),
                            color: badgeColor,
                            size: 24,
                          ),
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              // File Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedFileName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          isImage ? 'Image Proof' : (isPdf ? 'PDF Document' : 'Document'),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                        if (fileSize != null && fileSize! > 0) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            fileSize! < 1024 * 1024
                                ? '${(fileSize! / 1024).toStringAsFixed(1)} KB'
                                : '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB',
                            style: GoogleFonts.robotoMono(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // View / Open Button triggers rich CorrectionDocumentModal
              InkWell(
                onTap: () {
                  CorrectionDocumentModal.show(
                    context,
                    url: fullUrl,
                    fileName: resolvedFileName,
                    fileSize: fileSize,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isImage ? Icons.visibility_outlined : Icons.open_in_new_rounded,
                        size: 13,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Preview',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
