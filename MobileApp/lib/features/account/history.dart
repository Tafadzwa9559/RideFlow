import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import 'support.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.app});
  final AppController app;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String filter = 'All';
  DateTimeRange? range;
  @override
  Widget build(BuildContext context) {
    final records = widget.app.history
        .where(
          (r) =>
              (filter == 'All' ||
                  (filter == 'Completed'
                      ? r.status == RideStatus.completed
                      : r.status == RideStatus.cancelled)) &&
              (range == null ||
                  (!r.createdAt.isBefore(range!.start.toUtc()) &&
                      r.createdAt.isBefore(
                        range!.end.add(const Duration(days: 1)).toUtc(),
                      ))),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your activity'),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final selected = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (mounted) {
                setState(() => range = selected);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.app.perform(widget.app.sync);
          if (mounted) setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 8,
              children: ['All', 'Completed', 'Cancelled']
                  .map(
                    (v) => ChoiceChip(
                      label: Text(v),
                      selected: filter == v,
                      onSelected: (_) => setState(() => filter = v),
                    ),
                  )
                  .toList(),
            ),
            if (range != null)
              TextButton(
                onPressed: () => setState(() => range = null),
                child: const Text('Clear date filter'),
              ),
            ErrorNotice(widget.app),
            if (records.isEmpty)
              const EmptyState('No rides yet.', 'Your trips will appear here.'),
            for (final r in records)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: pale,
                  child: Icon(Icons.local_taxi_outlined, color: darkGreen),
                ),
                title: Text(r.destination.name),
                subtitle: Text(
                  '${DateFormat('d MMM, HH:mm').format(r.createdAt.toUtc().add(const Duration(hours: 2)))} CAT\n${statusLabel(r.status)}',
                ),
                trailing: Text(money(r.cents, currency: r.currency)),
                onTap: () =>
                    openPage(context, ReceiptPage(app: widget.app, ride: r)),
              ),
            if (widget.app.historyNext != null)
              OutlinedButton(
                onPressed: widget.app.busy
                    ? null
                    : () async {
                        await widget.app.moreHistory();
                        if (mounted) setState(() {});
                      },
                child: const Text('Load more'),
              ),
          ],
        ),
      ),
    );
  }
}

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.app, required this.ride});
  final AppController app;
  final Ride ride;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trip details')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Brand(),
        const SizedBox(height: 24),
        Text(
          statusLabel(ride.status),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text('${ride.pickup.name}\n↓\n${ride.destination.name}'),
        const Divider(height: 40),
        Text(
          money(ride.cents, currency: ride.currency),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const Text(
          'Please pay your driver directly using your selected payment method.',
        ),
        const SizedBox(height: 12),
        Text(
          'Payment method: ${directPaymentLabel(ride.paymentMethod, ride.paymentMethodName)}',
        ),
        Text('Trip reference: ${ride.id}'),
        if (ride.driver != null)
          Text(
            '${ride.driver!.name}\n${ride.driver!.vehicle} · ${ride.driver!.plate}',
          ),
        const SizedBox(height: 24),
        const Text(
          'This trip summary is not a payment confirmation. Trivia does not collect or verify payment.',
        ),
        if (ride.status == RideStatus.completed) ...[
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => openPage(
              context,
              FeedbackPage(
                app: app,
                title: 'Rate your journey',
                resource: 'rides/${ride.id}/review',
              ),
            ),
            child: const Text('Rating & review'),
          ),
        ],
        OutlinedButton(
          onPressed: () => openPage(
            context,
            FeedbackPage(
              app: app,
              title: 'Trip dispute',
              resource: 'rides/${ride.id}/dispute',
            ),
          ),
          child: const Text('Report a problem'),
        ),
      ],
    ),
  );
}
