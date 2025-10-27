import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TaxScreen extends StatelessWidget {
  const TaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tax & Payments')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const _TaxHeroCard(),
            const SizedBox(height: 20),
            _buildHighlights(context),
            const SizedBox(height: 24),
            Text(
              'Make a payment',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildPaymentForm(context),
            const SizedBox(height: 28),
            Text(
              'Payment history',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildPaymentHistory(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlights(BuildContext context) {
    final theme = Theme.of(context);
    final highlightItems = [
      _HighlightData(
        icon: FontAwesomeIcons.folderOpen,
        title: 'LKR 0.00',
        subtitle: 'Outstanding balance',
        color: theme.colorScheme.primary,
      ),
      _HighlightData(
        icon: FontAwesomeIcons.calendarCheck,
        title: 'Next due: 15 Dec',
        subtitle: 'Property tax – Q4',
        color: theme.colorScheme.secondary,
      ),
      _HighlightData(
        icon: FontAwesomeIcons.receipt,
        title: 'Receipts: 08',
        subtitle: 'Payments this year',
        color: theme.colorScheme.tertiary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columnCount = maxWidth > 900
            ? 3
            : maxWidth > 600
            ? 2
            : 1;
        final itemWidth = (maxWidth - (12 * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: highlightItems
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _HighlightCard(data: item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildPaymentForm(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.45 : 0.85,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settle taxes instantly with secure digital payments.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Amount (LKR)',
                prefixIcon: const Icon(FontAwesomeIcons.coins, size: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Tax type',
                prefixIcon: const Icon(FontAwesomeIcons.listUl, size: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'property',
                  child: Text('Property tax'),
                ),
                DropdownMenuItem(
                  value: 'business',
                  child: Text('Business license'),
                ),
                DropdownMenuItem(
                  value: 'waste',
                  child: Text('Solid waste service'),
                ),
                DropdownMenuItem(
                  value: 'water',
                  child: Text('Water service levy'),
                ),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Reference number',
                prefixIcon: const Icon(FontAwesomeIcons.hashtag, size: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add payment notes for municipal records',
                prefixIcon: const Icon(FontAwesomeIcons.pencil, size: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(FontAwesomeIcons.fileArrowUp, size: 16),
              label: const Text('Attach proof of payment'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attachment uploads will be available soon.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(FontAwesomeIcons.wallet),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Payment processing will be enabled shortly.',
                    ),
                  ),
                );
              },
              label: const Text('Pay now'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory(BuildContext context) {
    final theme = Theme.of(context);
    final historyItems = [
      _HistoryData(
        icon: FontAwesomeIcons.houseChimney,
        title: 'Property tax – Q3',
        subtitle: 'Paid via card • 12 Sep 2025',
        amount: 'LKR 12,500.00',
        statusLabel: 'Paid',
        statusColor: theme.colorScheme.primary,
      ),
      _HistoryData(
        icon: FontAwesomeIcons.idCardClip,
        title: 'Business license renewal',
        subtitle: 'Pending review • 30 Aug 2025',
        amount: 'LKR 5,000.00',
        statusLabel: 'Processing',
        statusColor: theme.colorScheme.secondary,
      ),
      _HistoryData(
        icon: FontAwesomeIcons.droplet,
        title: 'Water service levy',
        subtitle: 'Paid via bank transfer • 18 Jul 2025',
        amount: 'LKR 4,200.00',
        statusLabel: 'Paid',
        statusColor: theme.colorScheme.tertiary,
      ),
    ];

    return Column(
      children: historyItems
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PaymentHistoryTile(data: item),
            ),
          )
          .toList(),
    );
  }
}

class _TaxHeroCard extends StatelessWidget {
  const _TaxHeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3A7BD5), Color(0xFF00D2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stay on top of your civic dues',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track taxes across water services, property, and business permits from one dashboard.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroPill(label: 'Property tax'),
              _HeroPill(label: 'Business permits'),
              _HeroPill(label: 'Water deliveries'),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            icon: const Icon(FontAwesomeIcons.download, size: 16),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Statement downloads will arrive soon.'),
                ),
              );
            },
            label: const Text('Download statements'),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HighlightData {
  const _HighlightData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.data});

  final _HighlightData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: data.color.withValues(alpha: 0.18),
            child: FaIcon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            data.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryData {
  const _HistoryData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.statusLabel,
    required this.statusColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final String statusLabel;
  final Color statusColor;
}

class _PaymentHistoryTile extends StatelessWidget {
  const _PaymentHistoryTile({required this.data});

  final _HistoryData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.85),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: data.statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: FaIcon(data.icon, color: data.statusColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: data.statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: data.statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
