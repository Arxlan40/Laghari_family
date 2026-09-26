import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  FirebaseAuth? auth;
  FirebaseFirestore? firestore;
  try {
    auth = FirebaseAuth.instance;
  } catch (_) {}
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return AuthRepository(auth, firestore);
});

final currentUserStreamProvider = StreamProvider<UserModel?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchCurrentUser();
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(currentUserStreamProvider).valueOrNull;
});

final adminUsersFutureProvider = FutureProvider<List<UserModel>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getAdminUsers();
});

final userProfileFutureProvider =
    FutureProvider.family<UserModel?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  return ref.read(authRepositoryProvider).getUserProfile(uid);
});

