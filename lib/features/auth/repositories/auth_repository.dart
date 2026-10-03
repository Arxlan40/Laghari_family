import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:laghari_family/core/config/app_config.dart';
import 'package:laghari_family/core/config/firebase_options.dart';
import 'package:laghari_family/core/services/crashlytics_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth? get activeAuth {
    if (_auth != null) return _auth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get activeFirestore {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // In-memory user state for offline or test mode
  UserModel? _currentUser;
  final StreamController<UserModel?> _userStreamController =
      StreamController<UserModel?>.broadcast();
  final Completer<void> _initialAuthCompleter = Completer<void>();
  bool _isInitialAuthResolved = false;

  AuthRepository([this._auth, this._firestore]) {
    final auth = activeAuth;
    if (auth != null) {
      auth.authStateChanges().listen((firebaseUser) async {
        if (firebaseUser != null) {
          try {
            final profile = await getUserProfile(firebaseUser.uid);
            _currentUser = profile ??
                UserModel(
                  uid: firebaseUser.uid,
                  name: firebaseUser.displayName ?? 'User',
                  email: firebaseUser.email ?? '',
                  fatherName: '',
                  address: '',
                  role: (firebaseUser.email?.toLowerCase().trim() ==
                          'arxlanumer50@gmail.com')
                      ? UserRole.superAdmin
                      : UserRole.user,
                  status: AccountStatus.active,
                );
          } catch (e) {
            debugPrint('Error getting user profile: $e');
          }
        } else {
          _currentUser = null;
        }

        if (!_isInitialAuthResolved) {
          _isInitialAuthResolved = true;
          if (!_initialAuthCompleter.isCompleted) {
            _initialAuthCompleter.complete();
          }
        }
        _userStreamController.add(_currentUser);
      }, onError: (e) {
        debugPrint('authStateChanges error: $e');
        if (!_isInitialAuthResolved) {
          _isInitialAuthResolved = true;
          if (!_initialAuthCompleter.isCompleted) {
            _initialAuthCompleter.complete();
          }
        }
      });

      // Safety timeout: If Firebase Auth takes longer than 6 seconds, resolve to unblock app
      Future.delayed(const Duration(seconds: 6), () {
        if (!_isInitialAuthResolved) {
          debugPrint('Auth initialization timeout: proceeding with current state');
          _isInitialAuthResolved = true;
          if (!_initialAuthCompleter.isCompleted) {
            _initialAuthCompleter.complete();
          }
        }
      });
    } else {
      _isInitialAuthResolved = true;
      if (!_initialAuthCompleter.isCompleted) {
        _initialAuthCompleter.complete();
      }
    }
  }

  Stream<UserModel?> watchCurrentUser() async* {
    if (!_isInitialAuthResolved) {
      await _initialAuthCompleter.future;
    }
    yield _currentUser;
    yield* _userStreamController.stream;
  }

  Future<UserModel?> getCurrentUser() async {
    if (!_isInitialAuthResolved) {
      await _initialAuthCompleter.future;
    }
    return _currentUser;
  }

  /// Fetches user profile from Firestore `users/{uid}`
  Future<UserModel?> getUserProfile(String uid) async {
    final firestore = activeFirestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection(AppConfig.usersCollection)
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          return UserModel.fromJson(doc.data()!, documentId: uid);
        }
      } catch (e) {
        debugPrint('Error getting user profile from Firestore: $e');
      }
    }
    return _currentUser?.uid == uid ? _currentUser : null;
  }

  /// Signs up with email, password, and required custom fields
  Future<UserModel> signUpWithEmail({
    required String name,
    required String fatherName,
    required String email,
    required String password,
    required String address,
    String phone = '',
    String profileImageUrl = '',
    UserRole role = UserRole.user,
    String bloodGroup = 'Unknown',
    String gender = 'Male',
    String profession = '',
    UserDeviceInfo? deviceInfo,
  }) async {
    final auth = activeAuth;
    final firestore = activeFirestore;
    if (auth != null) {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final now = DateTime.now();

      final userModel = UserModel(
        uid: uid,
        name: name.trim(),
        fatherName: fatherName.trim(),
        email: email.trim(),
        address: address.trim(),
        phone: phone.trim(),
        profileImageUrl: profileImageUrl.trim(),
        role: role,
        status: AccountStatus.active,
        bloodGroup: bloodGroup,
        gender: UserModel.normalizeGender(gender),
        profession: profession,
        createdAt: now,
        updatedAt: now,
        deviceInfo: deviceInfo,
      );

      if (firestore != null) {
        await firestore
            .collection(AppConfig.usersCollection)
            .doc(uid)
            .set(userModel.toJson());
      }

      CrashlyticsService.instance.log('User registered: role=${userModel.role.value}');
      CrashlyticsService.instance.setUserContext(uid: userModel.uid, role: userModel.role.value);

      _userStreamController.add(userModel);
      return userModel;
    } else {
      // Demo mock login
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        fatherName: fatherName,
        email: email,
        address: address,
        phone: phone,
        profileImageUrl: profileImageUrl,
        role: role,
        status: AccountStatus.active,
        bloodGroup: bloodGroup,
        gender: UserModel.normalizeGender(gender),
        profession: profession,
        createdAt: now,
        updatedAt: now,
        deviceInfo: deviceInfo,
      );
      _currentUser = user;
      _userStreamController.add(user);
      return user;
    }
  }

  /// Updates user device and location information in Firestore
  Future<void> updateUserDeviceInfo(String uid, UserDeviceInfo info) async {
    final firestore = activeFirestore;
    if (firestore != null && uid.isNotEmpty) {
      try {
        await firestore.collection(AppConfig.usersCollection).doc(uid).set({
          'deviceInfo': info.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating user device info: $e');
      }
    }
  }

  /// Signs in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
    bool isAdminLogin = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    var auth = activeAuth;
    final firestore = activeFirestore;

    if (auth == null) {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (_) {
          try {
            await Firebase.initializeApp();
          } catch (_) {}
        }
      }
      auth = activeAuth;
    }

    if (auth == null) {
      try {
        FirebaseAuth.instance;
      } catch (e) {
        throw Exception('Firebase Authentication failed to load ($e).');
      }
      throw Exception('Firebase Authentication is not available.');
    }

    // Authenticate with Firebase Authentication.
    // If the password or email is incorrect, this throws FirebaseAuthException and will NOT bypass.
    final credential = await auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    if (credential.user == null) {
      throw Exception('Authentication failed. No user record returned.');
    }

    final uid = credential.user!.uid;
    var profile = await getUserProfile(uid);

    final isSuperAdminEmail = cleanEmail == 'arxlanumer50@gmail.com' ||
        cleanEmail == 'superadmin@laghari.family';

    if (profile == null) {
      final now = DateTime.now();
      profile = UserModel(
        uid: uid,
        name: isSuperAdminEmail
            ? 'Arsalan Umar'
            : (credential.user!.displayName ?? 'Laghari Family Member'),
        fatherName: isSuperAdminEmail ? 'Umar Farooq Laghari' : '',
        email: cleanEmail,
        address: '',
        profileImageUrl: '',
        role: isSuperAdminEmail ? UserRole.superAdmin : UserRole.user,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      if (firestore != null) {
        await firestore
            .collection(AppConfig.usersCollection)
            .doc(uid)
            .set(profile.toJson(), SetOptions(merge: true));
      }
    }

    if (profile.isBlocked) {
      await auth.signOut();
      throw Exception('Your account has been suspended. Please contact administrator.');
    }

    if (isAdminLogin && !profile.isAdmin) {
      await auth.signOut();
      throw Exception('Access denied. Administrator privileges required.');
    }

    _currentUser = profile;
    _userStreamController.add(profile);

    CrashlyticsService.instance.log('User signed in: role=${profile.role.value}');
    CrashlyticsService.instance.setUserContext(uid: profile.uid, role: profile.role.value);

    return profile;
  }

  /// Sends password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = activeAuth;
    if (auth != null) {
      await auth.sendPasswordResetEmail(email: email.trim());
    }
  }

  /// Saves / updates existing user profile in Firestore
  Future<void> saveUserProfile(UserModel user) => updateUserProfile(user);

  /// Updates existing user profile in Firestore
  Future<void> updateUserProfile(UserModel user) async {
    final firestore = activeFirestore;
    if (firestore != null) {
      await firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .set(user.toJson(), SetOptions(merge: true));
    }
    if (_currentUser?.uid == user.uid) {
      _currentUser = user;
    }
    _userStreamController.add(user);
  }

  /// Super Admin: Updates any user's role or status
  Future<void> setRoleAndStatus({
    required String uid,
    required UserRole role,
    required AccountStatus status,
  }) async {
    final firestore = activeFirestore;
    if (firestore != null) {
      await firestore.collection(AppConfig.usersCollection).doc(uid).update({
        'role': role.value,
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Super Admin: Lists all users
  Future<List<UserModel>> getAllUsers() async {
    final firestore = activeFirestore;
    if (firestore != null) {
      try {
        final snap = await firestore.collection(AppConfig.usersCollection).get();
        if (snap.docs.isNotEmpty) {
          return snap.docs
              .map((d) => UserModel.fromJson(d.data(), documentId: d.id))
              .toList();
        }
      } catch (e) {
        debugPrint('Firestore getAllUsers error: $e');
      }
    }
    return [];
  }

  /// Returns all users who are Admins or Super Admins
  Future<List<UserModel>> getAdminUsers() async {
    final all = await getAllUsers();
    return all.where((u) => u.isAdmin && !u.status.isBlocked).toList();
  }

  /// Updates FCM registration token on user profile in Firestore
  Future<void> updateUserFcmToken(String uid, String token) async {
    final firestore = activeFirestore;
    if (firestore != null && uid.isNotEmpty && token.isNotEmpty) {
      try {
        await firestore.collection(AppConfig.usersCollection).doc(uid).set({
          'fcm_token': token,
          'fcm_tokens': FieldValue.arrayUnion([token]),
          'fcm_updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating FCM token in Firestore: $e');
      }
    }
  }

  /// Permanently deletes a user document from Firestore
  Future<void> deleteUserPermanently(String uid) async {
    final firestore = activeFirestore;
    if (firestore != null && uid.isNotEmpty) {
      try {
        await firestore.collection(AppConfig.usersCollection).doc(uid).delete();
        debugPrint('Successfully deleted user $uid permanently from Firestore.');
      } catch (e) {
        debugPrint('Error deleting user $uid from Firestore: $e');
        rethrow;
      }
    }
  }

  /// Updates user password with Firebase Authentication including re-authentication
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final auth = activeAuth;
    if (auth == null || auth.currentUser == null) {
      throw Exception('User is not currently authenticated.');
    }

    final fbUser = auth.currentUser!;
    final email = fbUser.email;
    if (email == null || email.isEmpty) {
      throw Exception('User email not found for authentication.');
    }

    try {
      // 1. Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);

      // 2. Update password in Firebase Auth
      await fbUser.updatePassword(newPassword);
      debugPrint('Password updated successfully in Firebase Auth for uid=${fbUser.uid}');
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during changePassword: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Current password is incorrect. Please check and try again.');
        case 'weak-password':
          throw Exception('The new password is too weak. Please use at least 6 characters.');
        case 'requires-recent-login':
          throw Exception('For security, please log out and log back in before changing your password.');
        case 'too-many-requests':
          throw Exception('Too many attempts. Please wait a few moments and try again.');
        default:
          throw Exception(e.message ?? 'Failed to change password. Please try again.');
      }
    } catch (e) {
      debugPrint('Error changing password: $e');
      rethrow;
    }
  }

  /// Performs Google Play compliant account deletion:
  /// 1. Re-authenticates the user with password
  /// 2. Deletes user-specific Firestore data (users/{uid}, notifications, device/location info)
  /// 3. Preserves historical family-tree records in family_members
  /// 4. Deletes the Firebase Authentication user account
  /// 5. Cleans up session and signs out
  Future<void> deleteUserAccount({required String password}) async {
    final auth = activeAuth;
    final firestore = activeFirestore;
    if (auth == null || auth.currentUser == null) {
      throw Exception('User is not currently authenticated.');
    }

    final fbUser = auth.currentUser!;
    final uid = fbUser.uid;
    final email = fbUser.email;

    if (email == null || email.isEmpty) {
      throw Exception('User email not found for authentication.');
    }

    try {
      // 1. Re-authenticate user with password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await fbUser.reauthenticateWithCredential(credential);

      // 2. Clean up user notifications from Firestore
      if (firestore != null) {
        try {
          final notifsSnap = await firestore
              .collection('notifications')
              .where('userId', isEqualTo: uid)
              .get();
          final batch = firestore.batch();
          for (final doc in notifsSnap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } catch (e) {
          debugPrint('Note: Error removing user notifications during account deletion: $e');
        }

        // 3. Remove user profile document from users collection (including device & location info)
        try {
          await firestore.collection(AppConfig.usersCollection).doc(uid).delete();
          debugPrint('User profile deleted from Firestore: $uid');
        } catch (e) {
          debugPrint('Note: Error deleting user document: $e');
        }
      }

      // 4. Delete the Firebase Authentication account
      await fbUser.delete();
      debugPrint('Firebase Authentication account deleted: $uid');

      // 5. Sign out & clear local memory state
      _currentUser = null;
      _userStreamController.add(null);
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during deleteUserAccount: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Incorrect password. Please verify your password to proceed with account deletion.');
        case 'requires-recent-login':
          throw Exception('For security, please log out and log back in before deleting your account.');
        default:
          throw Exception(e.message ?? 'Failed to delete account. Please try again.');
      }
    } catch (e) {
      debugPrint('Error deleting user account: $e');
      rethrow;
    }
  }

  /// Signs out
  Future<void> signOut() async {
    _currentUser = null;
    _userStreamController.add(null);
    CrashlyticsService.instance.log('User signed out');
    CrashlyticsService.instance.setUserContext(uid: null, role: null);

    final auth = activeAuth;
    if (auth != null) {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }
}

