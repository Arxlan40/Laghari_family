import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/services/app_version_service.dart';

void main() {
  group('SemanticVersion Comparison Tests', () {
    test('Correctly compares semantic versions (1.0.9 < 1.0.10)', () {
      final v109 = SemanticVersion.parse('1.0.9');
      final v1010 = SemanticVersion.parse('1.0.10');

      expect(v109 < v1010, isTrue);
      expect(v1010 > v109, isTrue);
      expect(v109 == v1010, isFalse);
    });

    test('Correctly compares semantic versions (1.0.10 < 1.0.11)', () {
      final v1010 = SemanticVersion.parse('1.0.10');
      final v1011 = SemanticVersion.parse('1.0.11');

      expect(v1010 < v1011, isTrue);
      expect(v1011 > v1010, isTrue);
    });

    test('Correctly compares semantic versions (1.1.0 > 1.0.9)', () {
      final v110 = SemanticVersion.parse('1.1.0');
      final v109 = SemanticVersion.parse('1.0.9');

      expect(v110 > v109, isTrue);
      expect(v109 < v110, isTrue);
    });

    test('Handles identical versions', () {
      final v1 = SemanticVersion.parse('1.0.0');
      final v2 = SemanticVersion.parse('1.0.0');

      expect(v1 == v2, isTrue);
      expect(v1 <= v2, isTrue);
      expect(v1 >= v2, isTrue);
      expect(v1 < v2, isFalse);
      expect(v1 > v2, isFalse);
    });

    test('Handles leading "v" or "V" in version strings', () {
      final vWithPrefix = SemanticVersion.parse('v1.0.5');
      final vWithoutPrefix = SemanticVersion.parse('1.0.5');

      expect(vWithPrefix == vWithoutPrefix, isTrue);
    });

    test('Handles build numbers separated by "+"', () {
      final vBuild1 = SemanticVersion.parse('1.0.0+1');
      final vBuild2 = SemanticVersion.parse('1.0.0+2');

      expect(vBuild1 < vBuild2, isTrue);
      expect(vBuild2 > vBuild1, isTrue);
    });

    test('Handles pre-release suffixes (e.g. -beta, -rc.1)', () {
      final vRelease = SemanticVersion.parse('1.0.0');
      final vBeta = SemanticVersion.parse('1.0.0-beta');

      expect(vBeta.major, 1);
      expect(vBeta.minor, 0);
      expect(vBeta.patch, 0);
      expect(vBeta == vRelease, isTrue);
    });

    test('Handles empty or invalid versions gracefully', () {
      final vEmpty = SemanticVersion.parse('');
      expect(vEmpty.major, 0);
      expect(vEmpty.minor, 0);
      expect(vEmpty.patch, 0);

      final vInvalid = SemanticVersion.parse('invalid');
      expect(vInvalid.major, 0);
      expect(vInvalid.minor, 0);
      expect(vInvalid.patch, 0);
    });
  });

  group('RemoteVersionInfo Tests', () {
    test('Parses camelCase and snake_case Firestore documents correctly', () {
      final json1 = {
        'latestVersion': '1.0.2',
        'downloadUrl': 'https://example.com/app-release.apk',
        'forceUpdate': false,
        'releaseNotes': 'New features and bug fixes',
      };
      final info1 = RemoteVersionInfo.fromMap(json1);
      expect(info1.latestVersion, '1.0.2');
      expect(info1.downloadUrl, 'https://example.com/app-release.apk');
      expect(info1.forceUpdate, isFalse);
      expect(info1.releaseNotes, 'New features and bug fixes');
      expect(info1.isValid, isTrue);

      final json2 = {
        'latest_version': '1.1.0',
        'download_url': 'https://example.com/app-v1.1.apk',
        'force_update': true,
      };
      final info2 = RemoteVersionInfo.fromMap(json2);
      expect(info2.latestVersion, '1.1.0');
      expect(info2.downloadUrl, 'https://example.com/app-v1.1.apk');
      expect(info2.forceUpdate, isTrue);
      expect(info2.isValid, isTrue);
    });

    test('Flags invalid version document when required fields are missing', () {
      final invalid1 = RemoteVersionInfo.fromMap({});
      expect(invalid1.isValid, isFalse);

      final invalid2 = RemoteVersionInfo.fromMap({'latestVersion': '1.0.0'});
      expect(invalid2.isValid, isFalse);

      final invalid3 = RemoteVersionInfo.fromMap({'downloadUrl': 'https://example.com'});
      expect(invalid3.isValid, isFalse);
    });
  });
}
