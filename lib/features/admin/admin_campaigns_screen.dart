import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_brand_icon.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../campaigns/campaign_image.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';
import '../host/create_campaign_screen.dart';

class AdminCampaignsScreen extends ConsumerStatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  ConsumerState<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends ConsumerState<AdminCampaignsScreen> {
  List<Campaign>? _campaigns;
  String? _error;

  static String _centsToKwacha(int cents) {
    final t = (cents / 100).toStringAsFixed(2);
    return t.endsWith('.00') ? t.substring(0, t.length - 3) : t;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await ref.read(apiClientProvider).getAdminCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = rows
            .map((r) => Campaign.fromJson((r as Map).cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load campaigns.');
    }
  }

  Future<void> _confirmDelete(Campaign campaign) async {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: AlertDialog(
          title: const Text('Delete campaign?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${campaign.title}" will be removed from the platform immediately. The host and everyone who donated to it will be alerted (push + SMS).',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'Why is this campaign being removed? Shown to the host and donors.',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(LucideIcons.messageSquare, size: 18),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (ok != true) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteCampaign(campaign.id, reason: reasonController.text.trim());
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('"${campaign.title}" deleted. Host and donors were alerted.')),
      );
      await _load();
      ref.invalidate(adminDataProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
    }
  }

  Future<void> _editCampaign(Campaign campaign) async {
    final titleController = TextEditingController(text: campaign.title);
    final descriptionController = TextEditingController(text: campaign.description);
    final goalController = TextEditingController(
      text: campaign.hasGoal ? _centsToKwacha(campaign.goalCents) : '',
    );
    final minWithdrawController = TextEditingController(
      text: campaign.minWithdrawCents != null ? _centsToKwacha(campaign.minWithdrawCents!) : '',
    );
    final minSponsorsController = TextEditingController(text: '1');
    final endsAtController = TextEditingController(
      text: campaign.endsAt != null ? safeDate(campaign.endsAt) : '',
    );
    String status = campaign.status;
    String category =
        kCampaignCategories.contains(campaign.category) ? campaign.category : 'Other';
    String visibility = campaign.visibility == 'private' ? 'private' : 'public';
    String campaignType =
        kCampaignTypes.containsKey(campaign.campaignType) ? campaign.campaignType : 'community';
    String? errorText;
    Uint8List? pickedBytes;
    String? pickedName;
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit campaign'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: pickedBytes == null
                              ? CampaignImage(campaign: campaign, fit: BoxFit.cover)
                              : Image.memory(pickedBytes!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Campaign image',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              pickedBytes == null
                                  ? (campaign.logoUrl ?? campaign.imageUrl) != null
                                      ? 'Current image shown. Replace it to update.'
                                      : 'No image yet. Add one to make the campaign stand out.'
                                  : 'New image selected. Save to upload.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Replace image',
                        onPressed: () async {
                          final xfile = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (xfile != null) {
                            final bytes = await xfile.readAsBytes();
                            setDialogState(() {
                              pickedBytes = bytes;
                              pickedName = xfile.name;
                            });
                          }
                        },
                        icon: const Icon(LucideIcons.imagePlus,
                            size: 22, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Or pick a sample image:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final path in kSampleCampaignImages)
                        GestureDetector(
                          onTap: () async {
                            final data = await rootBundle.load(path);
                            setDialogState(() {
                              pickedBytes = data.buffer.asUint8List();
                              pickedName = path.split('/').last;
                            });
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: pickedName == path.split('/').last
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(LucideIcons.pencil, size: 18),
                    ),
                    maxLength: 200,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(LucideIcons.fileText, size: 18),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalController,
                    decoration: const InputDecoration(
                      labelText: 'Goal (ZMW)',
                      prefixIcon: Icon(LucideIcons.target, size: 18),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minWithdrawController,
                    decoration: const InputDecoration(
                      labelText: 'Min withdraw (ZMW)',
                      prefixIcon: Icon(LucideIcons.download, size: 18),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endsAtController,
                    decoration: const InputDecoration(
                      labelText: 'End date (YYYY-MM-DD)',
                      prefixIcon: Icon(LucideIcons.calendar, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: ['active', 'draft', 'ended']
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => status = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(LucideIcons.flag, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    items: kCampaignCategories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => category = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(LucideIcons.tags, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: visibility,
                    items: const [
                      DropdownMenuItem(value: 'public', child: Text('Public')),
                      DropdownMenuItem(value: 'private', child: Text('Private')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => visibility = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Visibility',
                      prefixIcon: Icon(LucideIcons.eye, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: campaignType,
                    items: [
                      for (final e in kCampaignTypes.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => campaignType = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Campaign type',
                      prefixIcon: Icon(LucideIcons.layoutGrid, size: 18),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    setDialogState(() => errorText = 'Title is required.');
                    return;
                  }
                  final goalStr = goalController.text.trim();
                  if (goalStr.isNotEmpty && (double.tryParse(goalStr) == null || double.parse(goalStr) <= 0)) {
                    setDialogState(() => errorText = 'Goal must be a positive number.');
                    return;
                  }
                  final minWStr = minWithdrawController.text.trim();
                  if (minWStr.isNotEmpty && (double.tryParse(minWStr) == null || double.parse(minWStr) <= 0)) {
                    setDialogState(() => errorText = 'Minimum withdraw must be a positive number.');
                    return;
                  }
                  final endsAtStr = endsAtController.text.trim();
                  if (endsAtStr.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(endsAtStr)) {
                    setDialogState(() => errorText = 'End date must be YYYY-MM-DD.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(LucideIcons.save, size: 16),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
    );

    titleController.dispose();
    descriptionController.dispose();
    goalController.dispose();
    minWithdrawController.dispose();
    minSponsorsController.dispose();
    endsAtController.dispose();

    if (ok != true) return;

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final goalStr = goalController.text.trim();
    final minWithdrawStr = minWithdrawController.text.trim();
    final endsAtStr = endsAtController.text.trim();

    final body = <String, dynamic>{};
    if (title.isNotEmpty) body['title'] = title;
    if (description.isNotEmpty) body['description'] = description;
    if (goalStr.isNotEmpty) {
      final goal = double.tryParse(goalStr);
      if (goal != null && goal > 0) body['goalCents'] = (goal * 100).round();
    }
    if (minWithdrawStr.isNotEmpty) {
      final minW = double.tryParse(minWithdrawStr);
      if (minW != null && minW > 0) body['minWithdrawCents'] = (minW * 100).round();
    }
    if (endsAtStr.isNotEmpty) {
      body['endsAt'] = endsAtStr;
    } else {
      body['endsAt'] = null;
    }
    body['status'] = status;
    body['category'] = category;
    body['visibility'] = visibility;
    body['campaignType'] = campaignType;

    try {
      await ref.read(apiClientProvider).adminUpdateCampaign(campaign.id, body);
      if (pickedBytes != null && pickedName != null) {
        try {
          await ref
              .read(apiClientProvider)
              .uploadLogo(campaign.id, pickedBytes!, pickedName!);
        } on ApiException catch (e) {
          if (mounted) {
            messenger.showSnackBar(SnackBar(
                content:
                    Text('Campaign saved, but image upload failed: ${e.message}')));
          }
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('"${campaign.title}" updated.')),
      );
      await _load();
      ref.invalidate(adminDataProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update. Try again.')),
        );
      }
    }
  }

  Future<void> _promoteCampaign(Campaign campaign) async {
    var days = 7;
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Promote campaign'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Put "${campaign.title}" in the top-5 promoted list. '
                'This is free — no payment is collected from the host.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: days,
                items: [7, 14, 30]
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('$d days'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => days = v);
                },
                decoration: const InputDecoration(labelText: 'Promote for'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(LucideIcons.rocket, size: 16),
              label: const Text('Promote'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final res = await ref
          .read(apiClientProvider)
          .adminPromoteCampaign(campaign.id, days: days);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text(res['message'] as String? ?? '"${campaign.title}" promoted.')));
      await _load();
      ref.invalidate(adminDataProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not promote. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = _campaigns;
    return Scaffold(
      appBar: AppBar(title: const Text('Campaigns')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: campaigns == null
            ? ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: AppIconSpinner(size: 32)),
                    ),
                ],
              )
            : campaigns.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            AppBrandIcon(size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No campaigns yet.',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Campaigns created by hosts will appear here.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: campaigns.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = campaigns[i];
                  final deleted = c.status == 'deleted';
                  return Card(
                    child: ListTile(
                      leading: deleted
                          ? CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.textMuted.withValues(alpha: 0.12),
                              child: Icon(
                                LucideIcons.archive,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: CampaignImage(campaign: c, fit: BoxFit.cover),
                              ),
                            ),
                      title: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        deleted
                            ? 'Deleted'
                            : '${formatKwacha(c.raisedCents)} raised \u00b7 ${formatKwacha(c.availableCents ?? 0)} available',
                      ),
                      isThreeLine: false,
                      trailing: deleted
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (c.promoted)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(LucideIcons.trendingUp,
                                        size: 18, color: AppColors.primary),
                                  )
                                else
                                  IconButton(
                                    tooltip: 'Promote campaign',
                                    icon: const Icon(LucideIcons.rocket,
                                        color: AppColors.primary),
                                    onPressed: () => _promoteCampaign(c),
                                  ),
                                IconButton(
                                  tooltip: 'Edit campaign',
                                  icon: const Icon(LucideIcons.pencil, color: AppColors.primary),
                                  onPressed: () => _editCampaign(c),
                                ),
                                IconButton(
                                  tooltip: 'Delete campaign',
                                  icon: const Icon(LucideIcons.trash2, color: AppColors.danger),
                                  onPressed: () => _confirmDelete(c),
                                ),
                              ],
                            ),
                      onTap: deleted ? null : () => context.push('/campaign/${c.id}'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
