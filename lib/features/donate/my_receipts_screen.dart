import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

class MyReceiptsScreen extends ConsumerStatefulWidget {
  const MyReceiptsScreen({super.key});

  @override
  ConsumerState<MyReceiptsScreen> createState() => _MyReceiptsScreenState();
}

class _MyReceiptsScreenState extends ConsumerState<MyReceiptsScreen> {
  List<dynamic> _receipts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final receipts = await ref.read(apiClientProvider).getMyReceipts();
      if (mounted) setState(() => _receipts = receipts);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your receipts.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(Map<String, dynamic> receipt) async {
    final api = ref.read(apiClientProvider);
    final url = api.receiptUrl(receipt['id'] as int);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the receipt. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My receipts')),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _fetch,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(LucideIcons.fileText,
                              color: AppColors.primary),
                          title: const Text('Download your official receipt'),
                          subtitle: const Text(
                              'Every confirmed gift gets a PDF receipt you can keep or share — '
                              'it shows the total processing fees (ZMW 0.2400 + Lipila + platform cut) '
                              'and the amount your campaign received.'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_receipts.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(LucideIcons.receipt,
                                    size: 32, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'No confirmed gifts yet. When you donate, your receipt will appear here.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (final r in _receipts)
                                ListTile(
                                  leading: const Icon(LucideIcons.receipt,
                                      color: AppColors.primary),
                                  title: Text(
                                    r['campaignTitle'] ?? 'Campaign',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    '${safeDate(r['date'])} • ${r['reference'] ?? ''}',
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Download PDF',
                                    icon: const Icon(LucideIcons.download,
                                        color: AppColors.primary),
                                    onPressed: () => _download(r),
                                  ),
                                ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Divider(height: 1),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_receipts.isNotEmpty)
                        Text(
                          'Tap the download icon to open the PDF for any gift.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
    );
  }
}
