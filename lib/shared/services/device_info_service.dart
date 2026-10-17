import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Provides unique device fingerprinting and telemetry for auth transport contracts.
class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  static const String _kDeviceIdKey = 'mano_device_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  String _deviceId = '';
  String _deviceName = 'Mobile Device';
  String _appVersion = '1.0.0';
  bool _initialized = false;

  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  String get appVersion => _appVersion;

  /// Initializes device metadata once on startup. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. App Version from package_info_plus
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;

      // 2. Persistent Device ID
      String? savedId = await _storage.read(key: _kDeviceIdKey);
      if (savedId == null || savedId.isEmpty) {
        savedId = await _resolveHardwareOrUuidDeviceId();
        await _storage.write(key: _kDeviceIdKey, value: savedId);
      }
      _deviceId = savedId;

      // 3. Human-readable Device Name
      _deviceName = await _resolveDeviceName();
      _initialized = true;
    } catch (e) {
      debugPrint('DeviceInfoService initialization warning: $e');
      if (_deviceId.isEmpty) {
        _deviceId = 'mob_${const Uuid().v4()}';
      }
      _initialized = true;
    }
  }

  Future<String> _resolveHardwareOrUuidDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final hardwareId = androidInfo.id;
        final cleaned = hardwareId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
        if (cleaned.isNotEmpty && cleaned.length >= 4 && cleaned.toLowerCase() != 'unknown') {
          return 'and_$cleaned';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final idfv = iosInfo.identifierForVendor;
        if (idfv != null && idfv.isNotEmpty) {
          return 'ios_$idfv';
        }
      }
    } catch (e) {
      debugPrint('Hardware device ID resolution error: $e');
    }
    return 'mob_${const Uuid().v4()}';
  }

  Future<String> _resolveDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final brand = androidInfo.brand;
        final model = androidInfo.model;
        if (brand.isNotEmpty && model.isNotEmpty) {
          return '$brand $model';
        } else if (model.isNotEmpty) {
          return model;
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final model = iosInfo.utsname.machine;
        final name = iosInfo.name;
        return name.isNotEmpty ? name : (model.isNotEmpty ? model : 'Apple Device');
      }
    } catch (e) {
      debugPrint('Device name resolution error: $e');
    }
    return 'Mobile Device';
  }
}
