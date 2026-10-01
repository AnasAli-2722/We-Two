import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_controller.dart';
import '../../../core/theme/app_theme_engine.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications = true;
  bool _inAppSounds = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    final selectedPreset = ref.watch(appThemePresetProvider);

    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                children: [
                  _SectionCard(
                    surfaceColor: surface,
                    title: 'Account',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.alternate_email_rounded),
                        title: const Text('Change Email'),
                        subtitle: const Text('UI only for now'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Change Email coming soon'),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, color: Colors.white10),
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded),
                        title: const Text('Change Password'),
                        subtitle: const Text('UI only for now'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Change Password coming soon'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    surfaceColor: surface,
                    title: 'Theme',
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        child: Column(
                          children: [
                            for (
                              var i = 0;
                              i < AppThemePreset.values.length;
                              i++
                            ) ...[
                              Builder(
                                builder: (context) {
                                  final preset = AppThemePreset.values[i];
                                  final palette = preset.palette;
                                  final selected = selectedPreset == preset;

                                  return _ThemeOptionTile(
                                    label: palette.label,
                                    accent: palette.accent,
                                    surface: palette.surface,
                                    surfaceAlt: palette.surfaceAlt,
                                    background: palette.background,
                                    selected: selected,
                                    onTap: () async {
                                      await HapticFeedback.selectionClick();
                                      await ref
                                          .read(appThemePresetProvider.notifier)
                                          .setTheme(preset);
                                    },
                                  );
                                },
                              ),
                              if (i != AppThemePreset.values.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    surfaceColor: surface,
                    title: 'Notifications',
                    children: [
                      SwitchListTile.adaptive(
                        value: _pushNotifications,
                        activeThumbColor: accent,
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Receive device notifications'),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _pushNotifications = value);
                        },
                      ),
                      const Divider(height: 1, color: Colors.white10),
                      SwitchListTile.adaptive(
                        value: _inAppSounds,
                        activeThumbColor: accent,
                        title: const Text('In-App Sounds'),
                        subtitle: const Text('Play sounds inside app'),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _inAppSounds = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    surfaceColor: surface,
                    title: 'Danger Zone',
                    titleColor: Colors.redAccent.shade100,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: surface.withValues(alpha: 0.85),
                              foregroundColor: Colors.redAccent.shade100,
                              minimumSize: const Size.fromHeight(46),
                            ),
                            onPressed: () async {
                              await HapticFeedback.mediumImpact();
                              await ref.read(authRepositoryProvider).signOut();
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign Out'),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Delete Account flow will be wired next.',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    required this.surfaceColor,
    this.titleColor,
  });

  final String title;
  final List<Widget> children;
  final Color surfaceColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              title,
              style: TextStyle(
                color: titleColor ?? Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.label,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 62,
              width: 94,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  children: [
                    Expanded(child: ColoredBox(color: accent)),
                    Expanded(child: ColoredBox(color: surfaceAlt)),
                    Expanded(child: ColoredBox(color: surface)),
                    Expanded(child: ColoredBox(color: background)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SwatchDot(color: accent),
                      const SizedBox(width: 6),
                      _SwatchDot(color: surfaceAlt),
                      const SizedBox(width: 6),
                      _SwatchDot(color: surface),
                      const SizedBox(width: 6),
                      _SwatchDot(color: background),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
    );
  }
}
