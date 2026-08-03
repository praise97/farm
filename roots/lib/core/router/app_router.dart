import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/app_providers.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/livestock/livestock_list_screen.dart';
import '../../presentation/screens/livestock/animal_detail_screen.dart';
import '../../presentation/screens/livestock/animal_form_screen.dart';
import '../../presentation/screens/equipment/equipment_screen.dart';
import '../../presentation/screens/inventory/inventory_screen.dart';
import '../../presentation/screens/finance/finance_screen.dart';
import '../../presentation/screens/crops/crops_screen.dart';
import '../../presentation/screens/tasks/tasks_screen.dart';
import '../../presentation/screens/map/map_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/alerts/alerts_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/workers/workers_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Stable GoRouter — do NOT watch auth here (that recreates the router and
/// kicks the user back to login after a successful sign-in).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final user = auth.valueOrNull;
      final loading = auth.isLoading && !auth.hasValue;

      // Stay put while the very first auth bootstrap is unresolved.
      if (loading) return null;
      if (user == null && !loggingIn) return '/login';
      if (user != null && loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/livestock', builder: (context, state) => const LivestockListScreen()),
          GoRoute(path: '/livestock/add', builder: (context, state) => const AnimalFormScreen()),
          GoRoute(
            path: '/livestock/:id',
            builder: (context, state) => AnimalDetailScreen(animalId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/livestock/:id/edit',
            builder: (context, state) => AnimalFormScreen(animalId: state.pathParameters['id']),
          ),
          GoRoute(path: '/equipment', builder: (context, state) => const EquipmentScreen()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen()),
          GoRoute(path: '/finance', builder: (context, state) => const FinanceScreen()),
          GoRoute(path: '/crops', builder: (context, state) => const CropsScreen()),
          GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
          GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
          GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
          GoRoute(path: '/workers', builder: (context, state) => const WorkersScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
        ],
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref ref;
}
