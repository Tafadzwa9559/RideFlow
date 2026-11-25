import 'package:flutter/material.dart';

import '../../core/map_view.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import 'booking_controller.dart';
import 'departure_picker.dart';

class BookingFields extends StatelessWidget {
  const BookingFields({super.key, required this.booking});
  final BookingController booking;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: booking,
    builder: (context, _) {
      final q = booking.quote;
      final currency = booking.currency;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!booking.intercity && !booking.courier)
            Wrap(
              spacing: 8,
              children: ['Standard', 'Comfort', 'XL']
                  .map(
                    (c) => ChoiceChip(
                      label: Text(
                        'Trivia $c\n${c == 'XL' ? '6 seats' : '4 seats'}',
                      ),
                      selected: booking.category == c,
                      onSelected: booking.submitting
                          ? null
                          : (_) => booking.setCategory(c),
                    ),
                  )
                  .toList(),
            ),
          if (booking.intercity) ...[
            DropdownButtonFormField<int>(
              initialValue: booking.passengerCount,
              decoration: const InputDecoration(
                labelText: 'Passengers (up to 6)',
              ),
              items: [
                for (var count = 1; count <= 6; count++)
                  DropdownMenuItem(value: count, child: Text('$count')),
              ],
              onChanged: booking.submitting
                  ? null
                  : (count) => booking.setIntercityDetails(count: count),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: booking.luggage,
              decoration: const InputDecoration(labelText: 'Luggage'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No luggage')),
                DropdownMenuItem(value: 'small', child: Text('Small bags')),
                DropdownMenuItem(value: 'large', child: Text('Large bags')),
              ],
              onChanged: booking.submitting
                  ? null
                  : (bags) => booking.setIntercityDetails(bags: bags),
            ),
          ],
          const SizedBox(height: 16),
          if (booking.courier) CourierFields(booking: booking),
          if (!booking.courier)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(
                booking.departureAt != null
                    ? harareTime(booking.departureAt!)
                    : 'Leave now',
              ),
              subtitle: const Text('Choose a departure time'),
              trailing: booking.departureAt == null
                  ? null
                  : IconButton(
                      tooltip: 'Leave now',
                      onPressed: booking.submitting
                          ? null
                          : () => booking.setDeparture(null),
                      icon: const Icon(Icons.close),
                    ),
              onTap: booking.submitting
                  ? null
                  : () async {
                      final time = await pickDeparture(
                        context,
                        current: booking.departureAt,
                      );
                      if (time != null && context.mounted) {
                        booking.setDeparture(time);
                      }
                    },
            ),
          if (booking.departureAt != null)
            const Text(
              'Matching opens 15 minutes before departure. A driver is confirmed after you accept an offer.',
            ),
          const SizedBox(height: 12),
          if (booking.quoting) ...[
            const LinearProgressIndicator(semanticsLabel: 'Calculating route'),
            const SizedBox(height: 8),
            const Text('Calculating driving route and fare…'),
          ],
          if (q != null)
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route preview',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${booking.app.distanceLabel(q.metres)} · ${(q.seconds / 60).ceil()} min',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  if (q.suggestedCents case final suggested?)
                    AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      child: Text(
                        'Suggested fare: ${money(suggested, currency: currency)}',
                        key: ValueKey('${q.id}-${q.suggestedCents}'),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Minimum allowed fare: ${money(q.minimumCents, currency: currency)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          if (q?.routingProvider == 'Geoapify') const GeoapifyAttribution(),
          if (booking.notice != null) InlineNotice(booking.notice!),
          if (booking.error != null)
            InlineNotice(booking.error!, isError: true),
          if (booking.pickup != null &&
              booking.destination != null &&
              !booking.quoting)
            TextButton.icon(
              onPressed: booking.submitting ? null : booking.refreshQuote,
              icon: const Icon(Icons.refresh),
              label: const Text('Recalculate route & fare'),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: booking.fare,
                  enabled: !booking.submitting,
                  onChanged: booking.editFare,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Offer your fare',
                    prefixText: '${currencySymbol(currency)} ',
                    suffixText: 'USD',
                    errorMaxLines: 3,
                    hintText: '0.00',
                    errorText: booking.fare.text.isEmpty
                        ? null
                        : booking.fareError,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    onPressed: booking.submitting
                        ? null
                        : () => booking.adjustFare(
                            BookingController.fareStepCents,
                          ),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Increase offer by 0.50 USD',
                  ),
                  IconButton(
                    onPressed: booking.submitting
                        ? null
                        : () => booking.adjustFare(
                            -BookingController.fareStepCents,
                          ),
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Decrease offer by 0.50 USD',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (booking.quote?.suggestedCents != null)
            TextButton(
              onPressed: booking.submitting
                  ? null
                  : booking.resetFareToSuggested,
              child: const Text('Reset to Suggested Fare'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: booking.note,
            enabled: !booking.submitting,
            maxLength: 250,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Passenger note (optional)',
              hintText: 'Any route notes or preferences for the driver',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          if (booking.fare.text.isNotEmpty && booking.fareError == null)
            Text(
              'Your offered fare: ${money(parseFare(booking.fare.text), currency: currency)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 6),
          const Text(
            'The fare is agreed when you accept a driver offer.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 18),
          ActionButton(
            booking.courier
                ? 'Request courier'
                : (booking.departureAt == null
                      ? 'Request ride'
                      : 'Schedule ride'),
            booking.canSubmit ? booking.submit : null,
            busy: booking.submitting || booking.app.busy,
          ),
        ],
      );
    },
  );
}

class CourierFields extends StatelessWidget {
  const CourierFields({super.key, required this.booking});
  final BookingController booking;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (key, label, limit, type) in [
        ('sender_name', 'Sender name', 100, TextInputType.name),
        ('sender_phone', 'Sender phone', 30, TextInputType.phone),
        ('recipient_name', 'Recipient name', 100, TextInputType.name),
        ('recipient_phone', 'Recipient phone', 30, TextInputType.phone),
        ('description', 'Parcel description', 250, TextInputType.text),
        (
          'instructions',
          'Delivery instructions (optional)',
          250,
          TextInputType.text,
        ),
        (
          'weight_kg',
          'Approximate weight (kg)',
          6,
          const TextInputType.numberWithOptions(decimal: true),
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            key: ValueKey(key),
            initialValue: '${booking.parcel[key] ?? ''}',
            enabled: !booking.submitting,
            maxLength: limit,
            keyboardType: type,
            decoration: InputDecoration(labelText: label, counterText: ''),
            onChanged: (value) => booking.setParcelValue(
              key,
              key == 'weight_kg' ? double.tryParse(value) : value,
            ),
          ),
        ),
      DropdownButtonFormField<String>(
        initialValue: booking.parcel['size'] as String,
        decoration: const InputDecoration(labelText: 'Parcel size'),
        items: const [
          DropdownMenuItem(value: 'small', child: Text('Small')),
          DropdownMenuItem(value: 'medium', child: Text('Medium')),
          DropdownMenuItem(value: 'large', child: Text('Large')),
        ],
        onChanged: booking.submitting
            ? null
            : (value) => booking.setParcelValue('size', value),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'The parcel contains no hazardous, prohibited or illegal goods.',
        ),
        value: booking.parcel['permitted_goods'] == true,
        onChanged: booking.submitting
            ? null
            : (value) => booking.setParcelValue('permitted_goods', value),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      const Text('The sender and assigned courier can see handover details.'),
    ],
  );
}
