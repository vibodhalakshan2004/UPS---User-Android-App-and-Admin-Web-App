import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class NewsDetailScreen extends StatelessWidget {
  final String id;
  const NewsDetailScreen({super.key, required this.id});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news')
            .doc(id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = (data['title'] as String?) ?? 'Untitled';
          final summary = (data['summary'] as String?) ?? '';
          final date = (data['publishedAt'] as Timestamp?)?.toDate();
          final List imageUrls = (data['imageUrls'] as List?) ?? const [];
          final String? pdfUrl = data['pdfUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'news-title-$id',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${date.toLocal()}'.split(' ')[0],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(summary, style: theme.textTheme.bodyMedium),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final u in imageUrls)
                        GestureDetector(
                          onTap: () => _openUrl(u.toString()),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              u.toString(),
                              height: 140,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (pdfUrl != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(pdfUrl),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Open PDF'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
