import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('News & Updates')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('news')
              .orderBy('publishedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final theme = Theme.of(context);
            final slivers = <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _NewsHero(theme: theme),
                ),
              ),
            ];

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              slivers.add(
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final isLast = index == 2;
                        return Padding(
                          padding:
                              EdgeInsets.only(bottom: isLast ? 0 : 16),
                          child: const _NewsSkeletonCard(),
                        );
                      },
                      childCount: 3,
                    ),
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: const _NewsEmptyState(
                      icon: FontAwesomeIcons.triangleExclamation,
                      title: 'Unable to load news',
                      message:
                          'Check your connection and pull down to refresh.',
                    ),
                  ),
                ),
              );
            } else {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                slivers.add(
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: const _NewsEmptyState(
                        icon: FontAwesomeIcons.newspaper,
                        title: 'No news yet',
                        message:
                            'We\'ll post municipal updates here as soon as they are published.',
                      ),
                    ),
                  ),
                );
              } else {
                slivers.add(
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final title =
                              (data['title'] as String?)?.trim() ?? 'Untitled';
                          final summary =
                              (data['summary'] as String?)?.trim() ?? '';
                          final imageUrl =
                              (data['imageUrl'] as String?)?.trim();
                          final publishedAt =
                              (data['publishedAt'] as Timestamp?)?.toDate();
                          final tag = (data['tag'] as String?)?.trim();
                          final isLast = index == docs.length - 1;
                          return Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                            child: _NewsCard(
                              id: doc.id,
                              title: title,
                              summary: summary,
                              publishedAt: publishedAt,
                              imageUrl: imageUrl,
                              tag: tag,
                            ),
                          );
                        },
                        childCount: docs.length,
                      ),
                    ),
                  ),
                );
              }
            }

            return RefreshIndicator(
              onRefresh: () async {
                await FirebaseFirestore.instance
                    .collection('news')
                    .orderBy('publishedAt', descending: true)
                    .limit(1)
                    .get();
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: slivers,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NewsHero extends StatelessWidget {
  const _NewsHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    FaIcon(FontAwesomeIcons.bullhorn, size: 12, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Municipal updates',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'News & alerts',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stay in the loop with announcements from the municipal council.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.id,
    required this.title,
    required this.summary,
    required this.publishedAt,
    required this.tag,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String summary;
  final DateTime? publishedAt;
  final String? imageUrl;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.45 : 0.92,
    );
    final dateLabel = publishedAt != null
        ? DateFormat('MMM d, yyyy').format(publishedAt!)
        : 'Just now';
    final displaySummary = summary.isEmpty
        ? 'Tap to read the full announcement.'
        : summary;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.go('/dashboard/news/$id'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null && tag!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Hero(
                    tag: 'news-title-$id',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displaySummary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Read more',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FaIcon(
                        FontAwesomeIcons.arrowRightLong,
                        size: 14,
                        color: theme.colorScheme.primary,
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
  }
}

class _NewsEmptyState extends StatelessWidget {
  const _NewsEmptyState({
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
      alpha: theme.brightness == Brightness.dark ? 0.4 : 0.9,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color
                    ?.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsSkeletonCard extends StatelessWidget {
  const _NewsSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.3 : 0.7,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _NewsSkeletonLine(widthFactor: 0.3, height: 14),
            SizedBox(height: 16),
            _NewsSkeletonLine(widthFactor: 0.85),
            SizedBox(height: 10),
            _NewsSkeletonLine(widthFactor: 0.7),
            SizedBox(height: 10),
            _NewsSkeletonLine(widthFactor: 0.6),
            SizedBox(height: 18),
            _NewsSkeletonLine(widthFactor: 0.4, height: 12),
          ],
        ),
      ),
    );
  }
}

class _NewsSkeletonLine extends StatelessWidget {
  const _NewsSkeletonLine({
    required this.widthFactor,
    this.height = 12,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
