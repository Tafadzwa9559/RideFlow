import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import 'legal_content.dart';

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.documentId});
  final String documentId;
  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late Future<LegalContent> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = LegalContent.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      title: Text(
        widget.documentId == 'terms' ? 'Terms & Conditions' : 'Privacy Policy',
      ),
    ),
    body: FutureBuilder<LegalContent>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load this document.'),
                TextButton(
                  onPressed: () => setState(() {
                    _contentFuture = LegalContent.load();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final legalContent = snapshot.data!;
        final doc = legalContent.document(widget.documentId);

        return SelectionArea(
          child: SingleChildScrollView(
            key: PageStorageKey(widget.documentId),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Brand(),
                    Semantics(
                      header: true,
                      child: Text(
                        doc['title'] as String,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (legalContent.status != 'published')
                      Text(
                        legalContent.reviewNotice,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Version: ${legalContent.version}\nEffective date: ${legalContent.effectiveDate}',
                      style: const TextStyle(height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      legalContent.attribution,
                      style: const TextStyle(height: 1.6),
                    ),
                    for (final (index, section)
                        in (doc['sections'] as List).indexed) ...[
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        child: Text(
                          '${index + 1}. ${section['title']}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(height: 1.4),
                        ),
                      ),
                      for (final paragraph in section['paragraphs'] as List)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            paragraph as String,
                            style: const TextStyle(fontSize: 16, height: 1.65),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    const LegalLinks(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final (id, title) in [
        ('terms', 'Terms & Conditions'),
        ('privacy', 'Privacy Policy'),
      ])
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => openPage(context, LegalPage(documentId: id)),
          child: Text(title),
        ),
    ],
  );
}
