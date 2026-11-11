import 'package:flutter/material.dart';

import 'rest_alert.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/body_page.dart';
import 'ui/home_page.dart';
import 'ui/plan_page.dart';
import 'ui/widgets.dart';
import 'ui/workout_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.load();
  await RestAlert.instance.init();
  runApp(const MyMoosclesApp());
}

class MyMoosclesApp extends StatefulWidget {
  const MyMoosclesApp({super.key});

  @override
  State<MyMoosclesApp> createState() => _MyMoosclesAppState();
}

class _MyMoosclesAppState extends State<MyMoosclesApp> {
  late String _themeKey = Store.instance.data.profile.theme;

  @override
  void initState() {
    super.initState();
    Store.instance.addListener(_onStore);
  }

  @override
  void dispose() {
    Store.instance.removeListener(_onStore);
    super.dispose();
  }

  // Só reconstrói o app inteiro quando o tema muda.
  void _onStore() {
    final k = Store.instance.data.profile.theme;
    if (k != _themeKey) setState(() => _themeKey = k);
  }

  @override
  Widget build(BuildContext context) {
    final t = themeFor(_themeKey);
    return MaterialApp(
      title: 'MyMooscles',
      debugShowCheckedModeBanner: false,
      theme: t.toThemeData(),
      builder: (context, child) => MooThemeScope(theme: t, child: child ?? const SizedBox.shrink()),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  static const _pages = <Widget>[
    HomePage(),
    WorkoutsPage(),
    BodyPage(),
    PlanPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: _pages)),
      bottomNavigationBar: MooNavBar(index: _index, onTap: (i) => setState(() => _index = i)),
    );
  }
}

class MooNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const MooNavBar({super.key, required this.index, required this.onTap});

  static const _items = <(IconData, IconData, String)>[
    (Icons.today_outlined, Icons.today, 'Hoje'),
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Treinos'),
    (Icons.monitor_weight_outlined, Icons.monitor_weight, 'Corpo'),
    (Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Plano'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final topBorder = t.borderWidth >= 2
        ? BorderSide(color: t.line, width: 2)
        : BorderSide(color: t.isDark ? const Color(0xFF24272E) : t.line, width: 1);
    return Container(
      decoration: BoxDecoration(color: t.navBg, border: Border(top: topBorder)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(child: _NavItem(item: _items[i], selected: i == index, onTap: () => onTap(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final (IconData, IconData, String) item;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final pillBg = !selected ? Colors.transparent : (t.key == 'noturno' ? t.acc : t.surf2);
    final fg = !selected ? t.muted : (t.key == 'noturno' ? t.onAcc : t.acc);
    final radius = BorderRadius.circular(14);
    return Semantics(
      selected: selected,
      button: true,
      label: item.$3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: pillBg,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? item.$2 : item.$1, color: fg, size: 24),
                  const SizedBox(height: 2),
                  Text(item.$3, style: t.body(12, weight: FontWeight.w700, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
