import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// Admin: non-transactional SMS alerts — all OFF by default. Superadmin /
/// assistants turn on the master switch, then pick which alert categories also
/// send an SMS (in addition to the push + in-app notification). SMS is
/// otherwise reserved for OTP + transaction confirmations to keep costs low.
class SmsAlertsConfigCard extends ConsumerStatefulWidget {
  const SmsAlertsConfigCard({super.key});

  @override
  ConsumerState<SmsAlertsConfigCard> createState() => _SmsAlertsConfigCardState();
}

class _SmsAlertsConfigCardState extends ConsumerState<SmsAlertsConfigCard> {
  bool _loading = true;
  bool _master = false;
  final Map<String, bool> _toggles = {};
  bool _saving = false;

  static const _categories = <String, (String, String)>{
    'sms_alert_milestone': ('Milestone reached', 'Host gets an SMS when their campaign hits a milestone %'),
    'sms_alert_promotion': ('Promotion live', 'Host gets an SMS when their promotion goes live'),
    'sms_alert_sponsor_desk': ('Sponsor Desk opportunities', 'Hosts get an SMS when new funding opportunities are published'),
    'sms_alert_event_reminder': ('Event reminders', 'Host gets an SMS for the 48h / 2h event countdown'),
    'sms_alert_announcement': ('Announcements published', 'Host gets an SMS when an update is published'),
    'sms_alert_campaign_ending': ('Campaign ending', 'Host gets an SMS when their campaign ends soon'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).getSmsAlerts();
      final cfg = res['config'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _master = cfg['master'] == true;
          _toggles.clear();
          for (final key in _categories.keys) {
            _toggles[key] = cfg[key] == true;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).setSmsAlerts({
        'master': _master,
        ..._toggles,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS alerts settings saved')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.messageSquare, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SMS alerts',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text('Non-transactional SMS — all off by default',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                if (_master)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('ON',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _master,
                onChanged: (v) => setState(() => _master = v),
                title: const Text('Master switch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Turn this on first, then pick categories below',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
              ),
              const Divider(height: 4),
              for (final entry in _categories.entries) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _toggles[entry.key] ?? false,
                  onChanged: _master
                      ? (v) => setState(() => _toggles[entry.key] = v)
                      : null,
                  title: Text(entry.value.$1, style: const TextStyle(fontSize: 13.5)),
                  subtitle: Text(entry.value.$2, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.save, size: 15),
                  label: Text(_saving ? 'Saving…' : 'Save SMS alerts'),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Each alert still sends a push + in-app notification; SMS is an extra '
                'delivery so hosts are reached even without the app open. Costs a few ngwee per message.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
