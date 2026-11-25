import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/controller.dart';
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
              (switch (filter) {
                'Upcoming' => r.status == RideStatus.scheduled,
                'Ongoing' => r.active && r.status != RideStatus.scheduled,
                'Completed' => r.status == RideStatus.completed,
                'Cancelled' =>
                  r.status == RideStatus.cancelled ||
                      r.status == RideStatus.expired,
                _ => true,
              }) &&
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
      body: ContentFrame(
        child: RefreshIndicator(
          onRefresh: () async {
            await widget.app.perform(widget.app.sync);
            if (mounted) setState(() {});
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                children:
                    ['All', 'Upcoming', 'Ongoing', 'Completed', 'Cancelled']
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
              if (records.isEmpty && widget.app.error == null)
                EmptyState(
                  filter == 'All' && range == null
                      ? 'No rides yet.'
                      : 'No matching rides',
                  filter == 'All' && range == null
                      ? 'Your trips will appear here.'
                      : 'Change the filters to see more trips.',
                ),
              for (final r in records)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: Icon(
                          Icons.local_taxi_outlined,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      title: Text(r.destination.name),
                      subtitle: Text(
                        '${DateFormat('d MMM, HH:mm').format((r.departureAt ?? r.createdAt).toUtc().add(harareOffset))} CAT\n${deliveryStatusLabel(r)} · ${money(r.cents, currency: r.currency)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      isThreeLine: true,
                      onTap: () => openPage(
                        context,
                        ReceiptPage(app: widget.app, ride: r),
                      ),
                    ),
                  ),
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
    body: ContentFrame(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            deliveryStatusLabel(ride),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(ride.serviceName),
          Text(harareTime(ride.departureAt ?? ride.createdAt)),
          if (ride.distanceMetres case final distance?)
            Text('${app.distanceLabel(distance)} by road'),
          const SizedBox(height: 16),
          InfoCard(
            child: RouteStops(
              pickup: ride.pickup.name,
              stops: ride.stops.map((stop) => stop.name).toList(),
              destination: ride.destination.name,
            ),
          ),
          const Divider(height: 40),
          Text(
            money(ride.cents, currency: ride.currency),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text('Trip reference: ${ride.id}'),
          if (ride.driver != null)
            Text(
              '${ride.driver!.name}\n${ride.driver!.vehicle} · ${ride.driver!.plate}',
            ),
          const SizedBox(height: 24),
          const Text(
            'This trip summary is not a payment confirmation. Trivia does not collect or verify payment.',
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share trip summary'),
            onPressed: () async {
              final box = context.findRenderObject() as RenderBox?;
              await SharePlus.instance.share(
                ShareParams(
                  subject: 'Trivia trip summary',
                  text: [
                    '${ride.serviceName} · ${harareTime(ride.departureAt ?? ride.createdAt)}',
                    deliveryStatusLabel(ride),
                    [
                      ride.pickup,
                      ...ride.stops,
                      ride.destination,
                    ].map((place) => place.name).join(' → '),
                    if (ride.distanceMetres case final distance?)
                      '${app.distanceLabel(distance)} by road',
                    '${ride.agreedCents == null ? 'Offered fare' : 'Agreed fare'}: ${money(ride.cents, currency: ride.currency)}',
                  ].join('\n'),
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                ),
              );
            },
          ),
          if (!app.driverMode && app.ride?.active != true && !ride.active)
            OutlinedButton.icon(
              icon: const Icon(Icons.repeat),
              label: const Text('Rebook this route'),
              onPressed: () {
                app.rebook(ride);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
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
    ),
  );
}
