import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin Tax & Compliance: income, estimated turnover tax (due the 14th each
/// month by default), smart invoice download, and a compliance checklist.
class TaxComplianceScreen extends ConsumerStatefulWidget {
  const TaxComplianceScreen({super.key});

  @override
  ConsumerState<TaxComplianceScreen> createState() => _TaxComplianceScreenState();
}

class _TaxComplianceScreenState extends ConsumerState<TaxComplianceScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _ratePct = 4;
  int _dueDay = 14;
  String _tin = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).getTaxDashboard();
      final settings = res['settings'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _data = res;
          _ratePct = (settings['ratePct'] as num?)?.toInt() ?? 4;
          _dueDay = (settings['dueDay'] as num?)?.toInt() ?? 14;
          _tin = settings['tin'] as String? ?? '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load tax dashboard.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).saveTaxSettings(ratePct: _ratePct.toDouble(), dueDay: _dueDay, tin: _tin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tax settings saved')));
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _downloadInvoice(String month) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(apiClientProvider);
    final token = api.token;
    if (token == null) return;
    final snack = messenger.showSnackBar(const SnackBar(content: Text('Downloading invoice…')));
    try {
      final res = await http.get(
        Uri.parse(api.taxInvoiceUrl(month)),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) throw Exception('Download failed (${res.statusCode})');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/kingdom-sponsor-invoice-$month.pdf');
      await file.writeAsBytes(res.bodyBytes);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved invoice-$month.pdf'),
          action: SnackBarAction(label: 'View', onPressed: () => OpenFile.open(file.path)),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Invoice download failed: $e')));
    } finally {
      snack.close();
    }
  }

  Future<void> _sendReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final snack = messenger.showSnackBar(const SnackBar(content: Text('Sending weekly report…')));
    try {
      final res = await ref.read(apiClientProvider).sendWeeklyReport();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(res['message'] as String? ?? 'Weekly report emailed')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Could not send: $e')));
    } finally {
      snack.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax & Compliance'),
        actions: [IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _load)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: AppIconSpinner())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
                    ],
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
                              const Row(
                                children: [
                                  Icon(LucideIcons.receipt, color: AppColors.gold),
                                  SizedBox(width: 8),
                                  Text('Estimated turnover tax', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Total taxable income',
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                              Text(formatKwacha(_data?['totalIncomeCents'] as int? ?? 0),
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text('Next payment due: ${_data?['nextDue']} (in ${_data?['daysUntilDue'] ?? '?'} days)',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                              const SizedBox(height: 8),
                              const Text(
                                'Zambian turnover tax is typically paid monthly on the 14th. '
                                'Confirm your exact rate and obligations with ZRA.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _sendReport,
                                icon: const Icon(LucideIcons.mail, size: 16),
                                label: const Text('Email weekly report now'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Tax rate (%)', isDense: true),
                                      initialValue: '$_ratePct',
                                      onChanged: (v) => _ratePct = int.tryParse(v) ?? 4,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Due day of month', isDense: true),
                                      initialValue: '$_dueDay',
                                      onChanged: (v) => _dueDay = int.tryParse(v) ?? 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                decoration: const InputDecoration(labelText: 'TPIN / TIN number', isDense: true),
                                initialValue: _tin,
                                onChanged: (v) => _tin = v,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _saveSettings,
                                  icon: _saving
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(LucideIcons.save, size: 16),
                                  label: Text(_saving ? 'Saving…' : 'Save settings'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monthly invoices', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(height: 8),
                              for (final m in (_data?['monthly'] as List<dynamic>? ?? []).reversed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text('${m['month']} • income ${formatKwacha(m['incomeCents'])}'),
                                      ),
                                      Text('Tax: ${formatKwacha(m['taxCents'])}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                      IconButton(
                                        tooltip: 'Download invoice',
                                        icon: const Icon(LucideIcons.download, size: 18),
                                        onPressed: () => _downloadInvoice(m['month'] as String),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Compliance checklist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(height: 8),
                              for (final c in (_data?['compliance'] as List<dynamic>? ?? []))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(c['done'] == true ? LucideIcons.checkCircle : LucideIcons.circle,
                                          size: 16,
                                          color: c['done'] == true ? AppColors.primary : AppColors.textMuted),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c['label'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                            Text(c['detail'] ?? '',
                                                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
