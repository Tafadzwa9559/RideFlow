import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/repository.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import 'booking_controller.dart';

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
          const SizedBox(height: 16),
          if (booking.quoting) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Calculating driving route and fare…'),
          ],
          if (q != null) ...[
            if (booking.app.repository is DemoRepository)
              const Text(
                'Demo estimate: fictional distance, duration and fare.',
              ),
            Text(
              '${(q.metres / 1000).toStringAsFixed(1)} km · ${(q.seconds / 60).ceil()} min',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              child: Text(
                'Suggested fare: ${money(q.suggestedCents!, currency: currency)}',
                key: ValueKey('${q.id}-${q.suggestedCents}'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Minimum allowed fare: ${money(q.minimumCents, currency: currency)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (booking.notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                booking.notice!,
                style: const TextStyle(color: darkGreen),
              ),
            ),
          if (booking.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                booking.error!,
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Offer your fare',
                    prefixText: '${currencySymbol(currency)} ',
                    hintText: '0.00',
                    errorText: booking.fare.text.isEmpty ? null : booking.fareError,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    onPressed: () => booking.adjustFare(BookingController.fareStepCents),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Increase offer by 0.50 USD',
                  ),
                  IconButton(
                    onPressed: () => booking.adjustFare(-BookingController.fareStepCents),
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Decrease offer by 0.50 USD',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Suggested fare — you can change this amount',
                style: TextStyle(fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: booking.quote?.suggestedCents == null ? null : booking.resetFareToSuggested,
                child: const Text('Reset to Suggested Fare'),
              ),
            ],
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
          const SizedBox(height: 16),
          const Text('Fare currency: USD'),
          const SizedBox(height: 20),
          Text(
            'Payment method',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (booking.loadingMethods) const LinearProgressIndicator(),
          if (booking.configurationError != null)
            TextButton(
              onPressed: booking.loadConfiguration,
              child: Text(booking.configurationError!),
            ),
          for (final group in [
            ('mobile_money', 'Mobile money'),
            ('cash', 'Cash'),
          ]) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                group.$2,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final m in booking.methods.where((v) => v.kind == group.$1))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: booking.method?.id == m.id ? pale : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: booking.method?.id == m.id
                          ? darkGreen
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      dense: true,
                      enabled: !booking.submitting,
                      leading: Icon(
                        m.kind == 'cash'
                            ? Icons.payments_outlined
                            : Icons.phone_android_outlined,
                        color: darkGreen,
                      ),
                      title: Text(m.name),
                      subtitle: Text(m.description),
                      trailing: Icon(
                        booking.method?.id == m.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: darkGreen,
                      ),
                      onTap: () => booking.setPayment(m),
                    ),
                  ),
                ),
              ),
          ],
          if (booking.paymentError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                booking.paymentError!,
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          const SizedBox(height: 16),
          if (booking.fare.text.isNotEmpty && booking.fareError == null)
            Text(
              'Your offered fare: ${money(parseFare(booking.fare.text), currency: currency)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          Text('Payment method: ${booking.method?.name ?? 'Choose a method'}'),
          const SizedBox(height: 6),
          const Text(
            'This is your offer, not a driver-accepted price. The agreed fare is confirmed only after a driver offer is accepted.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 18),
          ActionButton(
            'Request ride',
            booking.canSubmit ? booking.submit : null,
            busy: booking.submitting || booking.app.busy,
          ),
        ],
      );
    },
  );
}
