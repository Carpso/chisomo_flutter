import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../auth/auth_controller.dart';

/// A purchased event ticket the user can show as a scannable QR at the door.
/// The host's QR scanner reads `KSQR|<phone>|<contributionId>` and verifies the
/// ticket belongs to this event before checking in.
class MyTicketsScreen extends ConsumerStatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends ConsumerState<MyTicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _error;
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await ref.read(apiClientProvider).getMyTickets();
      if (mounted) {
        setState(() {
          _tickets = rows.whereType<Map>().map((t) => Map<String, dynamic>.from(t)).toList();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your tickets.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My tickets'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(LucideIcons.refreshCw), onPressed: _load),
        ],
      ),
      body: _loading
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
              : _tickets.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(40),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.ticket, size: 34, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text('No tickets yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(height: 8),
                        const Text(
                          'When you buy event tickets they appear here as a scannable '
                          'QR code the host can check you in with at the door.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, height: 1.4),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                        itemCount: _tickets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final t = _tickets[i];
                          final id = (t['id'] as num?)?.toInt() ?? 0;
                          final campaignId = (t['campaignId'] as num?)?.toInt() ?? 0;
                          final expanded = _expanded == id;
                          return Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => setState(() => _expanded = expanded ? null : id),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [AppColors.primary, AppColors.primaryLight],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(LucideIcons.ticket, color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            t['campaignTitle'] ?? 'Event ticket',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                          ),
                                        ),
                                        Text(
                                          '${t['ticketQty'] ?? 1} ×',
                                          style: const TextStyle(
                                              color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${t['tierName'] ?? 'Ticket'} • ${formatKwacha((t['amountCents'] as num?)?.toInt() ?? 0)}',
                                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bought ${safeDate(t['date'])}'
                                          '${t['eventDate'] != null ? ' • ${t['eventDate']}${t['eventTime'] != null && (t['eventTime'] as String).isNotEmpty ? ' at ${t['eventTime']}' : ''}' : ''}',
                                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: QrImageView(
                                            data: 'KSQR|${ref.read(authControllerProvider).value?.phone ?? ''}|$id',
                                            version: QrVersions.auto,
                                            size: 180,
                                            backgroundColor: Colors.white,
                                            padding: const EdgeInsets.all(10),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Show this code at the door to check in.',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11.5),
                                        ),
                                        if (campaignId > 0) ...[
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: () => context.push('/event/$campaignId'),
                                            icon: const Icon(LucideIcons.eye, size: 15),
                                            label: const Text('View event'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
