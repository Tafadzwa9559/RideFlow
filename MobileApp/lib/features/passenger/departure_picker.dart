import 'package:flutter/material.dart';

import '../../shared/models.dart';

Future<DateTime?> pickDeparture(
  BuildContext context, {
  DateTime? current,
}) async {
  final now = DateTime.now().toUtc().add(harareOffset);
  final earliest = now.add(const Duration(minutes: 16));
  final latest = now.add(const Duration(days: 30));
  final existing = current?.toUtc().add(harareOffset);
  final initial = existing != null && existing.isAfter(earliest)
      ? existing
      : earliest;
  final date = await showDatePicker(
    context: context,
    helpText: 'Departure date · Harare',
    initialDate: initial,
    firstDate: earliest,
    lastDate: latest,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    helpText: 'Departure time · Harare (CAT)',
    initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
  );
  if (time == null || !context.mounted) return null;
  final local = DateTime.utc(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (!local.isAfter(now.add(const Duration(minutes: 15))) ||
      local.isAfter(latest)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Choose a departure more than 15 minutes and up to 30 days from now.',
        ),
      ),
    );
    return null;
  }
  return local.subtract(harareOffset);
}
