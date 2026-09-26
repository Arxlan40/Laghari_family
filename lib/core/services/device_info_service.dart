import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/providers/auth_provider.dart';

class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  /// Collects available device and application information.
  /// If location is not provided, checks if location permission is already granted;
  /// if granted, fetches coordinates; otherwise marks permissionStatus accordingly.
  static Future<UserDeviceInfo> collectDeviceInfo({UserLocationInfo? location}) async {
    String platform = 'unknown';
    String manufacturer = '';
    String model = '';
    String deviceName = '';
    String operatingSystem = '';
    String operatingSystemVersion = '';
    bool? isPhysicalDevice;
    final Map<String, dynamic> extraDetails = {};

    try {
      if (kIsWeb) {
        platform = 'Web';
        final webInfo = await _deviceInfoPlugin.webBrowserInfo;
        manufacturer = webInfo.vendor ?? 'Browser';
        model = webInfo.browserName.name;
        deviceName = webInfo.userAgent ?? 'Web Browser';
        operatingSystem = 'Web';
        operatingSystemVersion = webInfo.appVersion ?? '';
      } else if (Platform.isAndroid) {
        platform = 'Android';
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        manufacturer = androidInfo.manufacturer;
        model = androidInfo.model;
        deviceName = androidInfo.device;
        operatingSystem = 'Android';
        operatingSystemVersion = androidInfo.version.release;
        isPhysicalDevice = androidInfo.isPhysicalDevice;
        extraDetails['brand'] = androidInfo.brand;
        extraDetails['sdkInt'] = androidInfo.version.sdkInt;
        extraDetails['hardware'] = androidInfo.hardware;
        extraDetails['product'] = androidInfo.product;
        extraDetails['supportedAbis'] = androidInfo.supportedAbis;
      } else if (Platform.isIOS) {
        platform = 'iOS';
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        manufacturer = 'Apple';
        model = iosInfo.model;
        deviceName = iosInfo.name;
        operatingSystem = 'iOS';
        operatingSystemVersion = iosInfo.systemVersion;
        isPhysicalDevice = iosInfo.isPhysicalDevice;
        extraDetails['systemName'] = iosInfo.systemName;
        extraDetails['localizedModel'] = iosInfo.localizedModel;
      } else if (Platform.isMacOS) {
        platform = 'macOS';
        final macInfo = await _deviceInfoPlugin.macOsInfo;
        manufacturer = 'Apple';
        model = macInfo.model;
        deviceName = macInfo.computerName;
        operatingSystem = 'macOS';
        operatingSystemVersion = '${macInfo.majorVersion}.${macInfo.minorVersion}';
      } else if (Platform.isWindows) {
        platform = 'Windows';
        final winInfo = await _deviceInfoPlugin.windowsInfo;
        manufacturer = '';
        model = winInfo.productName;
        deviceName = winInfo.computerName;
        operatingSystem = 'Windows';
        operatingSystemVersion = winInfo.displayVersion;
      } else if (Platform.isLinux) {
        platform = 'Linux';
        final linuxInfo = await _deviceInfoPlugin.linuxInfo;
        manufacturer = '';
        model = linuxInfo.name;
        deviceName = linuxInfo.prettyName;
        operatingSystem = 'Linux';
        operatingSystemVersion = linuxInfo.versionId ?? '';
      }
    } catch (e) {
      debugPrint('Error collecting platform device info: $e');
    }

    String appVersion = '1.0.0';
    String buildNumber = '1';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    } catch (e) {
      debugPrint('Error getting package info: $e');
    }

    // Determine location if not explicitly provided
    UserLocationInfo resolvedLocation = location ?? await _checkExistingLocation();

    return UserDeviceInfo(
      platform: platform,
      manufacturer: manufacturer,
      model: model,
      deviceName: deviceName,
      operatingSystem: operatingSystem,
      operatingSystemVersion: operatingSystemVersion,
      appVersion: appVersion,
      buildNumber: buildNumber,
      isPhysicalDevice: isPhysicalDevice,
      collectedAt: DateTime.now(),
      location: resolvedLocation,
      extraDetails: extraDetails.isNotEmpty ? extraDetails : null,
    );
  }

  /// Checks if location permission has already been granted, and if so fetches location.
  /// Never prompts the user with permission requests unprompted.
  static Future<UserLocationInfo> _checkExistingLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const UserLocationInfo(permissionStatus: 'disabled');
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        return UserLocationInfo(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          altitude: position.altitude,
          speed: position.speed,
          heading: position.heading,
          timestamp: position.timestamp,
          permissionStatus: 'granted',
        );
      } else if (permission == LocationPermission.deniedForever) {
        return const UserLocationInfo(permissionStatus: 'deniedForever');
      } else {
        return const UserLocationInfo(permissionStatus: 'denied');
      }
    } catch (e) {
      debugPrint('Error reading existing location: $e');
      return const UserLocationInfo(permissionStatus: 'unavailable');
    }
  }

  /// Explicitly requests location permission from the user and fetches location if granted.
  /// Used during signup onboarding when the user taps "Allow".
  static Future<UserLocationInfo> requestLocationPermissionAndFetch() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const UserLocationInfo(permissionStatus: 'disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
          return UserLocationInfo(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            altitude: position.altitude,
            speed: position.speed,
            heading: position.heading,
            timestamp: position.timestamp,
            permissionStatus: 'granted',
          );
        } catch (_) {
          return const UserLocationInfo(permissionStatus: 'granted');
        }
      } else if (permission == LocationPermission.deniedForever) {
        return const UserLocationInfo(permissionStatus: 'deniedForever');
      } else {
        return const UserLocationInfo(permissionStatus: 'denied');
      }
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return const UserLocationInfo(permissionStatus: 'denied');
    }
  }

  /// Asynchronously syncs device info in the background on startup for authenticated users.
  /// Throttled to at most once per 24 hours unless app version changed.
  static Future<void> syncDeviceInfoInBackground(WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.uid.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('last_device_info_sync_${user.uid}');
      final lastVersion = prefs.getString('last_synced_app_version');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      if (lastSyncStr != null && lastVersion == currentVersion) {
        final lastSync = DateTime.tryParse(lastSyncStr);
        if (lastSync != null && DateTime.now().difference(lastSync).inHours < 24) {
          return; // Throttled: recently synced
        }
      }

      // Collect device info in background (respects existing location permissions without prompting)
      final deviceInfo = await collectDeviceInfo();

      // Write to Firestore asynchronously
      await ref.read(authRepositoryProvider).updateUserDeviceInfo(user.uid, deviceInfo);

      // Record last sync
      await prefs.setString('last_device_info_sync_${user.uid}', DateTime.now().toIso8601String());
      await prefs.setString('last_synced_app_version', currentVersion);
    } catch (e) {
      debugPrint('Background device info sync note: $e');
    }
  }

  static UserDeviceInfo? cachedDeviceInfo;

  /// Fetches device details and requests/reads location on splash screen.
  /// Times out gracefully so splash screen transition is never blocked.
  static Future<UserDeviceInfo> fetchDeviceDetailsAndLocationOnSplash() async {
    UserLocationInfo locationInfo;
    try {
      locationInfo = await requestLocationPermissionAndFetch().timeout(
        const Duration(seconds: 4),
        onTimeout: () => const UserLocationInfo(permissionStatus: 'timeout'),
      );
    } catch (_) {
      locationInfo = await _checkExistingLocation();
    }

    final devInfo = await collectDeviceInfo(location: locationInfo);
    cachedDeviceInfo = devInfo;
    return devInfo;
  }
}
