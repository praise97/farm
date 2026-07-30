import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/roots_theme.dart';
import '../providers/app_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const destinations = <_NavItem>[
    _NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '/dashboard'),
    _NavItem('Livestock', Icons.pets_outlined, Icons.pets, '/livestock'),
    _NavItem('Equipment', Icons.agriculture_outlined, Icons.agriculture, '/equipment'),
    _NavItem('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, '/inventory'),
    _NavItem('Crops', Icons.grass_outlined, Icons.grass, '/crops'),
    _NavItem('Finance', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, '/finance'),
    _NavItem('Tasks', Icons.task_alt_outlined, Icons.task_alt, '/tasks'),
    _NavItem('Map', Icons.map_outlined, Icons.map, '/map'),
    _NavItem('Reports', Icons.assessment_outlined, Icons.assessment, '/reports'),
    _NavItem('Workers', Icons.groups_outlined, Icons.groups, '/workers'),
    _NavItem('Alerts', Icons.notifications_outlined, Icons.notifications, '/alerts'),
    _NavItem('Settings', Icons.settings_outlined, Icons.settings, '/settings'),
  ];

  /// Primary sidebar items shown on mobile and desktop.
  static const sidebarItems = <_NavItem>[
    _NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '/dashboard'),
    _NavItem('Livestock', Icons.pets_outlined, Icons.pets, '/livestock'),
    _NavItem('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, '/inventory'),
    _NavItem('Tasks', Icons.task_alt_outlined, Icons.task_alt, '/tasks'),
  ];

  int _indexForLocation(String location, List<_NavItem> items) {
    final i = items.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? -1 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final location = GoRouterState.of(context).uri.toString();
    final user = ref.watch(authStateProvider).valueOrNull;
    final unread = ref.watch(unreadAlertsProvider);

    void onSelect(String path) {
      context.go(path);
      if (!isDesktop) Navigator.of(context).pop();
    }

    Future<void> onLogout() async {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }

    final sidebar = _AppSidebar(
      items: isDesktop ? destinations : sidebarItems,
      selectedIndex: isDesktop
          ? _indexForLocation(location, destinations)
          : _indexForLocation(location, sidebarItems),
      unread: unread,
      userName: user?.name ?? 'Guest',
      userRole: user?.role.name ?? '',
      initials: user?.initials ?? 'R',
      compact: !isDesktop,
      onSelect: (item) => onSelect(item.path),
      onLogout: onLogout,
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForLocation(location)),
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
          PopupMenuButton<String>(
            onSelected: (v) => context.go('/$v'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'equipment', child: Text('Equipment')),
              PopupMenuItem(value: 'crops', child: Text('Crops')),
              PopupMenuItem(value: 'finance', child: Text('Finance')),
              PopupMenuItem(value: 'map', child: Text('Farm Map')),
              PopupMenuItem(value: 'reports', child: Text('Reports')),
              PopupMenuItem(value: 'workers', child: Text('Workers')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: RootsColors.navy,
        child: SafeArea(child: sidebar),
      ),
      body: child,
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

class _AppSidebar extends StatelessWidget {
  const _AppSidebar({
    required this.items,
    required this.selectedIndex,
    required this.unread,
    required this.userName,
    required this.userRole,
    required this.initials,
    required this.compact,
    required this.onSelect,
    required this.onLogout,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final int unread;
  final String userName;
  final String userRole;
  final String initials;
  final bool compact;
  final ValueChanged<_NavItem> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : 250,
      color: RootsColors.navy,
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, compact ? 16 : 28, compact ? 12 : 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: RootsColors.leaf, size: 28),
              const SizedBox(width: 10),
              const Text(
                'Roots',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              if (compact) ...[
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 20 : 36),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final d = items[i];
                final selected = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: selected ? RootsColors.sidebarAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Icon(
                        selected ? d.selectedIcon : d.icon,
                        color: selected ? RootsColors.leaf : const Color(0xFFB0C9DB),
                        size: 22,
                      ),
                      title: Text(
                        d.label,
                        style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFFB0C9DB),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      onTap: () => onSelect(d),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!compact)
            ListTile(
              dense: true,
              leading: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_outlined, color: Color(0xFFB0C9DB), size: 20),
              ),
              title: const Text(
                'Alerts',
                style: TextStyle(color: Color(0xFFB0C9DB), fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onTap: () => onSelect(const _NavItem('Alerts', Icons.notifications_outlined, Icons.notifications, '/alerts')),
            ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: RootsColors.sidebarAccent,
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(
                      userRole.isEmpty ? '' : '${userRole[0].toUpperCase()}${userRole.substring(1)}',
                      style: const TextStyle(color: Color(0xFF8AAEC4), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Color(0xFFB0C9DB), size: 18),
                tooltip: 'Log out',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
