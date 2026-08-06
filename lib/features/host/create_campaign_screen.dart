import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../campaigns/campaigns_controller.dart';

class CreateCampaignScreen extends ConsumerStatefulWidget {
  final int? campaignId;

  const CreateCampaignScreen({super.key, this.campaignId});

  @override
  ConsumerState<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goalController = TextEditingController();
  final _minWithdrawController = TextEditingController(text: '5');
  bool _submitting = false;
  bool _hasGoal = true;
  bool _editing = false;
  String? _error;
  DateTime? _endsAt;
  XFile? _logo;
  String? _existingLogoUrl;

  @override
  void initState() {
    super.initState();
    if (widget.campaignId != null) {
      _editing = true;
      _loadCampaign(widget.campaignId!);
    }
  }

  Future<void> _loadCampaign(int campaignId) async {
    try {
      final res = await ref.read(apiClientProvider).get('/api/campaigns/$campaignId');
      if (!mounted) return;
      final c = res;
      _titleController.text = c['title'] as String? ?? '';
      _descriptionController.text = c['description'] as String? ?? '';
      final goalCents = c['goalCents'] as int? ?? 0;
      _hasGoal = goalCents > 0;
      _goalController.text = _hasGoal ? (goalCents / 100).toString() : '';
      final minWithdrawCents = c['minWithdrawCents'] as int? ?? 200;
      _minWithdrawController.text = (minWithdrawCents / 100).toString();
      _endsAt = c['endsAt'] != null
          ? DateTime.tryParse(c['endsAt'] as String)
          : null;
      _existingLogoUrl = c['logoUrl'] as String?;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load campaign data.');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    _minWithdrawController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file != null) setState(() => _logo = file);
  }

  Future<void> _save() async {
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
      final api = ref.read(apiClientProvider);
      final body = {
        'title': title,
        'description': description,
        'goalCents': _hasGoal ? (goalK * 100).round() : 0,
        'minWithdrawCents': (minK * 100).round(),
        if (_endsAt != null) 'endsAt': _endsAt!.toIso8601String().split('T')[0],
      };

       if (_editing && widget.campaignId != null) {
         await api.updateCampaign(widget.campaignId!, body);
         if (_logo != null) {
           try {
             final bytes = await _logo!.readAsBytes();
             await api.uploadLogo(widget.campaignId!, bytes, _logo!.name);
           } catch (_) {}
         }
          ref.invalidate(campaignsProvider);
          ref.invalidate(campaignDetailProvider(widget.campaignId!));
          if (mounted) context.go('/campaign/${widget.campaignId}');
      } else {
        final res = await ref.read(hostProvider.notifier).createCampaign(
              title: title,
              description: description,
              goalCents: _hasGoal ? (goalK * 100).round() : 0,
              minWithdrawCents: (minK * 100).round(),
              endsAt: _endsAt,
            );
        final campaignId = res['id'] as int?;
        if (campaignId != null && _logo != null) {
          try {
            final bytes = await _logo!.readAsBytes();
            await api.uploadLogo(campaignId, bytes, _logo!.name);
          } catch (_) {
            // Logo upload is best-effort; the campaign is already live.
          }
        }
        if (mounted) context.go('/host');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save the campaign. Check your connection and try again.',
        );
      }
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(_editing ? 'Edit campaign' : 'New campaign')),
      body: ListView(
        padding: EdgeInsets.all(16).copyWith(
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Campaign title',
              hintText: 'e.g. UPC Lusaka Youths - Livingstone Conference Trip',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _pickLogo,
            icon: Icon(
              _logo == null ? LucideIcons.imagePlus : LucideIcons.image,
              size: 18,
            ),
            label: Text(
              _logo != null
                  ? 'Photo selected — tap to change'
                  : (_editing && _existingLogoUrl != null
                      ? 'Logo already uploaded — tap to change'
                      : 'Add a photo (optional)'),
            ),
          ),
          if (_logo != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.file(
                  File(_logo!.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          if (_editing && _existingLogoUrl != null && _logo == null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.network(
                  _existingLogoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Current logo (tap "Add a photo" above to replace)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
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
              helperText:
                  'Funds are sent to your mobile money automatically once your available balance reaches this amount (default K5). '
                  'On payout, Lipila charges 1.5% and Kingdom Sponsor charges 1% (min K3). '
                  'Example: a K100 payout delivers K85.50 to your phone.',
              helperMaxLines: 4,
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
          if (_editing) ...[
            const SizedBox(height: 8),
            Text(
              'Changes are applied immediately and propagate across the platform within seconds.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? SizedBox(
                    width: 22, height: 22,
                    child: AppIconSpinner(size: 22, color: Colors.white),
                  )
                : Text(_editing ? 'Update campaign' : 'Create campaign'),
          ),
        ],
      ),
    );
  }
}
