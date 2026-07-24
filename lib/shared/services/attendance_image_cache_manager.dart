import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Singleton cache manager for attendance punch images.
///
/// Configuration:
///   - key: unique cache directory key ("attendance_images")
///   - stalePeriod: 30 days — images are served from disk for 30 days without
///     re-downloading even if the server returns a fresh response.
///   - maxNrOfCacheObjects: 500 — up to 500 images stored on disk.
///
/// Usage:
///   CachedNetworkImage(
///     imageUrl: url,
///     cacheManager: AttendanceImageCacheManager.instance,
///     ...
///   )
class AttendanceImageCacheManager {
  static const String _key = 'attendance_images';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: _key),
      fileService: HttpFileService(),
    ),
  );

  // Private constructor — never instantiate directly.
  AttendanceImageCacheManager._();
}
