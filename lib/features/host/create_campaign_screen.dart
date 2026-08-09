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

/// Bundled sample campaign images hosts can pick without having a photo.
/// Both the original gradient samples and the `_real` CC0/public-domain photos
/// (Wikimedia Commons, Openverse / Flickr CC0, Picsum) are offered.
const kSampleCampaignImages = [
  // Generic gradient samples
  'assets/campaign_samples/sample_1.png',
  'assets/campaign_samples/sample_2.png',
  'assets/campaign_samples/sample_3.png',
  'assets/campaign_samples/sample_4.png',
  'assets/campaign_samples/sample_5.png',
  // Category gradient samples
  'assets/campaign_samples/cat_church_ministry.png',
  'assets/campaign_samples/cat_missions.png',
  'assets/campaign_samples/cat_worship_music.png',
  'assets/campaign_samples/cat_education.png',
  'assets/campaign_samples/cat_bursary.png',
  'assets/campaign_samples/cat_medical.png',
  'assets/campaign_samples/cat_disability.png',
  'assets/campaign_samples/cat_funeral.png',
  'assets/campaign_samples/cat_children.png',
  'assets/campaign_samples/cat_youth_sports.png',
  'assets/campaign_samples/cat_marriage_family.png',
  'assets/campaign_samples/cat_community.png',
  'assets/campaign_samples/cat_food_water.png',
  'assets/campaign_samples/cat_disaster.png',
  'assets/campaign_samples/cat_environment.png',
  // Category real photos
  'assets/campaign_samples/cat_church_ministry_real.jpg',
  'assets/campaign_samples/cat_missions_real.jpg',
  'assets/campaign_samples/cat_worship_music_real.jpg',
  'assets/campaign_samples/cat_education_real.jpg',
  'assets/campaign_samples/cat_bursary_real.jpg',
  'assets/campaign_samples/cat_medical_real.jpg',
  'assets/campaign_samples/cat_disability_real.jpg',
  'assets/campaign_samples/cat_funeral_real.jpg',
  'assets/campaign_samples/cat_children_real.jpg',
  'assets/campaign_samples/cat_youth_sports_real.jpg',
  'assets/campaign_samples/cat_marriage_family_real.jpg',
  'assets/campaign_samples/cat_community_real.jpg',
  'assets/campaign_samples/cat_food_water_real.jpg',
  'assets/campaign_samples/cat_disaster_real.jpg',
  'assets/campaign_samples/cat_environment_real.jpg',
  'assets/campaign_samples/cat_agriculture_real.jpg',
  'assets/campaign_samples/cat_business_real.jpg',
];

/// Suggested sample image per campaign category (falls back to the generic set).
const kSampleImageForCategory = <String, String>{
  'Church & Ministry': 'assets/campaign_samples/cat_church_ministry_real.jpg',
  'Missions & Evangelism': 'assets/campaign_samples/cat_missions_real.jpg',
  'Music & Worship': 'assets/campaign_samples/cat_worship_music_real.jpg',
  'Bible School & Discipleship': 'assets/campaign_samples/cat_church_ministry_real.jpg',
  'Education & School Fees': 'assets/campaign_samples/cat_education_real.jpg',
  'Bursary & Scholarships': 'assets/campaign_samples/cat_bursary_real.jpg',
  'Medical & Health': 'assets/campaign_samples/cat_medical_real.jpg',
  'Disability Support': 'assets/campaign_samples/cat_disability_real.jpg',
  'Funeral & Memorial': 'assets/campaign_samples/cat_funeral_real.jpg',
  'Children & Orphans': 'assets/campaign_samples/cat_children_real.jpg',
  "Women's Empowerment": 'assets/campaign_samples/cat_community_real.jpg',
  'Youth & Sports': 'assets/campaign_samples/cat_youth_sports_real.jpg',
  'Marriage & Family': 'assets/campaign_samples/cat_marriage_family_real.jpg',
  'Elderly Care': 'assets/campaign_samples/cat_funeral_real.jpg',
  'Community Development': 'assets/campaign_samples/cat_community_real.jpg',
  'Food & Hunger Relief': 'assets/campaign_samples/cat_food_water_real.jpg',
  'Water & Sanitation': 'assets/campaign_samples/cat_food_water_real.jpg',
  'Solar & Electricity': 'assets/campaign_samples/cat_environment_real.jpg',
  'Disaster & Emergency Relief': 'assets/campaign_samples/cat_disaster_real.jpg',
  'Refugee & Migrant Support': 'assets/campaign_samples/cat_missions_real.jpg',
  'Prison Ministry': 'assets/campaign_samples/cat_church_ministry_real.jpg',
  'Agriculture & Farming': 'assets/campaign_samples/cat_agriculture_real.jpg',
  'Livestock & Seeds': 'assets/campaign_samples/cat_agriculture_real.jpg',
  'Business & Startups': 'assets/campaign_samples/cat_business_real.jpg',
  'Construction & Buildings': 'assets/campaign_samples/cat_community_real.jpg',
  'Transport & Vehicles': 'assets/campaign_samples/cat_business_real.jpg',
  'Clothing & Household': 'assets/campaign_samples/cat_children_real.jpg',
  'Technology & Devices': 'assets/campaign_samples/cat_education_real.jpg',
  'Weddings & Celebrations': 'assets/campaign_samples/cat_marriage_family_real.jpg',
  'Environmental & Conservation': 'assets/campaign_samples/cat_environment_real.jpg',
};

class CreateCampaignScreen extends ConsumerStatefulWidget {
  final int? campaignId;

  const CreateCampaignScreen({super.key, this.campaignId});

  @override
  ConsumerState<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  static String _kwachaText(int cents) {
    final t = (cents / 100).toStringAsFixed(2);
    return t.endsWith('.00') ? t.substring(0, t.length - 3) : t;
  }
  final _goalController = TextEditingController();
  final _minWithdrawController = TextEditingController(text: '5');
  bool _submitting = false;
  bool _hasGoal = true;
  bool _editing = false;
  String? _error;
  DateTime? _endsAt;
  XFile? _logo;
  Uint8List? _sampleBytes;
  String? _existingLogoUrl;
  String _category = 'Other';
  String _campaignType = 'community';
  bool _isPrivate = false;

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
      final c = res['campaign'] is Map ? (res['campaign'] as Map).cast<String, dynamic>() : res;
      _titleController.text = c['title'] as String? ?? '';
      _descriptionController.text = c['description'] as String? ?? '';
      final goalCents = c['goalCents'] as int? ?? 0;
      _hasGoal = goalCents > 0;
      _goalController.text = _hasGoal ? _kwachaText(goalCents) : '';
      final minWithdrawCents = c['minWithdrawCents'] as int? ?? 200;
      _minWithdrawController.text = _kwachaText(minWithdrawCents);
      _endsAt = c['endsAt'] != null
          ? DateTime.tryParse(c['endsAt'] as String)
          : null;
      _existingLogoUrl = c['logoUrl'] as String?;
      setState(() {
        _category = c['category'] as String? ?? 'Other';
        _campaignType = kCampaignTypes.containsKey(c['campaignType'])
            ? c['campaignType'] as String
            : 'community';
        _isPrivate = (c['visibility'] as String? ?? 'public') == 'private';
      });
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
    if (file != null) {
      setState(() {
        _logo = file;
        _sampleBytes = null;
      });
    }
  }

  Future<void> _pickSample(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final name = assetPath.split('/').last;
      setState(() {
        _sampleBytes = data.buffer.asUint8List();
        _logo = XFile.fromData(data.buffer.asUint8List(), name: name);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load that sample image.')),
        );
      }
    }
  }

  bool _sampleSelected(String assetPath) =>
      _logo != null && _logo!.name == assetPath.split('/').last;

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
        'category': _category,
        'campaignType': _campaignType,
        'visibility': _isPrivate ? 'private' : 'public',
        if (_endsAt != null) 'endsAt': _endsAt!.toIso8601String().split('T')[0],
      };

       if (_editing && widget.campaignId != null) {
         final res = await api.updateCampaign(widget.campaignId!, body);
         if (_logo != null) {
           try {
             final bytes = await _logo!.readAsBytes();
             final logoRes = await api.uploadLogo(widget.campaignId!, bytes, _logo!.name);
             if (mounted && logoRes['logoUrl'] != null) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Campaign image uploaded')),
               );
             }
           } catch (e) {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Image upload failed: $e')),
               );
             }
           }
         }
         // Hosts submit changes for admin review (fraud protection) — the
         // backend returns a message like "submitted for review".
         final msg = res['message'] as String? ?? 'Edit submitted for review';
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
         }
         ref.invalidate(campaignsProvider);
         ref.invalidate(campaignDetailProvider(widget.campaignId!));
         if (mounted) context.go('/host');
     } else {
        final res = await ref.read(hostProvider.notifier).createCampaign(
              title: title,
              description: description,
              goalCents: _hasGoal ? (goalK * 100).round() : 0,
              minWithdrawCents: (minK * 100).round(),
              endsAt: _endsAt,
              category: _category,
              campaignType: _campaignType,
            );
        final campaignId = res['id'] as int?;
        if (campaignId != null && _logo != null) {
          try {
            final bytes = await _logo!.readAsBytes();
            final logoRes = await api.uploadLogo(campaignId, bytes, _logo!.name);
            if (mounted && logoRes['logoUrl'] != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Campaign image uploaded')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Image upload failed: $e')),
              );
            }
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
    final today = DateTime(now.year, now.month, now.day);
    final first = today.add(const Duration(days: 1));
    final last = today.add(const Duration(days: 365 * 2));
    // If an existing deadline is already in the past (or today), fall back to a
    // valid initial date so showDatePicker never asserts on initialDate < firstDate.
    DateTime initial;
    final current = _endsAt;
    if (current != null) {
      final c = DateTime(current.year, current.month, current.day);
      initial = (c.isBefore(first) || c.isAfter(last)) ? first : c;
    } else {
      initial = today.add(const Duration(days: 30));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
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
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(LucideIcons.tags, size: 18),
            ),
            child: DropdownButton<String>(
              value: kCampaignCategories.contains(_category) ? _category : 'Other',
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final c in kCampaignCategories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _category = v);
                // Suggest a matching sample image when the host changes the
                // category and hasn't picked a photo yet.
                if (_logo == null && _existingLogoUrl == null) {
                  final suggested = kSampleImageForCategory[v];
                  if (suggested != null) _pickSample(suggested);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Campaign type',
              prefixIcon: Icon(LucideIcons.tags, size: 18),
            ),
            child: DropdownButton<String>(
              value: kCampaignTypes.containsKey(_campaignType) ? _campaignType : 'community',
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final e in kCampaignTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _campaignType = v);
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
              title: const Text('Private campaign',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text(
                _isPrivate
                    ? 'Hidden from the public list. Only people with your link can see and give to it.'
                    : 'Visible to everyone in the campaign list and on the home carousel.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              secondary: Icon(
                _isPrivate ? LucideIcons.lock : LucideIcons.globe,
                size: 20,
                color: AppColors.primary,
              ),
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
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
          const SizedBox(height: 12),
          Text(
            'Or pick a sample image:',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final path in kSampleCampaignImages)
                GestureDetector(
                  onTap: () => _pickSample(path),
                  child: Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _sampleSelected(path)
                            ? AppColors.gold
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Image.asset(path, fit: BoxFit.cover),
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
                    : Image.file(
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
                  'On payout, Lipila charges 1.5% and Kingdom Sponsor charges K0.24 + 1% (min K3). '
                  'Example: a K100 payout delivers K95.26 to your phone.',
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
