import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../shared/widgets.dart';
import '../../shared/models.dart';

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
  int? lastRevision;
  bool get notifications => widget.resource == 'notifications';
  @override
  void didUpdateWidget(ResourcePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final revision = widget.app.dataRevision;
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
    lastRevision = widget.app.dataRevision;
    data = widget.app.repository.read(widget.resource);
  }

  Future<void> refresh() async {
    final next = widget.app.repository.read(widget.resource);
    setState(() => data = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder displays the request failure.
    }
  }

  Future<void> markRead(String path) async {
    try {
      await widget.app.repository.write(path, {});
      if (mounted) await refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark notifications as read.'),
          ),
        );
      }
    }
  }

  String notificationTitle(Map item) {
    final courier =
        item['payload'] is Map && item['payload']['service'] == 'Courier';
    return switch (item['type']) {
      'ride.created' => courier ? 'Courier request sent' : 'Ride request sent',
      'ride.scheduled' => 'Ride scheduled',
      'ride.rescheduled' => 'Departure time changed',
      'ride.matching_open' => 'Scheduled ride matching started',
      'ride.request' => courier ? 'New courier request' : 'New ride request',
      'offer.created' => 'New driver offer',
      'offer.updated' => 'Driver offer updated',
      'offer.expired' => 'Driver offer expired',
      'offer.withdrawn' => 'Driver offer withdrawn',
      'offer.declined' => 'Driver declined the request',
      'driver.assigned' => courier ? 'Courier confirmed' : 'Driver confirmed',
      'ride.arriving' => courier ? 'Courier on the way' : 'Driver on the way',
      'ride.arrived' => courier ? 'Courier at pickup' : 'Driver at pickup',
      'ride.inProgress' => courier ? 'Parcel picked up' : 'Trip started',
      'ride.completed' => courier ? 'Parcel delivered' : 'Trip completed',
      'ride.cancelled' => 'Request cancelled',
      'ride.expired' => 'Request expired',
      'driver.location' => 'Driver location updated',
      _ => '${item['title'] ?? item['type'] ?? 'Notification'}',
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        if (notifications) ...[
          IconButton(
            onPressed: refresh,
            tooltip: 'Refresh notifications',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => markRead('notifications/mark-all-read'),
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
          ),
        ],
      ],
    ),
    body: ContentFrame(
      child: FutureBuilder<Map<String, dynamic>>(
        future: data,
        builder: (_, s) {
          if (s.hasError) {
            return ListView(
              padding: const EdgeInsets.only(top: 24),
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
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading ${widget.title.toLowerCase()}',
              ),
            );
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
                      notifications &&
                          item['id'] != null &&
                          item['read_at'] == null
                      ? () => markRead('notifications/${item['id']}/read')
                      : widget.resource == 'payments/methods' &&
                            item['id'] != null
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
                        : (item['read_at'] == null
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_outlined),
                  ),
                  title: Text(
                    notifications
                        ? notificationTitle(item as Map)
                        : '${item['name'] ?? item['title'] ?? item['type'] ?? 'Notification'}',
                  ),
                  subtitle: switch (DateTime.tryParse('${item['timestamp']}')) {
                    final time? => Text(harareTime(time)),
                    _ =>
                      item['description'] == null
                          ? null
                          : Text('${item['description']}'),
                  },
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
    ),
  );
}
