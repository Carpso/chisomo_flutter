import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

/// QR scan for admins (confirm a user's profile) and hosts (check attendees in
/// to their events). Hosts pick an event, then scan an attendee's code.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  AdminUser? _user;
  Map<String, dynamic>? _checkIn;
  String? _lookupError;
  int? _selectedEventId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _processing = true;
    try {
      final parts = raw.split('|');
      if (parts.length < 2 || parts[0] != 'KSQR') {
        setState(() { _lookupError = 'Not a Kingdom Sponsor QR code.'; _checkIn = null; });
        return;
      }
      final phone = parts[1];
      if (_selectedEventId != null) {
        // Event check-in mode.
        final res = await ref.read(apiClientProvider).checkInAttendee(_selectedEventId!, phone);
        setState(() {
          _checkIn = res;
          _lookupError = res['ok'] == true ? null : (res['error'] as String?);
          _user = null;
        });
      } else {
        final res = await ref.read(apiClientProvider).getAdminUsers(q: phone, limit: 1);
        final users = (res['users'] as List<dynamic>? ?? [])
            .map((u) => AdminUser.fromJson(u as Map<String, dynamic>))
            .toList();
        setState(() {
          _user = users.isEmpty ? null : users.first;
          _checkIn = null;
          _lookupError = users.isEmpty ? 'No user found for $phone.' : null;
        });
      }
    } catch (_) {
      setState(() => _lookupError = 'Could not process the code.');
    } finally {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(hostProvider).value;
    final myEvents = host == null
        ? const <Campaign>[]
        : host.campaigns.where((c) => c.isEvent || c.campaignType == 'event').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: _user != null
          ? _ProfileCard(user: _user!, onDone: () => setState(() => _user = null))
          : _checkIn != null
              ? _CheckInCard(result: _checkIn!, onDone: () => setState(() => _checkIn = null))
              : Column(
                  children: [
                    if (myEvents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedEventId,
                          hint: const Text('Check in for an event… (optional)'),
                          items: [
                            for (final e in myEvents)
                              DropdownMenuItem(value: e.id, child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _selectedEventId = v),
                          decoration: const InputDecoration(
                            labelText: 'Event check-in',
                            prefixIcon: Icon(LucideIcons.ticket, size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          MobileScanner(controller: _controller, onDetect: _handleScan),
                          const Center(child: Icon(LucideIcons.scanLine, size: 120, color: Colors.white38)),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (_lookupError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(_lookupError!,
                                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                              ),
                            Text(
                              _selectedEventId != null
                                  ? 'Scan an attendee\'s Kingdom Sponsor QR code to check them in.'
                                  : 'Point the camera at a user\'s Kingdom Sponsor QR code.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textMuted),
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

class _CheckInCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onDone;

  const _CheckInCard({required this.result, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = result['attendee'] as Map<String, dynamic>? ?? {};
    final name = (a['name'] as String? ?? '').isNotEmpty ? a['name'] as String : (a['username'] as String? ?? 'Guest');
    final first = result['first'] == true;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(first ? LucideIcons.checkCircle : LucideIcons.userCheck,
                    size: 56, color: first ? AppColors.primary : AppColors.gold),
                const SizedBox(height: 12),
                Text(name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(first ? 'Checked in for the first time!' : 'Already checked in',
                    style: TextStyle(color: first ? AppColors.primary : AppColors.gold, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text('Total checked in: ${result['total'] ?? 0}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                if (a['checkedInAt'] != null)
                  Text('at ${a['checkedInAt']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onDone,
          icon: const Icon(LucideIcons.scanLine, size: 16),
          label: const Text('Scan next attendee'),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onDone;

  const _ProfileCard({required this.user, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = user;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.shieldCheck, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('User confirmed — profile verified', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      (u.displayName.isNotEmpty ? u.displayName[0] : '?').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: Text(u.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(height: 16),
                _row('Phone', u.phone),
                _row('Username', u.username),
                if (u.name != null) _row('Name', u.name!),
                _row('Joined', safeDate(u.createdAt)),
                if (u.lastLoginAt != null) _row('Last login', safeDate(u.lastLoginAt!)),
                _row('Total given', formatKwacha(u.givenCents)),
                if (u.kycDocUrl != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(u.kycDocUrl!)),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.eye, size: 14, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text('View KYC document',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onDone,
          icon: const Icon(LucideIcons.scanLine, size: 16),
          label: const Text('Scan another code'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
