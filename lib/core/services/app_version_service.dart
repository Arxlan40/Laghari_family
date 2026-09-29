import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// Proper Semantic Version parser and comparator.
/// Supports standard formats like `1.0.0`, `1.0.10+1`, `2.1.3-beta`.
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final int build;
  final String raw;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
    required this.raw,
  });

  factory SemanticVersion.parse(String versionStr) {
    final cleaned = versionStr.trim();
    if (cleaned.isEmpty) {
      return const SemanticVersion(major: 0, minor: 0, patch: 0, raw: '0.0.0');
    }

    // Strip leading 'v' or 'V' if present
    String v = cleaned;
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }

    // Split build number (separated by '+')
    int buildNum = 0;
    if (v.contains('+')) {
      final parts = v.split('+');
      v = parts[0];
      if (parts.length > 1) {
        buildNum = int.tryParse(parts[1]) ?? 0;
      }
    }

    // Strip any pre-release suffix (e.g. -beta, -rc.1)
    if (v.contains('-')) {
      v = v.split('-')[0];
    }

    final segments = v.split('.');
    final major = segments.isNotEmpty ? (int.tryParse(segments[0]) ?? 0) : 0;
    final minor = segments.length > 1 ? (int.tryParse(segments[1]) ?? 0) : 0;
    final patch = segments.length > 2 ? (int.tryParse(segments[2]) ?? 0) : 0;

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: buildNum,
      raw: cleaned,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (build != other.build) return build.compareTo(other.build);
    return 0;
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          build == other.build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => raw;
}

/// Remote version information fetched from Firestore.
class RemoteVersionInfo {
  final String latestVersion;
  final String downloadUrl;
  final bool forceUpdate;
  final String? releaseNotes;

  const RemoteVersionInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.forceUpdate = false,
    this.releaseNotes,
  });

  factory RemoteVersionInfo.fromMap(Map<String, dynamic> map) {
    return RemoteVersionInfo(
      latestVersion: (map['latestVersion'] ?? map['latest_version'] ?? '').toString().trim(),
      downloadUrl: (map['downloadUrl'] ?? map['download_url'] ?? '').toString().trim(),
      forceUpdate: map['forceUpdate'] == true || map['force_update'] == true,
      releaseNotes: (map['releaseNotes'] ?? map['release_notes'] ?? map['message'])?.toString(),
    );
  }

  bool get isValid => latestVersion.isNotEmpty && downloadUrl.isNotEmpty;
}

/// Download state during APK update.
enum DownloadStatus { idle, downloading, completed, error }

class DownloadProgress {
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final String? filePath;

  const DownloadProgress({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
    this.filePath,
  });
}

/// Manages application version checking, Firestore remote version, and platform updates.
class AppVersionService {
  final FirebaseFirestore? _firestore;

  // Session state to prevent annoying repeat popups
  static bool hasSkippedThisSession = false;

  AppVersionService([this._firestore]);

  /// Retrieves the local installed application version string (e.g. "1.0.0").
  Future<String> getLocalVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        return info.version;
      }
    } catch (e) {
      debugPrint('PackageInfo error: $e');
    }
    return AppConfig.appVersion;
  }

  /// Retrieves remote version info from Firestore:
  /// Primary doc: `app_config/version`
  /// Fallback doc: `settings/app`
  Future<RemoteVersionInfo?> getRemoteVersionInfo() async {
    final firestore = _firestore;
    if (firestore == null) return null;

    try {
      // 1. Try collection `app_config`, doc `version`
      final docSnap = await firestore
          .collection(AppConfig.appConfigCollection)
          .doc(AppConfig.versionDoc)
          .get();

      if (docSnap.exists && docSnap.data() != null) {
        final info = RemoteVersionInfo.fromMap(docSnap.data()!);
        if (info.isValid) return info;
      }

      // 2. Fallback check in `settings/app`
      final fallbackSnap = await firestore
          .collection(AppConfig.settingsCollection)
          .doc(AppConfig.appSettingsDoc)
          .get();

      if (fallbackSnap.exists && fallbackSnap.data() != null) {
        final data = fallbackSnap.data()!;
        if (data.containsKey('latestVersion') || data.containsKey('latest_version')) {
          final info = RemoteVersionInfo.fromMap(data);
          if (info.isValid) return info;
        }
      }
    } catch (e) {
      debugPrint('Error fetching version from Firestore: $e');
    }
    return null;
  }

  /// Checks if an update is available by comparing local vs remote semver.
  Future<({bool updateAvailable, String currentVersion, RemoteVersionInfo? remoteInfo})>
      checkForUpdate() async {
    // On web, updates are delivered automatically via web deployment; skip version checks
    if (kIsWeb) {
      return (
        updateAvailable: false,
        currentVersion: AppConfig.appVersion,
        remoteInfo: null,
      );
    }

    try {
      final currentVersion = await getLocalVersion();
      final remoteInfo = await getRemoteVersionInfo();

      if (remoteInfo == null || !remoteInfo.isValid) {
        return (
          updateAvailable: false,
          currentVersion: currentVersion,
          remoteInfo: null,
        );
      }

      final localSem = SemanticVersion.parse(currentVersion);
      final remoteSem = SemanticVersion.parse(remoteInfo.latestVersion);

      final updateAvailable = remoteSem > localSem;

      return (
        updateAvailable: updateAvailable,
        currentVersion: currentVersion,
        remoteInfo: remoteInfo,
      );
    } catch (e) {
      debugPrint('Version check error: $e');
      final currentVersion = await getLocalVersion();
      return (
        updateAvailable: false,
        currentVersion: currentVersion,
        remoteInfo: null,
      );
    }
  }

  /// Performs platform-specific update action:
  /// - Android: Downloads APK with progress callback and initiates package install via OpenFilex.
  /// - iOS: Opens App Store/TestFlight/distribution URL via url_launcher.
  /// - Web/Desktop: Opens download URL in browser/handler.
  Stream<DownloadProgress> downloadAndInstall({
    required String downloadUrl,
  }) async* {
    if (downloadUrl.trim().isEmpty) {
      yield const DownloadProgress(
        status: DownloadStatus.error,
        errorMessage: 'Download URL is missing or empty.',
      );
      return;
    }

    final uri = Uri.tryParse(downloadUrl.trim());
    if (uri == null) {
      yield const DownloadProgress(
        status: DownloadStatus.error,
        errorMessage: 'Invalid download URL format.',
      );
      return;
    }

    // iOS, Web, or non-Android platforms: open directly in browser or store
    if (kIsWeb || !Platform.isAndroid) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          yield const DownloadProgress(status: DownloadStatus.completed, progress: 1.0);
        } else {
          yield const DownloadProgress(
            status: DownloadStatus.error,
            errorMessage: 'Could not launch download URL.',
          );
        }
      } catch (e) {
        yield DownloadProgress(
          status: DownloadStatus.error,
          errorMessage: 'Error launching update: $e',
        );
      }
      return;
    }

    // Android APK download & install flow
    yield const DownloadProgress(status: DownloadStatus.downloading, progress: 0.05);

    try {
      final client = http.Client();
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield DownloadProgress(
          status: DownloadStatus.error,
          errorMessage: 'Server returned HTTP ${response.statusCode} while downloading update.',
        );
        return;
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final saveFile = File('${tempDir.path}/laghari_family_update.apk');
      if (await saveFile.exists()) {
        await saveFile.delete();
      }

      final sink = saveFile.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          final p = (received / contentLength).clamp(0.0, 1.0);
          yield DownloadProgress(status: DownloadStatus.downloading, progress: p);
        }
      }

      await sink.flush();
      await sink.close();

      yield DownloadProgress(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: saveFile.path,
      );

      // Trigger Android Package Installer
      final openResult = await OpenFilex.open(
        saveFile.path,
        type: 'application/vnd.android.package-archive',
      );

      if (openResult.type != ResultType.done) {
        // Fallback to opening URL in external browser if package installer intent fails
        debugPrint('OpenFilex result: ${openResult.message}. Falling back to browser.');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Download error: $e');
      // If direct APK download fails, fallback to launching downloadUrl in browser
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        yield const DownloadProgress(
          status: DownloadStatus.completed,
          progress: 1.0,
        );
      } catch (_) {
        yield DownloadProgress(
          status: DownloadStatus.error,
          errorMessage: 'Download failed: $e',
        );
      }
    }
  }
}

final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return AppVersionService(firestore);
});

final currentAppVersionProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(appVersionServiceProvider);
  return service.getLocalVersion();
});
