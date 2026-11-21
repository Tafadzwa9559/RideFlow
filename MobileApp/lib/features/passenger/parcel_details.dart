import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/controller.dart';
import '../../core/api_error.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';

class ParcelDetailsPage extends StatefulWidget {
  const ParcelDetailsPage({super.key, required this.app, required this.ride});
  final AppController app;
  final Ride ride;

  @override
  State<ParcelDetailsPage> createState() => _ParcelDetailsPageState();
}

class _ParcelDetailsPageState extends State<ParcelDetailsPage> {
  Map<String, dynamic>? details;
  Uint8List? photo;
  bool loading = false;
  String? error;
  final code = TextEditingController();
  String get resource => 'rides/${widget.ride.id}/parcel';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> refresh({String? upload}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (upload != null) {
        await widget.app.repository.uploadParcelPhoto(widget.ride.id, upload);
      }
      final result = await widget.app.repository.read(resource);
      if (!mounted) return;
      setState(() {
        details = result;
        photo = null;
      });
      if (result['has_photo'] == true) {
        final image = await widget.app.repository.parcelPhoto(widget.ride.id);
        if (mounted) setState(() => photo = Uint8List.fromList(image));
      }
    } catch (problem) {
      if (mounted) setState(() => error = apiErrorMessage(problem));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> selectPhoto() async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      );
      if (selected != null && mounted) await refresh(upload: selected.path);
    } catch (problem) {
      if (mounted) setState(() => error = apiErrorMessage(problem));
    }
  }

  Future<void> deliver() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.app.repository.write('$resource/confirm', {
        'code': code.text.trim(),
      });
      await widget.app.perform(widget.app.sync);
      if (mounted) Navigator.pop(context);
    } catch (problem) {
      if (mounted) setState(() => error = apiErrorMessage(problem));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.app,
    builder: (context, _) {
      final app = widget.app;
      final ride = app.ride?.id == widget.ride.id ? app.ride! : widget.ride;
      final parcel = details?['parcel'] as Map?;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Parcel handover'),
          actions: [
            IconButton(
              onPressed: loading ? null : refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh parcel details',
            ),
          ],
        ),
        body: ContentFrame(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (loading) const LinearProgressIndicator(),
              if (error != null) InlineNotice(error!, isError: true),
              if (parcel != null) ...[
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${parcel['description']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('${parcel['size']} · ${parcel['weight_kg']} kg'),
                      if ((parcel['instructions'] as String? ?? '').isNotEmpty)
                        Text('${parcel['instructions']}'),
                      const SizedBox(height: 12),
                      Text('Sender · ${parcel['sender_name']}'),
                      Text('${parcel['sender_phone']}'),
                      const SizedBox(height: 8),
                      Text('Recipient · ${parcel['recipient_name']}'),
                      Text('${parcel['recipient_phone']}'),
                    ],
                  ),
                ),
                if (photo != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      photo!,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
                if (!app.driverMode && ride.active)
                  TextButton.icon(
                    onPressed: loading ? null : selectPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      photo == null
                          ? 'Add parcel photo'
                          : 'Replace parcel photo',
                    ),
                  ),
                if (!app.driverMode &&
                    ride.status == RideStatus.inProgress) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Give this code to the recipient. They should show it to the courier at handover.',
                  ),
                  SelectableText(
                    '${details?['confirmation_code'] ?? 'Refresh to get your code'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
                if (app.driverMode && ride.status == RideStatus.inProgress) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Recipient’s 8-digit code',
                    ),
                    maxLength: 8,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  ActionButton(
                    'Confirm delivery',
                    RegExp(r'^\d{8}$').hasMatch(code.text) ? deliver : null,
                    busy: loading,
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}
