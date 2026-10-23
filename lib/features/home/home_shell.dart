import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../customers/customer_list_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../parts/part_list_screen.dart';
import '../reports/reports_screen.dart';
import '../transactions/transaction_list_screen.dart';

/// Kerangka utama aplikasi dengan navigasi 5 menu di bagian bawah.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  // Menu: Dashboard, Pelanggan, Transaksi, Sparepart, Laporan.
  static const List<_MenuItem> _menus = [
    _MenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    _MenuItem(
      title: 'Pelanggan',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
    ),
    _MenuItem(
      title: 'Transaksi',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
    ),
    _MenuItem(
      title: 'Sparepart',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
    ),
    _MenuItem(
      title: 'Laporan',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
    ),
  ];

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    // Beri tahu halaman mana yang aktif supaya data dimuat ulang.
    context.dependencies.selectedTab.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DashboardScreen(),
          CustomerListScreen(),
          TransactionListScreen(),
          PartListScreen(),
          ReportsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          destinations: _menus
              .map(
                (menu) => NavigationDestination(
                  icon: Icon(menu.icon),
                  selectedIcon: Icon(menu.activeIcon),
                  label: menu.title,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
  });

  final String title;
  final IconData icon;
  final IconData activeIcon;
}
