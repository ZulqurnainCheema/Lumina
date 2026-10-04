import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Reloads a tab's data whenever its route becomes the visible one again,
// for example after a pushed screen is closed or the tab is reselected.
mixin RouteRefresh<T extends StatefulWidget> on State<T> {
  GoRouterDelegate? _routerDelegate;

  String get routePath;

  void onRouteShown();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _routerDelegate = GoRouter.of(context).routerDelegate;
      _routerDelegate!.addListener(_onRouteChange);
    });
  }

  @override
  void dispose() {
    _routerDelegate?.removeListener(_onRouteChange);
    super.dispose();
  }

  void _onRouteChange() {
    if (mounted &&
        _routerDelegate!.currentConfiguration.uri.path == routePath) {
      onRouteShown();
    }
  }
}
