import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

/// Online sample event poster images (picsum.photos, no key) grouped by theme.
const kEventSampleImages = <({String label, String url})>[
  (label: 'Gala / banquet', url: 'https://picsum.photos/seed/ks-event-gala/1200/630'),
  (label: 'Concert / music', url: 'https://picsum.photos/seed/ks-event-concert/1200/630'),
  (label: 'Conference / talk', url: 'https://picsum.photos/seed/ks-event-conf/1200/630'),
  (label: 'Church / worship', url: 'https://picsum.photos/seed/ks-event-church/1200/630'),
  (label: 'Charity / fundraiser', url: 'https://picsum.photos/seed/ks-event-charity/1200/630'),
  (label: 'Sports / games', url: 'https://picsum.photos/seed/ks-event-sports/1200/630'),
  (label: 'Festival / open air', url: 'https://picsum.photos/seed/ks-event-fest/1200/630'),
  (label: 'Workshop / training', url: 'https://picsum.photos/seed/ks-event-workshop/1200/630'),
];

/// Bundled REAL event poster assets (offline-safe, uploaded to R2 on save).
const kEventBundledSamples = <({String label, String asset})>[
  (label: 'Gala', asset: 'assets/event_samples/event_gala.jpg'),
  (label: 'Concert', asset: 'assets/event_samples/event_concert.jpg'),
  (label: 'Conference', asset: 'assets/event_samples/event_conference.jpg'),
  (label: 'Church', asset: 'assets/event_samples/event_church.jpg'),
  (label: 'Charity', asset: 'assets/event_samples/event_charity.jpg'),
  (label: 'Sports', asset: 'assets/event_samples/event_sports.jpg'),
  (label: 'Festival', asset: 'assets/event_samples/event_festival.jpg'),
  (label: 'Workshop', asset: 'assets/event_samples/event_workshop.jpg'),
];

/// Dedicated, best-in-class Event creation UI (distinct from Campaigns).
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _goalController = TextEditingController();
  final _tierNameController = TextEditingController();
  final _tierPriceController = TextEditingController();
  String _category = 'Other';
  bool _isPrivate = false;
  bool _hasGoal = false;
  bool _ticketed = false;
  int _capacity = 0;
  final List<({String name, int amountCents})> _tiers = [];
  DateTime? _start;
  DateTime? _end;
  XFile? _logo;
  Uint8List? _sampleBytes;
  String? _sampleImageUrl;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _goalController.dispose();
    _tierNameController.dispose();
    _tierPriceController.dispose();
    super.dispose();
  }

  static String _kwachaText(int cents) {
    final t = (cents / 100).toStringAsFixed(2);
    return t.endsWith('.00') ? t.substring(0, t.length - 3) : t;
  }

  Future<void> _pickStart() async {
    final picked = await showDateTimePicker('Event start', _start ?? DateTime.now().add(const Duration(days: 7)));
    if (picked != null) {
      setState(() {
        _start = picked;
        if (_end == null || _end!.isBefore(picked)) _end = picked.add(const Duration(hours: 2));
      });
    }
  }

  Future<void> _pickEnd() async {
    final initial = _end ?? _start?.add(const Duration(hours: 2)) ?? DateTime.now().add(const Duration(days: 7));
    final picked = await showDateTimePicker('Event end', initial, first: _start);
    if (picked != null) setState(() => _end = picked);
  }

  Future<DateTime?> showDateTimePicker(String title, DateTime initial, {DateTime? first}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: (first ?? DateTime.now()).toLocal(),
      lastDate: DateTime(initial.year + 3),
      helpText: '$title — date',
    );
    if (date == null) return null;
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: '$title — time',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 85);
    if (file != null) setState(() { _logo = file; _sampleBytes = null; _sampleImageUrl = null; });
  }

  Future<void> _pickBundledSample(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final name = asset.split('/').last;
      setState(() {
        _sampleBytes = data.buffer.asUint8List();
        _logo = XFile.fromData(data.buffer.asUint8List(), name: name);
        _sampleImageUrl = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load that poster.')),
        );
      }
    }
  }

  bool _bundledSelected(String asset) => _logo?.name == asset.split('/').last;

  void _addInlineTier() {
    final name = _tierNameController.text.trim();
    final price = double.tryParse(_tierPriceController.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) {
      setState(() => _error = 'Enter a ticket name and a valid price.');
      return;
    }
    if (_tiers.length >= 10) return;
    setState(() {
      _tiers.add((name: name, amountCents: (price * 100).round()));
      _tierNameController.clear();
      _tierPriceController.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      setState(() => _error = 'Fill in the event title and description.');
      return;
    }
    if (_start != null && _end != null && !_end!.isAfter(_start!)) {
      setState(() => _error = 'The end time must be after the start time.');
      return;
    }
    if (_ticketed && _tiers.isEmpty) {
      setState(() => _error = 'Add at least one ticket tier, or turn off ticketing.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final goalK = double.tryParse(_goalController.text.trim()) ?? 0;
      final res = await api.post('/api/campaigns', {
        'title': title,
        'description': description,
        'goalCents': _hasGoal && goalK > 0 ? (goalK * 100).round() : 0,
        'minWithdrawCents': 500,
        'category': _category,
        'campaignType': 'event',
        'visibility': _isPrivate ? 'private' : 'public',
        if (_start != null) 'eventDate': _start!.toIso8601String().split('T')[0],
        if (_end != null) 'endsAt': _end!.toIso8601String().split('T')[0],
        if (_venueController.text.trim().isNotEmpty) 'eventVenue': _venueController.text.trim(),
        'eventCapacity': _capacity,
        if (_sampleImageUrl != null) 'imageUrl': _sampleImageUrl,
        if (_ticketed && _tiers.isNotEmpty)
          'eventTiers': [
            for (final t in _tiers) {'name': t.name, 'amountCents': t.amountCents},
          ],
      }, auth: true);

      final eventId = res['id'] as int?;
      if (eventId != null && _logo != null) {
        try {
          final bytes = await _logo!.readAsBytes();
          await api.uploadLogo(eventId, bytes, _logo!.name);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created, but the poster upload failed.')));
          }
        }
      }

      // Make the new event appear immediately on the Events tab.
      ref.invalidate(campaignsProvider);
      ref.invalidate(adminDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created!')));
        context.go('/events');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create the event. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New event')),
      body: ListView(
        padding: EdgeInsets.all(16).copyWith(bottom: 16 + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Event title', hintText: 'e.g. Lusaka Fundraising Gala 2026'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Event description',
              hintText: 'What is this event about? Who is it for? What will funds go towards?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 4),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(LucideIcons.tags, size: 18)),
            child: DropdownButton<String>(
              value: kCampaignCategories.contains(_category) ? _category : 'Other',
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final c in kSortedCategories) DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
              title: const Text('Private event', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Only people with your invite link can see and buy tickets.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              secondary: Icon(_isPrivate ? LucideIcons.lock : LucideIcons.globe, size: 20, color: AppColors.primary),
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _pickStart,
                  icon: const Icon(LucideIcons.play, size: 16, color: AppColors.primary),
                  label: Text(_start == null ? 'Event start' : _fmt(_start!), style: const TextStyle(fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _pickEnd,
                  icon: const Icon(LucideIcons.flag, size: 16, color: AppColors.primary),
                  label: Text(_end == null ? 'Event end' : _fmt(_end!), style: const TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _venueController,
            decoration: const InputDecoration(labelText: 'Venue', hintText: 'e.g. Mulungushi Conference Centre', prefixIcon: Icon(LucideIcons.mapPin, size: 18), isDense: true),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              value: _ticketed,
              onChanged: (v) => setState(() => _ticketed = v),
              title: const Text('Ticketed event', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Sell ticket tiers (Standard, VIP…) — turn on to add tiers.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              secondary: Icon(_ticketed ? LucideIcons.ticket : LucideIcons.ticket, size: 20, color: AppColors.primary),
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          if (_ticketed) ...[
            const SizedBox(height: 8),
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total tickets (0 = unlimited)', isDense: true),
              initialValue: _capacity > 0 ? '$_capacity' : '',
              onChanged: (v) => _capacity = int.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.ticket, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Ticket tiers (${_tiers.length}/10)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('Total tickets: ${_capacity > 0 ? '$_capacity' : 'unlimited'}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            if (_tiers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Add at least one tier below so donors can buy tickets.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            for (int i = 0; i < _tiers.length; i++) ...[
              const SizedBox(height: 6),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  dense: true,
                  leading: Icon(LucideIcons.ticket, size: 18, color: AppColors.primary),
                  title: Text(_tiers[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('${_kwachaText(_tiers[i].amountCents)} per ticket'),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: AppColors.danger),
                    onPressed: () => setState(() => _tiers.removeAt(i)),
                  ),
                ),
              ),
            ],
            // Inline "new tier" form — always visible when ticketed.
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              color: AppColors.primary.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add a ticket tier', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _tierNameController,
                            decoration: const InputDecoration(labelText: 'Ticket name', hintText: 'e.g. Standard', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _tierPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Price (K)', prefixText: 'K ', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _tiers.length >= 10 ? null : _addInlineTier,
                        icon: const Icon(LucideIcons.plus, size: 15),
                        label: const Text('Add tier'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _pickLogo,
            icon: Icon(_logo == null && _sampleImageUrl == null ? LucideIcons.imagePlus : LucideIcons.image, size: 18),
            label: Text(_logo == null && _sampleImageUrl == null ? 'Add a poster photo (optional)' : 'Poster selected — tap to change'),
          ),
          const SizedBox(height: 10),
          Text('Or pick a real event poster:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in kEventBundledSamples)
                GestureDetector(
                  onTap: () => _pickBundledSample(s.asset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _bundledSelected(s.asset) ? AppColors.gold : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Image.asset(s.asset, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 2),
                      Text(s.label, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Or use an online sample poster:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in kEventSampleImages)
                GestureDetector(
                  onTap: () => setState(() {
                    _sampleImageUrl = s.url;
                    _logo = null;
                    _sampleBytes = null;
                  }),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _sampleImageUrl == s.url ? AppColors.gold : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Image.network(s.url, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(LucideIcons.image, color: AppColors.textMuted),
                            )),
                      ),
                      const SizedBox(height: 2),
                      Text(s.label, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
            ],
          ),
          if (_logo != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: _sampleBytes != null
                    ? Image.memory(_sampleBytes!, fit: BoxFit.cover)
                    : Image.file(File(_logo!.path), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ] else if (_sampleImageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.network(_sampleImageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            value: _hasGoal,
            onChanged: (v) => setState(() => _hasGoal = v),
            title: const Text('Set a fundraising goal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('Off = no target amount', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          if (_hasGoal)
            TextField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Goal amount (K)', prefixText: 'K ', isDense: true),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: AppIconSpinner(size: 22, color: Colors.white))
                : const Text('Create event'),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    final local = d.toLocal();
    final date = '${local.year}-${two(local.month)}-${two(local.day)}';
    final time = '${two(local.hour)}:${two(local.minute)}';
    return '$date $time';
  }

  String two(int n) => n.toString().padLeft(2, '0');
}
