import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/about/presentation/screens/about_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_tree_screen.dart';
import '../../features/admin/presentation/screens/admin_user_management_screen.dart';
import '../../features/admin/presentation/screens/audit_log_screen.dart';
import '../../features/admin/presentation/screens/json_export_import_screen.dart';
import '../../features/admin/presentation/screens/pending_requests_screen.dart';
import '../../features/auth/presentation/screens/admin_login_screen.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/my_profile_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/edit_requests/presentation/screens/request_add_child_screen.dart';
import '../../features/edit_requests/presentation/screens/submit_edit_request_screen.dart';
import '../../features/family_tree/presentation/screens/family_members_screen.dart';
import '../../features/family_tree/presentation/screens/family_tree_screen.dart';
import '../../features/family_tree/presentation/screens/member_profile_screen.dart';
import '../../features/family_tree/presentation/screens/person_family_tree_screen.dart';
import '../../features/family_tree/presentation/screens/search_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../presentation/widgets/main_navigation_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserStreamProvider);
  final splashCheckDone = ref.watch(splashCheckDoneProvider);

  return GoRouter(
    initialLocation: kIsWeb ? '/family-tree' : '/splash',
    redirect: (BuildContext context, GoRouterState state) {
      final loc = state.matchedLocation;

      // 1. Auth & Splash initialization logic
      if (kIsWeb) {
        // On Web, bypass splash screen completely
        if (loc == '/splash') {
          final user = authState.valueOrNull;
          if (user != null) {
            return user.isAdmin ? '/admin/dashboard' : '/family-tree';
          }
          return '/login';
        }
        if (authState.isLoading) {
          return null;
        }
      } else {
        // On mobile, keep on splash until checks finish
        if (loc == '/splash' && (authState.isLoading || !splashCheckDone)) {
          return null;
        }
        if (authState.isLoading) {
          return loc == '/splash' ? null : '/splash';
        }
      }

      final user = authState.valueOrNull;
      final isAuth = user != null;

      final isAuthRoute =
          loc == '/login' || loc == '/signup' || loc == '/admin-login';

      // 2. Unauthenticated users cannot access protected routes
      if (!isAuth) {
        if (loc == '/splash') return '/login';
        return isAuthRoute ? null : '/login';
      }

      // 3. Authenticated users attempting to visit splash or auth routes go to role-specific first screen
      if (loc == '/splash' || isAuthRoute) {
        if (user.isAdmin) {
          return '/admin/dashboard';
        }
        return '/family-tree';
      }

      // 4. Admin route protection & Super Admin restrictions
      if (loc.startsWith('/admin')) {
        if (!user.isAdmin) {
          return '/family-tree';
        }
        // Super Admin only routes
        final isSuperAdminRoute = loc == '/admin/users' ||
            loc == '/admin/export-import' ||
            loc == '/admin/audit-logs';
        if (isSuperAdminRoute && !user.isSuperAdmin) {
          return '/admin/dashboard';
        }
      }

      // 5. If user profile needs completion (skip for super admin)
      if (!user.role.isSuperAdmin &&
          (user.fatherName.isEmpty || user.address.isEmpty) &&
          loc != '/complete-profile') {
        return '/complete-profile';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SignupScreen(initialData: extra);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/admin-login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),

      // Material 3 Bottom Navigation Shell (Role-aware: Admin vs Normal User)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Admin Panel (First screen for Admin / Super Admin)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          // Branch 1: Family Tree Canvas (First screen for Normal Users)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/family-tree',
                builder: (context, state) {
                  final focusMemberId = state.uri.queryParameters['focusMemberId'];
                  return FamilyTreeScreen(focusMemberId: focusMemberId);
                },
              ),
            ],
          ),
          // Branch 2: Family Members Directory
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/family-members',
                builder: (context, state) => const FamilyMembersScreen(),
              ),
            ],
          ),
          // Branch 3: My Profile & Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-profile',
                builder: (context, state) => const MyProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Sub-screens & Detail routes
      GoRoute(
        path: '/member/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MemberProfileScreen(memberId: id);
        },
      ),
      GoRoute(
        path: '/member/:id/tree',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PersonFamilyTreeScreen(memberId: id);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/submit-edit-request/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SubmitEditRequestScreen(memberId: id);
        },
      ),
      GoRoute(
        path: '/edit-request/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SubmitEditRequestScreen(memberId: id);
        },
      ),
      GoRoute(
        path: '/request-add-child/:fatherId',
        builder: (context, state) {
          final fatherId = state.pathParameters['fatherId'] ?? '';
          return RequestAddChildScreen(fatherId: fatherId);
        },
      ),
      GoRoute(
        path: '/admin/requests',
        builder: (context, state) => const PendingRequestsScreen(),
      ),
      GoRoute(
        path: '/admin/tree',
        builder: (context, state) {
          final focusMemberId = state.uri.queryParameters['focusMemberId'];
          return AdminTreeScreen(focusMemberId: focusMemberId);
        },
      ),
      GoRoute(
        path: '/admin/edit-member/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SubmitEditRequestScreen(memberId: id, isDirectAdmin: true);
        },
      ),
      GoRoute(
        path: '/admin/add-child/:fatherId',
        builder: (context, state) {
          final fatherId = state.pathParameters['fatherId'] ?? '';
          return RequestAddChildScreen(fatherId: fatherId, isDirectAdmin: true);
        },
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUserManagementScreen(),
      ),
      GoRoute(
        path: '/admin/export-import',
        builder: (context, state) => const JsonExportImportScreen(),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        builder: (context, state) => const AuditLogScreen(),
      ),
    ],
  );
});
