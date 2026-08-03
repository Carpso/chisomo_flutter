import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../campaigns/campaigns_controller.dart';

class CreateCampaignScreen extends ConsumerStatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  ConsumerState<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goalController = TextEditingController();
  final _minWithdrawController = TextEditingController(text: '200');
  bool _submitting = false;
  bool _hasGoal = true;
  String? _error;
  DateTime? _endsAt;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    _minWithdrawController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final goalK = double.tryParse(_goalController.text.trim()) ?? 0;
    final minK = double.tryParse(_minWithdrawController.text.trim()) ?? 200;

    if (title.isEmpty || description.isEmpty || (_hasGoal && goalK <= 0)) {
      setState(() => _error =
          _hasGoal ? 'Fill in the title, description and goal amount.' : 'Fill in the title and description.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(hostProvider.notifier).createCampaign(
            title: title,
            description: description,
            goalCents: _hasGoal ? (goalK * 100).round() : 0,
            minWithdrawCents: (minK * 100).round(),
            endsAt: _endsAt,
          );
      if (mounted) context.go('/host');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsAt ?? now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Campaign deadline (shown as a countdown)',
    );
    if (picked != null) setState(() => _endsAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New campaign')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Campaign title',
              hintText: 'e.g. UPC Lusaka Youths - Livingstone Conference Trip',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What are you raising funds for? Who benefits?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _hasGoal,
            onChanged: (v) => setState(() => _hasGoal = v),
            title: const Text('Set a fundraising goal'),
            subtitle: const Text('Off = open fundraiser with no target amount'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _goalController,
            enabled: _hasGoal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Goal amount (K)',
              hintText: 'e.g. 15000',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minWithdrawController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minimum payout (K)',
              helperText: 'Funds are sent to your mobile money automatically once available balance reaches this amount',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _pickDeadline,
            icon: Icon(
              _endsAt == null ? LucideIcons.calendarDays : LucideIcons.calendarCheck,
              size: 18,
            ),
            label: Text(
              _endsAt == null
                  ? 'Optional: set a campaign deadline'
                  : 'Deadline: ${_endsAt!.toLocal().toString().split(' ')[0]} (tap to change)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _create,
            child: _submitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create campaign'),
          ),
        ],
      ),
    );
  }
}
