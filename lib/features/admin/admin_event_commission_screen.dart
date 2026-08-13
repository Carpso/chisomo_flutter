import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin: configure event finder's commission (default K10, MoMo + card) and
/// the platform fees that apply to collections — all editable from the
/// dashboard without redeploying.
class AdminEventCommissionScreen extends ConsumerStatefulWidget {
  const AdminEventCommissionScreen({super.key});

  @override
  ConsumerState<AdminEventCommissionScreen> createState() => _AdminEventCommissionScreenState();
}

class _AdminEventCommissionScreenState extends ConsumerState<AdminEventCommissionScreen> {
  bool _loading = true;
  bool _enabled = false;
  String? _error;
  bool _saving = false;

  late final TextEditingController _finder = TextEditingController();
  late final TextEditingController _cardFinder = TextEditingController();
  late final TextEditingController _momoPct = TextEditingController();
  late final TextEditingController _momoMin = TextEditingController();
  late final TextEditingController _fixed = TextEditingController();
  late final TextEditingController _cardPct = TextEditingController();
  late final TextEditingController _cardMin = TextEditingController();
  late final TextEditingController _cardLipila = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _finder.dispose();
    _cardFinder.dispose();
    _momoPct.dispose();
    _momoMin.dispose();
    _fixed.dispose();
    _cardPct.dispose();
    _cardMin.dispose();
    _cardLipila.dispose();
    super.dispose();
  }

  String _fmt(int cents) => (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).get('/api/admin/event-commission', auth: true);
      if (!mounted) return;
      setState(() {
        _enabled = res['enabled'] == true;
        _finder.text = _fmt((res['finderFeeCents'] as num?)?.toInt() ?? 1000);
        _cardFinder.text = _fmt((res['cardFinderFeeCents'] as num?)?.toInt() ?? 1000);
        _momoPct.text = ((res['platformPct'] as num?)?.toDouble() ?? 1).toStringAsFixed(1);
        _momoMin.text = _fmt((res['platformMinFeeCents'] as num?)?.toInt() ?? 300);
        _fixed.text = _fmt((res['platformFixedFeeCents'] as num?)?.toInt() ?? 48);
        _cardPct.text = ((res['cardPlatformPct'] as num?)?.toDouble() ?? 2).toStringAsFixed(1);
        _cardMin.text = _fmt((res['cardPlatformMinFeeCents'] as num?)?.toInt() ?? 500);
        _cardLipila.text = ((res['cardLipilaCollectionPct'] as num?)?.toDouble() ?? 2.5).toStringAsFixed(1);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load fee settings.'; _loading = false; });
    }
  }

  double _d(TextEditingController c, double dflt) => double.tryParse(c.text.trim()) ?? dflt;
  int _c(TextEditingController c, int dflt) => ((double.tryParse(c.text.trim()) ?? dflt) * 100).round();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put('/api/admin/event-commission', {
        'enabled': _enabled,
        'finderFeeCents': _c(_finder, 1000),
        'cardFinderFeeCents': _c(_cardFinder, 1000),
        'platformPct': _d(_momoPct, 1),
        'platformMinFeeCents': _c(_momoMin, 300),
        'platformFixedFeeCents': _c(_fixed, 48),
        'cardPlatformPct': _d(_cardPct, 2),
        'cardPlatformMinFeeCents': _c(_cardMin, 500),
        'cardLipilaCollectionPct': _d(_cardLipila, 2.5),
      }, auth: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee settings saved')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, {bool pct = false}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: pct ? null : 'K ', isDense: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees & commissions')),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(LucideIcons.ticket, color: AppColors.primary, size: 28),
                            const SizedBox(height: 10),
                            Text('Event finder\'s commission',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            const Text(
                              'For EVENT ticket campaigns only: when an event host withdraws, a flat '
                              'commission is deducted from their payout on top of Kingdom Sponsor\'s '
                              'normal platform cut (K3/1% + K0.48) and Lipila\'s 1.5% disbursement fee.\n\n'
                              'Default is K10. You can turn it off here, or waive it per event from the '
                              'admin campaigns screen.',
                              style: TextStyle(color: AppColors.textMuted, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Charge event commission', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Off = event payouts only carry the normal platform cut + Lipila'),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    if (_enabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _field(_finder, 'MoMo finder\'s fee (K)')),
                          const SizedBox(width: 10),
                          Expanded(child: _field(_cardFinder, 'Card finder\'s fee (K)')),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('Platform collection fees',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('These apply to every donation / ticket sale (MoMo and card).',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _field(_momoPct, 'MoMo %', pct: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _field(_momoMin, 'MoMo min (K)')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _field(_fixed, 'Fixed fee (K)')),
                        const SizedBox(width: 10),
                        Expanded(child: _field(_cardLipila, 'Lipila card %', pct: true)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _field(_cardPct, 'Card %', pct: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _field(_cardMin, 'Card min (K)')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.check, size: 18),
                      label: const Text('Save settings'),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.info, size: 18, color: AppColors.gold),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Example (K500 MoMo event, K10 commission): donor pays K515.98; '
                                'host payout deducts K7.50 (Lipila) + K5.48 (normal cut) + K10 (finder\'s) = K477.02.',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
