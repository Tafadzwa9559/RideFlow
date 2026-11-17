import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../shared/widgets.dart';

class ResourcePage extends StatefulWidget {
  const ResourcePage({
    super.key,
    required this.app,
    required this.title,
    required this.resource,
    required this.empty,
  });
  final AppController app;
  final String title, resource, empty;
  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  late Future<Map<String, dynamic>> data;
  String lastRevision = '';
  @override
  void didUpdateWidget(ResourcePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final revision = '${widget.app.history.length}-${widget.app.ride?.status}';
    if (revision != lastRevision) {
      lastRevision = revision;
      data = widget.app.repository.read(widget.resource);
    }
  }

  Future<void> more(Map<String, dynamic> current) async {
    try {
      final page = await widget.app.repository.read(current['next'] as String);
      if (mounted) {
        setState(
          () => data = Future.value({
            ...page,
            'items': [
              ...(current['items'] as List),
              ...(page['items'] as List? ?? []),
            ],
          }),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load the next page. Retry.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    data = widget.app.repository.read(widget.resource);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (_, s) {
        if (s.hasError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EmptyState(
                'Unable to load',
                'Check your connection and try again.',
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: OutlinedButton(
                  onPressed: () => setState(
                    () => data = widget.app.repository.read(widget.resource),
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ],
          );
        }
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = s.data!['items'] as List? ?? [];
        if (items.isEmpty) {
          return EmptyState(
            widget.title,
            widget.empty,
            icon: Icons.inbox_outlined,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.resource == 'payments/methods')
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Only platform-enabled payment methods appear here. The final payment choice must be confirmed with your booking.',
                ),
              ),
            for (final item in items)
              ListTile(
                onTap:
                    widget.resource == 'payments/methods' && item['id'] != null
                    ? () {
                        widget.app.selectPayment(
                          '${item['id']}',
                          '${item['name']}',
                        );
                        Navigator.maybePop(context);
                      }
                    : null,
                leading: Icon(
                  widget.resource.startsWith('payments')
                      ? Icons.payments_outlined
                      : Icons.notifications_outlined,
                ),
                title: Text(
                  '${item['name'] ?? item['title'] ?? item['type'] ?? 'Notification'}',
                ),
                subtitle: item['description'] == null
                    ? null
                    : Text('${item['description']}'),
              ),
            if (s.data!['next'] != null)
              OutlinedButton(
                onPressed: () => more(s.data!),
                child: const Text('Load more'),
              ),
          ],
        );
      },
    ),
  );
}
