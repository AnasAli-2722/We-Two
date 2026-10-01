import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import '../core/theme/app_theme_engine.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    final muted = appColors?.muted ?? Colors.white.withValues(alpha: 0.72);
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hideDock = isKeyboardOpen;

    return Scaffold(
      backgroundColor: background,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          if (!hideDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: 62,
                      decoration: BoxDecoration(
                        color: surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _DockIcon(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: 'Chat',
                              selected: navigationShell.currentIndex == 0,
                              selectedColor: accent,
                              unselectedColor: muted,
                              onTap: () => _onTap(0),
                            ),
                          ),
                          Expanded(
                            child: _DockIcon(
                              icon: Icons.people_alt_outlined,
                              label: 'Friends',
                              selected: navigationShell.currentIndex == 1,
                              selectedColor: accent,
                              unselectedColor: muted,
                              onTap: () => _onTap(1),
                            ),
                          ),
                          Expanded(
                            child: _DockIcon(
                              icon: Icons.person_outline_rounded,
                              label: 'Profile',
                              selected: navigationShell.currentIndex == 2,
                              selectedColor: accent,
                              unselectedColor: muted,
                              onTap: () => _onTap(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: IconButton(
        onPressed: onTap,
        tooltip: label,
        splashRadius: 22,
        icon: Icon(
          icon,
          size: 23,
          color: selected ? selectedColor : unselectedColor,
        ),
      ),
    );
  }
}
