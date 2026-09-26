import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/storage/services/supabase_storage_service.dart';

void main() {
  group('SupabaseStorageService Validation Tests', () {
    late SupabaseStorageService service;

    setUp(() {
      service = SupabaseStorageService();
    });

    test('Accepts valid JPG image under 5MB', () {
      final dummyBytes = Uint8List(1024 * 50); // 50 KB
      final result = service.validateImage(bytes: dummyBytes, fileExtension: 'jpg');
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Accepts valid PNG image with leading dot extension', () {
      final dummyBytes = Uint8List(1024 * 100); // 100 KB
      final result = service.validateImage(bytes: dummyBytes, fileExtension: '.png');
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Accepts valid WebP image', () {
      final dummyBytes = Uint8List(1024 * 20); // 20 KB
      final result = service.validateImage(bytes: dummyBytes, fileExtension: 'webp');
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Rejects empty image bytes', () {
      final result = service.validateImage(bytes: Uint8List(0), fileExtension: 'jpg');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('empty or corrupted'));
    });

    test('Rejects image exceeding 5MB limit', () {
      final largeBytes = Uint8List(6 * 1024 * 1024); // 6 MB
      final result = service.validateImage(bytes: largeBytes, fileExtension: 'jpg');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('too large'));
      expect(result.errorMessage, contains('Maximum allowed size is 5MB'));
    });

    test('Rejects unsupported file format (.exe, .pdf, .txt)', () {
      final dummyBytes = Uint8List(1024);
      final pdfResult = service.validateImage(bytes: dummyBytes, fileExtension: 'pdf');
      expect(pdfResult.isValid, isFalse);
      expect(pdfResult.errorMessage, contains('Unsupported image format'));

      final exeResult = service.validateImage(bytes: dummyBytes, fileExtension: '.exe');
      expect(exeResult.isValid, isFalse);

      final txtResult = service.validateImage(bytes: dummyBytes, fileExtension: 'txt');
      expect(txtResult.isValid, isFalse);
    });

    test('Converts bytes to valid base64 data URI', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final uri = service.bytesToDataUri(dummyBytes, fileExtension: 'png');
      expect(uri.startsWith('data:image/png;base64,'), isTrue);
    });
  });
}
