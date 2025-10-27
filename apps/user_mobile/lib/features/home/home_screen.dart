import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/auth_service.dart';
import '../../core/app_logo.dart';
import 'home_activity_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;
    final theme = Theme.of(context);
    final displayName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim().split(' ').first
        : 'User';
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatFullDate(DateTime.now());
    final userId = user?.uid;
    final disableShortcuts = !authService.isReady || userId == null;
    final initials = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(showTitle: true, title: 'UPS'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') {
                context.go('/dashboard/about');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('About')),
            ],
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/auth');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(context, theme, displayName, dateLabel, initials),
            const SizedBox(height: 24),
            _buildSectionHeader(
              theme,
              title: 'Quick Actions',
              subtitle: 'Manage your essential services in one tap.',
            ),
            const SizedBox(height: 16),
            _buildDashboardGrid(context, isBusy: disableShortcuts),
            const SizedBox(height: 24),
            _buildSectionHeader(
              theme,
              title: 'Recent Activity',
              subtitle: 'Stay updated with your latest requests.',
            ),
            const SizedBox(height: 16),
            _buildRecentActivityList(context, userId: userId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    ThemeData theme,
    String displayName,
    String dateLabel,
    String initials,
  ) {
    final surfaceColor = theme.colorScheme.surfaceContainerHighest;
    final onSurfaceMuted = theme.colorScheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      color: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    initials,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good day, $displayName',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Manage taxes, community bookings, service tracking, and news from one super app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                ActionChip(
                  avatar: Icon(
                    FontAwesomeIcons.fileInvoiceDollar,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: const Text('Pay tax'),
                  onPressed: () => context.go('/dashboard/tax'),
                  backgroundColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.28),
                ),
                ActionChip(
                  avatar: Icon(
                    FontAwesomeIcons.calendarCheck,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  label: const Text('Book services'),
                  onPressed: () => context.go('/dashboard/bookings'),
                  backgroundColor: theme.colorScheme.secondaryContainer
                      .withValues(alpha: 0.28),
                ),
                ActionChip(
                  avatar: Icon(
                    FontAwesomeIcons.locationArrow,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
                  label: const Text('Track deliveries'),
                  onPressed: () => context.go('/dashboard/tracker'),
                  backgroundColor: theme.colorScheme.tertiaryContainer
                      .withValues(alpha: 0.28),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardGrid(BuildContext context, {required bool isBusy}) {
    final shortcuts = <_ShortcutItem>[
      const _ShortcutItem(
        icon: FontAwesomeIcons.fileInvoiceDollar,
        label: 'Pay Tax',
        gradient: [Color(0xFF43CEA2), Color(0xFF185A9D)],
        route: '/dashboard/tax',
      ),
      const _ShortcutItem(
        icon: FontAwesomeIcons.mapPin,
        label: 'Service Tracker',
        gradient: [Color(0xFFF2994A), Color(0xFFF2C94C)],
        route: '/dashboard/tracker',
      ),
      const _ShortcutItem(
        icon: FontAwesomeIcons.newspaper,
        label: 'News',
        gradient: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
        route: '/dashboard/news',
      ),
      const _ShortcutItem(
        icon: FontAwesomeIcons.circleExclamation,
        label: 'Complaints',
        gradient: [Color(0xFFE96443), Color(0xFF904E95)],
        route: '/dashboard/complaints',
      ),
      const _ShortcutItem(
        icon: FontAwesomeIcons.calendarCheck,
        label: 'Booking',
        gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        route: '/dashboard/bookings',
      ),
      const _ShortcutItem(
        icon: FontAwesomeIcons.user,
        label: 'Profile',
        gradient: [Color(0xFF26D0CE), Color(0xFF1A2980)],
        route: '/dashboard/profile',
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 720 ? 2 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: shortcuts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final item = shortcuts[index];
        return _DashboardShortcut(
          item: item,
          onTap: isBusy ? null : () => context.go(item.route),
          isBusy: isBusy,
        );
      },
    );
  }

  Widget _buildRecentActivityList(
    BuildContext context, {
    required String? userId,
  }) {
    final theme = Theme.of(context);

    if (userId == null) {
      return const _ActivityEmptyState(
        icon: FontAwesomeIcons.userSlash,
        title: 'Sign in to view your activity',
        message: 'Bookings and complaints you make will appear here.',
      );
    }

    final activityService = HomeActivityService();

    return StreamBuilder<List<HomeActivityEvent>>(
      stream: activityService.streamForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _ActivitySkeletonList();
        }

        if (snapshot.hasError) {
          return const _ActivityEmptyState(
            icon: FontAwesomeIcons.triangleExclamation,
            title: 'We couldn\'t load your activity',
            message: 'Please check your connection and try again.',
          );
        }

        final events = snapshot.data ?? const <HomeActivityEvent>[];
        if (events.isEmpty) {
          return const _ActivityEmptyState(
            icon: FontAwesomeIcons.clipboardCheck,
            title: 'You\'re all caught up',
            message: 'Create a booking or file a complaint to see it here.',
          );
        }

        final items = events.take(6).map((event) {
          return _ActivityItem(
            icon: _iconForActivity(event.type),
            title: event.title,
            subtitle: event.subtitle,
            timestamp: _relativeTimeLabel(context, event.timestamp),
            color: _colorForActivity(event.type, theme),
          );
        }).toList();

        return Column(
          children: [
            for (var i = 0; i < items.length; i++)
              _ActivityTimelineTile(
                item: items[i],
                isFirst: i == 0,
                isLast: i == items.length - 1,
              ),
          ],
        );
      },
    );
  }
}

class _ShortcutItem {
  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.gradient,
  });

  final IconData icon;
  final String label;
  final String route;
  final List<Color> gradient;
}

class _DashboardShortcut extends StatelessWidget {
  const _DashboardShortcut({
    required this.item,
    required this.onTap,
    required this.isBusy,
  });

  final _ShortcutItem item;
  final VoidCallback? onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -40,
              right: -20,
              child: _GlowCircle(
                diameter: 150,
                color: Colors.white,
                opacity: 0.12,
              ),
            ),
            const Positioned(
              bottom: -50,
              left: -30,
              child: _GlowCircle(
                diameter: 170,
                color: Colors.white,
                opacity: 0.18,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: FaIcon(item.icon, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Explore',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FaIcon(
                        FontAwesomeIcons.arrowRightLong,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isBusy) {
      card = Stack(
        children: [
          card,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned.fill(
            child: Center(
              child: SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _PressableScale(onTap: onTap, child: card);
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String timestamp;
  final Color color;
}

class _ActivityTimelineTile extends StatelessWidget {
  const _ActivityTimelineTile({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final _ActivityItem item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timelineColor = theme.colorScheme.outline.withValues(alpha: 0.2);
    final baseSurface = theme.colorScheme.surfaceContainerHighest;
    final background = baseSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.3 : 0.75,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color,
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 2),
                      color: timelineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: FaIcon(
                              item.icon,
                              size: 16,
                              color: item.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.timestamp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForActivity(HomeActivityType type) {
  return switch (type) {
    HomeActivityType.booking => FontAwesomeIcons.calendarCheck,
    HomeActivityType.complaint => FontAwesomeIcons.circleExclamation,
  };
}

Color _colorForActivity(HomeActivityType type, ThemeData theme) {
  final scheme = theme.colorScheme;
  return switch (type) {
    HomeActivityType.booking => scheme.primary,
    HomeActivityType.complaint => scheme.tertiary,
  };
}

String _relativeTimeLabel(BuildContext context, DateTime timestamp) {
  final now = DateTime.now();
  if (timestamp.isAfter(now)) {
    final diff = timestamp.difference(now);
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes.clamp(1, 59);
      return 'In $minutes min${minutes == 1 ? '' : 's'}';
    }
    if (diff.inHours < 48) {
      final hours = diff.inHours;
      return 'In $hours hour${hours == 1 ? '' : 's'}';
    }
    final days = diff.inDays;
    return 'In $days day${days == 1 ? '' : 's'}';
  }

  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes;
    return '$minutes min${minutes == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    final days = diff.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
  return DateFormat('MMM d, yyyy').format(timestamp);
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.4 : 0.85,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.75,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySkeletonList extends StatelessWidget {
  const _ActivitySkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ActivitySkeletonTile(isLast: false),
        _ActivitySkeletonTile(isLast: false),
        _ActivitySkeletonTile(isLast: true),
      ],
    );
  }
}

class _ActivitySkeletonTile extends StatelessWidget {
  const _ActivitySkeletonTile({required this.isLast});

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.3 : 0.6,
    );
    final accent = theme.colorScheme.primary.withValues(alpha: 0.25);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 2),
                      color: accent.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonLine(widthFactor: 0.45),
                    SizedBox(height: 12),
                    _SkeletonLine(widthFactor: 0.8),
                    SizedBox(height: 8),
                    _SkeletonLine(widthFactor: 0.6),
                    SizedBox(height: 16),
                    _SkeletonLine(widthFactor: 0.35),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.diameter,
    required this.color,
    required this.opacity,
  });

  final double diameter;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.96 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) {
      return widget.child;
    }

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
