import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Symbols.wb_sunny), label: 'Today'),
          NavigationDestination(
            icon: Icon(Symbols.menu_book),
            label: 'Library',
          ),
          NavigationDestination(icon: Icon(Symbols.bar_chart), label: 'Stats'),
        ],
      ),
    );
  }
}
