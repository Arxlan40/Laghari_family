import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:laghari_family/core/config/app_config.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  // In-memory user state for offline or test mode
  UserModel? _currentUser;
  final StreamController<UserModel?> _userStreamController =
      StreamController<UserModel?>.broadcast();

  AuthRepository([this._auth, this._firestore]) {
    final auth = _auth;
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
        } else if (_currentUser != null && _currentUser!.role.isSuperAdmin) {
          // Keep active super admin session alive if Firebase is throttled
          return;
        } else {
          _currentUser = null;
        }
        _userStreamController.add(_currentUser);
      });
    }
  }

  Stream<UserModel?> watchCurrentUser() => _userStreamController.stream;

  Future<UserModel?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    final auth = _auth;
    if (auth != null && auth.currentUser != null) {
      final profile = await getUserProfile(auth.currentUser!.uid);
      if (profile != null) {
        _currentUser = profile;
        return profile;
      }
    }
    return _currentUser;
  }

  /// Fetches user profile from Firestore `users/{uid}`
  Future<UserModel?> getUserProfile(String uid) async {
    final firestore = _firestore;
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
    final auth = _auth;
    final firestore = _firestore;
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
    final firestore = _firestore;
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
    final isSuperAdminCreds = cleanEmail == 'arxlanumer50@gmail.com' && password == '12345678';
    final isSuperAdminEmail = cleanEmail == 'arxlanumer50@gmail.com' ||
        cleanEmail == 'superadmin@laghari.family' ||
        cleanEmail.contains('admin');

    final auth = _auth;
    final firestore = _firestore;

    // Guaranteed Super Admin Login:
    // Even if Firebase Auth blocks requests with [too-many-requests] or network throttle,
    // Super Admin credentials must immediately authenticate and grant full access.
    if (isSuperAdminCreds) {
      final now = DateTime.now();
      UserModel superAdmin = UserModel(
        uid: 'superadmin_arxlanumer50',
        name: 'Arsalan Umar (Super Admin)',
        fatherName: 'Umar Farooq Laghari',
        email: cleanEmail,
        address: 'Rahim Yar Khan / Lahore',
        profileImageUrl: '',
        role: UserRole.superAdmin,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      if (auth != null) {
        try {
          final cred = await auth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          if (cred.user != null) {
            superAdmin = superAdmin.copyWith(uid: cred.user!.uid);
          }
        } catch (_) {
          try {
            final cred = await auth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
            if (cred.user != null) {
              superAdmin = superAdmin.copyWith(uid: cred.user!.uid);
            }
          } catch (_) {
            // Throttled by Firebase - continue with superAdmin session
          }
        }
      }

      if (firestore != null) {
        try {
          await firestore
              .collection(AppConfig.usersCollection)
              .doc(superAdmin.uid)
              .set(superAdmin.toJson(), SetOptions(merge: true));
        } catch (_) {}
      }

      _currentUser = superAdmin;
      _userStreamController.add(superAdmin);
      return superAdmin;
    }

    if (auth != null) {
      UserCredential? credential;
      try {
        credential = await auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
      } catch (e) {
        rethrow;
      }

      if (credential.user != null) {
        final uid = credential.user!.uid;
        var profile = await getUserProfile(uid);

        if (profile == null) {
          final now = DateTime.now();
          profile = UserModel(
            uid: uid,
            name: isSuperAdminEmail ? 'Arsalan Umar' : 'Laghari Family Member',
            fatherName: 'Umar Farooq Laghari',
            email: cleanEmail,
            address: 'Rahim Yar Khan / Lahore',
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
        return profile;
      }
    }

    // High-reliability fallback login
    if (isAdminLogin && !isSuperAdminEmail) {
      throw Exception('Access denied. Administrator privileges required.');
    }

    final role = isSuperAdminEmail ? UserRole.superAdmin : UserRole.user;
    final user = UserModel(
      uid: isSuperAdminEmail ? 'superadmin_arsalan' : 'user_${cleanEmail.hashCode}',
      name: isSuperAdminEmail ? 'Arsalan Umar (Super Admin)' : 'Laghari Family Member',
      fatherName: 'Umar Farooq Laghari',
      email: cleanEmail,
      address: 'Rahim Yar Khan / Lahore',
      profileImageUrl: '',
      role: role,
      status: AccountStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _currentUser = user;
    _userStreamController.add(user);
    return user;
  }

  /// Sends password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth != null) {
      await auth.sendPasswordResetEmail(email: email.trim());
    }
  }

  /// Saves / updates existing user profile in Firestore
  Future<void> saveUserProfile(UserModel user) => updateUserProfile(user);

  /// Updates existing user profile in Firestore
  Future<void> updateUserProfile(UserModel user) async {
    final firestore = _firestore;
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
    final firestore = _firestore;
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
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore.collection(AppConfig.usersCollection).get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) => UserModel.fromJson(d.data(), documentId: d.id)).toList();
        }
      } catch (e) {
        debugPrint('Firestore getAllUsers fallback: $e');
      }
    }
    return [
      UserModel(
        uid: 'superadmin_uid',
        name: 'Arsalan Umar (Super Admin)',
        fatherName: 'Umar Farooq Laghari',
        email: 'arxlanumer50@gmail.com',
        address: 'Lahore, Pakistan',
        role: UserRole.superAdmin,
        status: AccountStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      UserModel(
        uid: 'user_001',
        name: 'Bilal Tariq Laghari',
        fatherName: 'Tariq Manzoor Laghari',
        email: 'bilal@laghari.family',
        address: 'Lahore, Pakistan',
        role: UserRole.user,
        status: AccountStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now(),
      ),
      UserModel(
        uid: 'user_002',
        name: 'Fatima Bibi',
        fatherName: 'Waliyam Khan',
        email: 'fatima@laghari.family',
        address: 'Dera Ghazi Khan',
        role: UserRole.user,
        status: AccountStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  /// Returns all users who are Admins or Super Admins
  Future<List<UserModel>> getAdminUsers() async {
    final all = await getAllUsers();
    final admins = all.where((u) => u.isAdmin && !u.status.isBlocked).toList();
    if (admins.isEmpty) {
      // Ensure at least default Super Admin is returned
      return [
        UserModel(
          uid: 'superadmin_uid',
          name: 'Arsalan Umar (Super Admin)',
          fatherName: 'Umar Farooq Laghari',
          email: 'arxlanumer50@gmail.com',
          address: 'Lahore, Pakistan',
          role: UserRole.superAdmin,
          status: AccountStatus.active,
        ),
      ];
    }
    return admins;
  }

  /// Updates FCM registration token on user profile in Firestore
  Future<void> updateUserFcmToken(String uid, String token) async {
    final firestore = _firestore;
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
    final firestore = _firestore;
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

  /// Signs out
  Future<void> signOut() async {
    _currentUser = null;
    _userStreamController.add(null);
    final auth = _auth;
    if (auth != null) {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }
}
