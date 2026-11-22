import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/add_screen.dart';
import 'screens/records_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await appState.init();
  runApp(const LedgerApp());
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final t = appState.theme;
        return MaterialApp(
          title: '我的账本',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: t.primary),
            scaffoldBackgroundColor: t.background,
            fontFamily: 'sans-serif',
          ),
          home: const MainShell(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final List<Widget> _pages = const [
    HomeScreen(),
    AddScreen(),
    RecordsScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final t = appState.theme;
        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: appState.navIndex,
              children: _pages,
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: t.card,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(icon: Icons.home_rounded, label: '首页', index: 0, activeColor: t.primary, textColor: t.subText),
                    _NavItem(icon: Icons.add_circle_rounded, label: '记账', index: 1, activeColor: t.primary, textColor: t.subText),
                    _NavItem(icon: Icons.list_alt_rounded, label: '明细', index: 2, activeColor: t.primary, textColor: t.subText),
                    _NavItem(icon: Icons.bar_chart_rounded, label: '统计', index: 3, activeColor: t.primary, textColor: t.subText),
                    _NavItem(icon: Icons.settings_rounded, label: '设置', index: 4, activeColor: t.primary, textColor: t.subText),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final Color activeColor;
  final Color textColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.activeColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = appState.navIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => appState.navIndex = index,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: index == 1 ? 34 : 24,
              color: active ? activeColor : textColor.withOpacity(0.55),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: active ? activeColor : textColor.withOpacity(0.55),
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
