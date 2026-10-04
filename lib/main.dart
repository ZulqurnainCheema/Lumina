import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lumina/screens/edit_book.dart';
import 'package:lumina/screens/edit_entry.dart';
import 'package:lumina/screens/library.dart';
import 'package:lumina/screens/reading_plan.dart';
import 'package:lumina/screens/reading_session.dart';
import 'package:lumina/screens/science.dart';
import 'package:lumina/screens/settings.dart';
import 'package:lumina/screens/today.dart';
import 'package:lumina/screens/weekly_review.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:lumina/screens/add_book_progress.dart';
import 'package:lumina/screens/add_books.dart';
import 'package:lumina/screens/book_progress.dart';
import 'package:lumina/screens/summary_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'theme.dart';
import 'package:go_router/go_router.dart';
import 'screens/statistics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lumina',
      debugShowCheckedModeBanner: false,
      theme: LuminaTheme.dark(),
      routerConfig: _router,
    );
  }
}

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    // The three tabs. Everything else is pushed on top and hides the bar.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeShell(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (BuildContext context, GoRouterState state) {
                return const Today();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/library',
              builder: (context, state) {
                return const Library();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/statistics',
              builder: (context, state) {
                return const StatisticsScreen();
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/add-books',
      builder: (BuildContext context, GoRouterState state) {
        return const Addbooks();
      },
    ),
    GoRoute(
      path: '/book-progress/:id',
      builder: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id']!;
        return BookProgress(id: int.parse(id));
      },
    ),
    GoRoute(
      path: '/add-book-progress/:id',
      builder: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id']!;
        return AddBookProgress(
          id: int.parse(id),
          durationSeconds: state.extra as int?,
        );
      },
    ),
    GoRoute(
      path: '/edit-book/:id',
      builder: (context, state) {
        return EditBook(id: int.parse(state.pathParameters['id']!));
      },
    ),
    GoRoute(
      path: '/edit-entry/:id',
      builder: (context, state) {
        return EditEntry(id: int.parse(state.pathParameters['id']!));
      },
    ),
    GoRoute(
      path: '/summary/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return SummaryPage(id: int.parse(id));
      },
    ),
    GoRoute(
      path: '/read/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ReadingSession(id: int.parse(id));
      },
    ),
    GoRoute(
      path: '/plan',
      builder: (context, state) {
        return const ReadingPlan();
      },
    ),
    GoRoute(
      path: '/review',
      builder: (context, state) {
        return const WeeklyReview();
      },
    ),
    GoRoute(
      path: '/science',
      builder: (context, state) {
        return const Science();
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) {
        return const Settings();
      },
    ),
  ],
);

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  static const List<(IconData, String)> _destinations = <(IconData, String)>[
    (Symbols.wb_sunny, 'Today'),
    (Symbols.menu_book, 'Library'),
    (Symbols.bar_chart, 'Stats'),
  ];

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar floats; screens scroll behind it.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: LuminaColors.sheet,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: LuminaColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                for (int index = 0; index < _destinations.length; index++)
                  Expanded(
                    child: _NavItem(
                      icon: _destinations[index].$1,
                      label: _destinations[index].$2,
                      selected: index == navigationShell.currentIndex,
                      onTap: () {
                        navigationShell.goBranch(
                          index,
                          initialLocation:
                              index == navigationShell.currentIndex,
                        );
                      },
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? LuminaColors.onAccent
        : LuminaColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? LuminaColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 14, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
