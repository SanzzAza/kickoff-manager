import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../theme.dart';
import 'club_screen.dart';
import 'match_sim_screen.dart';
import 'table_screen.dart';
import 'squad_screen.dart';
import 'market_screen.dart';

class HomeShell extends StatefulWidget {
  final GameService service;
  const HomeShell({super.key, required this.service});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ClubScreen(service: widget.service, onNavigate: (i) => setState(() => index = i)),
      SquadScreen(service: widget.service),
      MatchSimScreen(service: widget.service),
      TableScreen(service: widget.service),
      MarketScreen(service: widget.service),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 62,
        backgroundColor: AppColors.surface,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
              label: 'Klub'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups, color: AppColors.primary),
              label: 'Skuad'),
          NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              selectedIcon: Icon(Icons.play_circle, color: AppColors.primary),
              label: 'Main'),
          NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard, color: AppColors.primary),
              label: 'Klasemen'),
          NavigationDestination(
              icon: Icon(Icons.swap_horiz_outlined),
              selectedIcon: Icon(Icons.swap_horiz, color: AppColors.primary),
              label: 'Transfer'),
        ],
      ),
    );
  }
}
