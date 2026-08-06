import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/roots_theme.dart';
import '../../core/tour/app_tour.dart';
import '../providers/app_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  static const destinations = <_NavItem>[
    _NavItem('Dashboard', Icons.grid_view_rounded, Icons.grid_view_rounded, '/dashboard'),
    _NavItem('Livestock', Icons.pets_outlined, Icons.pets, '/livestock'),
    _NavItem('Crops', Icons.grass_outlined, Icons.grass, '/crops'),
    _NavItem('Equipment', Icons.agriculture_outlined, Icons.agriculture, '/equipment'),
    _NavItem('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, '/inventory'),
    _NavItem('Finance', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, '/finance'),
    _NavItem('Tasks', Icons.task_alt_outlined, Icons.task_alt, '/tasks'),
    _NavItem('Map', Icons.map_outlined, Icons.map, '/map'),
    _NavItem('Reports', Icons.assessment_outlined, Icons.assessment, '/reports'),
    _NavItem('Workers', Icons.groups_outlined, Icons.groups, '/workers'),
    _NavItem('Alerts', Icons.notifications_outlined, Icons.notifications, '/alerts'),
    _NavItem('Settings', Icons.settings_outlined, Icons.settings, '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final location = GoRouterState.of(context).uri.toString();
    final user = ref.watch(authStateProvider).valueOrNull;
    final unread = ref.watch(unreadAlertsProvider);

    void onSelect(String path) {
      context.go(path);
      if (!isDesktop) {
        _scaffoldKey.currentState?.closeDrawer();
      }
    }

    Future<void> onLogout() async {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }

    final perms = ref.watch(permissionsProvider);
    final isSupervisor = perms?.isSupervisor ?? false;

    final sidebar = _AuraSidebar(
      selectedPath: location,
      unread: unread,
      userName: user?.name ?? 'Guest',
      showAll: isDesktop,
      isSupervisor: isSupervisor,
      onSelect: onSelect,
      onLogout: onLogout,
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            tourTarget(
              key: TourKeys.menu,
              title: 'Navigation',
              description: 'Use this sidebar to open Dashboard, Livestock, Crops, Finance, Alerts and more.',
              child: SizedBox(width: 280, child: sidebar),
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_titleForLocation(location)),
        leading: tourTarget(
          key: TourKeys.menu,
          title: 'Menu',
          description: 'Tap to open the sidebar — livestock, crops, finance, alerts and settings.',
          onTargetClick: _openDrawer,
          child: IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open menu',
            onPressed: _openDrawer,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Alerts',
            onPressed: () => context.go('/alerts'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        width: MediaQuery.sizeOf(context).width * 0.75,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
        child: sidebar,
      ),
      body: widget.child,
    );
  }

  String _titleForLocation(String location) {
    for (final d in destinations) {
      if (location.startsWith(d.path)) return d.label;
    }
    return 'Roots';
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon, this.path);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// AURA-style dark sidebar: brand header, section labels, active pill, red logout.
class _AuraSidebar extends StatelessWidget {
  const _AuraSidebar({
    required this.selectedPath,
    required this.unread,
    required this.userName,
    required this.showAll,
    required this.isSupervisor,
    required this.onSelect,
    required this.onLogout,
  });

  final String selectedPath;
  final int unread;
  final String userName;
  final bool showAll;
  final bool isSupervisor;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;

  // AURA screenshot palette
  static const _bg = Color(0xFF0F1A17);
  static const _activeBg = Color(0xFF1E2E28);
  static const _activeIcon = Color(0xFF3DDB7A);
  static const _iconIdle = Color(0xFFF0F4F2);
  static const _label = Color(0xFF8B9A93);
  static const _logout = Color(0xFFE07A7A);

  bool _isSelected(String path) => selectedPath.startsWith(path);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ROOTS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Farm Manager',
                          style: TextStyle(
                            color: _label,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Welcome, $userName',
                style: const TextStyle(
                  color: Color(0xFFD5DDD8),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF2A3531), height: 1),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _tile(
                      const _NavItem('Dashboard', Icons.grid_view_rounded, Icons.grid_view_rounded, '/dashboard'),
                    ),
                    if (isSupervisor) ...[
                      _section('MANAGEMENT'),
                      _tile(const _NavItem('Livestock', Icons.pets_outlined, Icons.pets, '/livestock')),
                      _tile(const _NavItem('Crops', Icons.grass_outlined, Icons.grass, '/crops')),
                      _tile(const _NavItem('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, '/inventory')),
                    ] else ...[
                      _section('MY WORK'),
                      _tile(const _NavItem('Livestock', Icons.pets_outlined, Icons.pets, '/livestock')),
                      _tile(const _NavItem('Staff', Icons.groups_outlined, Icons.groups, '/workers')),
                    ],
                    _tile(const _NavItem('Tasks', Icons.task_alt_outlined, Icons.task_alt, '/tasks')),
                    if (isSupervisor) ...[
                      _section('OPERATIONS'),
                      _tile(const _NavItem('Equipment', Icons.agriculture_outlined, Icons.agriculture, '/equipment')),
                      _tile(const _NavItem('Finance', Icons.payments_outlined, Icons.payments, '/finance')),
                      if (showAll) ...[
                        _tile(const _NavItem('Map', Icons.map_outlined, Icons.map, '/map')),
                        _tile(const _NavItem('Reports', Icons.assessment_outlined, Icons.assessment, '/reports')),
                        _tile(const _NavItem('Workers', Icons.groups_outlined, Icons.groups, '/workers')),
                      ],
                    ],
                    _section('ACCOUNT'),
                    _tile(
                      const _NavItem('Alerts', Icons.notifications_outlined, Icons.notifications, '/alerts'),
                      badge: unread,
                    ),
                    if (isSupervisor && !showAll)
                      _tile(const _NavItem('Workers', Icons.groups_outlined, Icons.groups, '/workers')),
                    if (isSupervisor && !showAll)
                      _tile(const _NavItem('Reports', Icons.assessment_outlined, Icons.assessment, '/reports')),
                    _tile(const _NavItem('Settings', Icons.settings_outlined, Icons.settings, '/settings')),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onLogout,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: _logout, size: 22),
                        SizedBox(width: 14),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: _logout,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: _label,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _tile(_NavItem d, {int badge = 0}) {
    final selected = _isSelected(d.path);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? _activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelect(d.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? d.selectedIcon : d.icon,
                  color: selected ? _activeIcon : _iconIdle,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    d.label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFF2F5F3),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: RootsColors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
