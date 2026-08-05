import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen> {
  bool _busy = true;
  String? _error;
  String _code = '';
  String _shareUrl = '';
  int _total = 0;
  int _last30d = 0;
  List<dynamic> _referrals = [];

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final me = await api.getMyReferral();
      final res = await api.getMyReferrals();
      if (!mounted) return;
      setState(() {
        _code = me['code'] as String? ?? '';
        _shareUrl = me['shareUrl'] as String? ?? '';
        _total = res['total'] as int? ?? 0;
        _last30d = res['last30d'] as int? ?? 0;
        _referrals = res['referrals'] as List<dynamic>? ?? [];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your referral code. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied to clipboard')),
    );
  }

  Future<void> _share() async {
    final text = 'Give on Kingdom Sponsor with my referral code: $_code — $sharePage';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  String get sharePage => _shareUrl.isEmpty
      ? 'https://kingdom-sponsor-api.godfreymoseskalambo.workers.dev/share'
      : _shareUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: _busy
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
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
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'YOUR REFERRAL CODE',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textMuted, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _code,
                              style: theme.textTheme.headlineMedium
                                  ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 4),
                            ),
                            const SizedBox(height: 16),
                            if (_shareUrl.isNotEmpty)
                              QrImageView(
                                data: sharePage,
                                version: QrVersions.auto,
                                size: 160,
                                backgroundColor: Colors.white,
                                embeddedImage: const AssetImage(
                                    'assets/kingdom_sponsor_app_icon.jpg'),
                                embeddedImageStyle: QrEmbeddedImageStyle(
                                  size: const Size.square(40),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipOval(
                                  child: Image.asset(
                                    'assets/kingdom_sponsor_app_icon.jpg',
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Kingdom Sponsor',
                                  style: theme.textTheme.labelMedium
                                      ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share your code so friends get you on Kingdom Sponsor — '
                              'they enter it when they sign up.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _copy,
                                    icon: const Icon(LucideIcons.copy, size: 16),
                                    label: const Text('Copy code'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _share,
                                    icon: const Icon(LucideIcons.messageCircle, size: 16),
                                    label: const Text('Share'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(LucideIcons.users, color: AppColors.primary),
                        title: Text('$_total people joined with your code'),
                        subtitle: Text('$_last30d in the last 30 days'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'People you referred',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_referrals.isEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(LucideIcons.userPlus, color: AppColors.textMuted),
                          title: const Text('No referrals yet'),
                          subtitle: const Text('Share your code to get started'),
                        ),
                      )
                    else
                      Card(
                        child: Column(
                          children: [
                            for (final r in _referrals)
                              ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  child: Text(
                                    ((r['username'] as String? ?? '?').isNotEmpty
                                            ? r['username'] as String
                                            : '?')
                                        .substring(0, 1),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                title: Text(r['username'] ?? 'Giver'),
                                subtitle: Text(r['date'] ?? ''),
                                trailing: const Icon(LucideIcons.checkCircle2,
                                    color: AppColors.primary, size: 18),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
