import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// Admin: configurable milestone thresholds — the percentage points at which
/// donors + host get a "campaign reached X%" celebration push. Default 25/50/75/100.
class MilestoneConfigCard extends ConsumerStatefulWidget {
  const MilestoneConfigCard({super.key});

  @override
  ConsumerState<MilestoneConfigCard> createState() => _MilestoneConfigCardState();
}

class _MilestoneConfigCardState extends ConsumerState<MilestoneConfigCard> {
  bool _loading = true;
  final List<int> _thresholds = [];
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).getMilestoneConfig();
      final list = (res['thresholds'] as List<dynamic>? ?? [25, 50, 75, 100])
          .map((e) => (e as num).toInt())
          .toList();
      if (mounted) {
        setState(() {
          _thresholds
            ..clear()
            ..addAll(list);
          _controller.text = list.join(', ');
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final parsed = _controller.text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((n) => n > 0 && n <= 100)
        .toSet()
        .toList()
      ..sort();
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one threshold (1–100).')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).setMilestoneConfig(parsed);
      if (mounted) {
        setState(() {
          _thresholds
            ..clear()
            ..addAll(parsed);
          _controller.text = parsed.join(', ');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone thresholds saved')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.trophy, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Milestone celebrations',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text('% of goal at which donors + host get a push',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else ...[
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Thresholds % (comma-separated)',
                  hintText: '25, 50, 75, 100',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _thresholds)
                    Chip(
                      label: Text('$t%'),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.save, size: 15),
                  label: Text(_saving ? 'Saving…' : 'Save thresholds'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
