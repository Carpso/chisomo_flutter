import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_brand_icon.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';

class AirtimeConfig {
  final bool enabled;
  final int markupPct;
  final int minAmountCents;
  final int maxAmountCents;
  final int bonusPct;
  final int creditsCents;

  const AirtimeConfig({
    required this.enabled,
    required this.markupPct,
    required this.minAmountCents,
    required this.maxAmountCents,
    required this.bonusPct,
    required this.creditsCents,
  });

  factory AirtimeConfig.fromJson(Map<String, dynamic> j) => AirtimeConfig(
        enabled: j['enabled'] == true,
        markupPct: j['markupPct'] as int? ?? 5,
        minAmountCents: j['minAmountCents'] as int? ?? 500,
        maxAmountCents: j['maxAmountCents'] as int? ?? 50000,
        bonusPct: j['bonusPct'] as int? ?? 5,
        creditsCents: j['creditsCents'] as int? ?? 0,
      );
}

/// Shared live value of the admin Airtime toggle. Watched by the home carousel
/// (to hide/show the Buy Airtime slide) and by [AirtimeScreen] (to block the
/// buy form). The admin config invalidates it whenever it saves, so the toggle
/// takes effect immediately everywhere.
final airtimeEnabledProvider = FutureProvider<bool>((ref) async {
  try {
    final res = await ref.read(apiClientProvider).get('/api/airtime/config');
    return res['enabled'] == true;
  } catch (_) {
    return false;
  }
});

/// Buy airtime for friends and family.
class AirtimeScreen extends ConsumerStatefulWidget {
  const AirtimeScreen({super.key});

  @override
  ConsumerState<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends ConsumerState<AirtimeScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  String _network = 'airtel';
  bool _loading = false;
  bool _useCredits = false;
  String? _error;
  String? _success;
  AirtimeConfig? _config;
  bool _configFailed = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _configFailed = false);
    try {
      final res = await ref.read(apiClientProvider).get('/api/airtime/config');
      if (mounted) setState(() => _config = AirtimeConfig.fromJson(res));
    } catch (_) {
      if (mounted) setState(() => _configFailed = true);
    }
  }

  Future<void> _order() async {
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final kwacha = double.tryParse(_amountController.text.trim()) ?? 0;
    final amountCents = (kwacha * 100).round();

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final validPhone =
        (digits.startsWith('260') && digits.length == 12) ||
        (digits.startsWith('0') && digits.length == 10);
    if (!validPhone) {
      setState(() => _error = 'Enter a valid Zambian phone number (e.g. +260 977 123 456).');
      return;
    }
    if (_config != null && (amountCents < _config!.minAmountCents || amountCents > _config!.maxAmountCents)) {
      setState(() => _error = 'Amount must be between ${formatKwacha(_config!.minAmountCents)} and ${formatKwacha(_config!.maxAmountCents)}');
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });
    try {
      // Adhere to the admin toggle even if the screen was opened before it
      // changed: the backend also blocks disabled orders, but fail fast here.
      if (_config?.enabled != true) {
        if (mounted) setState(() => _error = 'Airtime is not available right now.');
        return;
      }
      final useCreditsCents = _useCredits ? _config?.creditsCents ?? 0 : 0;
      final res = await ref.read(apiClientProvider).post('/api/airtime/order', {
        'phone': phone,
        'network': _network,
        'amountCents': amountCents,
        'useCreditsCents': useCreditsCents,
      }, auth: true);
      if (mounted) {
        setState(() {
          _success = res['message'] as String? ?? 'Airtime order placed!';
          _phoneController.clear();
          _amountController.clear();
        });
        _loadConfig();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not place order. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _config;

    return Scaffold(
      appBar: AppBar(title: const Text('Buy Airtime')),
      body: config == null
          ? _configFailed
              ? _buildLoadError(theme)
              : const Center(child: AppIconSpinner())
          : !config.enabled
              ? _buildComingSoon(theme)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.gold.withValues(alpha: 0.08)],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.smartphone, color: AppColors.primary, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Send airtime to anyone', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                    Text('Top up for family & friends on any network', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Network selector
                    Text('Select network', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final (network, label, color, asset) in [
                          ('airtel', 'Airtel', const Color(0xFFE30613), 'assets/airtel_icon.jpg'),
                          ('mtn', 'MTN', const Color(0xFFFFC107), 'assets/mtn_icon.webp'),
                          ('zamtel', 'Zamtel', const Color(0xFF006600), 'assets/zamtel_icon.jpg'),
                          ('zedmobile', 'Zed Mobile', const Color(0xFFB3131F), 'assets/zedmobile_icon.jpg'),
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(() => _network = network),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _network == network ? color.withValues(alpha: 0.15) : AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _network == network ? color : AppColors.textMuted.withValues(alpha: 0.2), width: 2),
                                  ),
                                  child: Column(
                                    children: [
                                      ClipOval(
                                        child: Image.asset(
                                          asset,
                                          width: 30,
                                          height: 30,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(LucideIcons.smartphone, size: 20, color: _network == network ? color : AppColors.textMuted),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _network == network ? color : AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Phone number
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+260 9XX XXX XXX',
                        prefixIcon: Icon(LucideIcons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Amount
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Amount (K)',
                        prefixIcon: const Icon(LucideIcons.coins),
                        helperText: 'K${config.minAmountCents ~/ 100} - K${config.maxAmountCents ~/ 100} (+${config.markupPct}% processing fee)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick amounts
                    Wrap(
                      spacing: 8,
                      children: [5, 10, 20, 50, 100].map((kwacha) => ActionChip(
                        label: Text('K$kwacha'),
                        onPressed: () => _amountController.text = '$kwacha',
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      )).toList(),
                    ),
                    // Bonus credits
                    if (config.creditsCents > 0) ...[
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.zero,
                        color: AppColors.gold.withValues(alpha: 0.08),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          value: _useCredits,
                          onChanged: (v) => setState(() => _useCredits = v),
                          title: Text(
                            'Use ${formatKwacha(config.creditsCents)} bonus credits',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: Text(
                            'Deducted from this order',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          secondary: const Icon(LucideIcons.gift, size: 20, color: AppColors.gold),
                        ),
                      ),
                    ],
                    if (config.bonusPct > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(LucideIcons.gift, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Earn ${config.bonusPct}% of the airtime amount back as credits on every order.',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.danger), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))],
                        ),
                      ),
                    ],
                    if (_success != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [const Icon(LucideIcons.checkCircle, size: 16, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(_success!, style: const TextStyle(color: AppColors.primary)))],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loading ? null : _order,
                      icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.zap),
                      label: Text(_loading ? 'Processing…' : 'Buy Airtime'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.info, size: 16, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Check your phone for the mobile money prompt and enter your PIN to pay. Airtime is delivered to the recipient as soon as the payment is confirmed. A small ${(config.markupPct)}% processing fee applies. Earnings support worthy causes.',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textDark, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildComingSoon(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.smartphone, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Airtime coming soon', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Text(
              'We\'re working on bringing you airtime purchases for all Zambian networks. Check back soon!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const AppBrandIcon(size: 18),
              label: const Text('Browse Fundraisers'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wifiOff, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Could not load airtime settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadConfig,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class AirtimeAdminConfig extends ConsumerStatefulWidget {
  const AirtimeAdminConfig({super.key});

  @override
  ConsumerState<AirtimeAdminConfig> createState() => _AirtimeAdminConfigState();
}

class _AirtimeAdminConfigState extends ConsumerState<AirtimeAdminConfig> {
  bool _enabled = false;
  int _markup = 5;
  int _minAmount = 500;
  int _maxAmount = 50000;
  int _bonus = 5;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/api/airtime/config');
      if (mounted) {
        setState(() {
          _enabled = res['enabled'] == true;
          _markup = res['markupPct'] as int? ?? 5;
          _minAmount = res['minAmountCents'] as int? ?? 500;
          _maxAmount = res['maxAmountCents'] as int? ?? 50000;
          _bonus = res['bonusPct'] as int? ?? 5;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put('/api/admin/airtime/config', {
        'enabled': _enabled,
        'markupPct': _markup,
        'minAmountCents': _minAmount,
        'maxAmountCents': _maxAmount,
        'bonusPct': _bonus,
      }, auth: true);
      // Reflect the toggle everywhere immediately (carousel slide, buy screen).
      ref.invalidate(airtimeEnabledProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Airtime settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Sends a real K1 top-up to a test number to verify the Africa's Talking
  /// airtime keys are working end-to-end.
  Future<void> _testAirtime() async {
    final phoneController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test airtime keys'),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sends a real K1 airtime top-up to verify the Africa\'s Talking '
                'purchase keys work. This costs K1 on your AT account.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Recipient phone',
                  hintText: '+260 977 123 456',
                  prefixIcon: Icon(LucideIcons.phone, size: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send K1 test'),
          ),
        ],
      ),
    );
    final phone = phoneController.text.trim();
    phoneController.dispose();
    if (confirmed != true || phone.isEmpty) return;
    setState(() => _testing = true);
    try {
      final res = await ref.read(apiClientProvider).post(
        '/api/admin/airtime/test',
        {'phone': phone},
        auth: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'K1 airtime sent')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Airtime test failed. Check the AT credentials.')),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
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
                const Icon(LucideIcons.smartphone, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Airtime System', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
              ],
            ),
            const SizedBox(height: 8),
            Text(_enabled ? 'Enabled — users can buy airtime' : 'Disabled — shows "Coming Soon"', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Text('Markup: $_markup%', style: theme.textTheme.bodySmall),
            Slider(value: _markup.toDouble(), min: 0, max: 20, divisions: 20, label: '$_markup%', onChanged: (v) => setState(() => _markup = v.round())),
            const SizedBox(height: 8),
            Text('Bonus reward: $_bonus% of each order back as credits', style: theme.textTheme.bodySmall),
            Slider(value: _bonus.toDouble(), min: 0, max: 50, divisions: 50, label: '$_bonus%', onChanged: (v) => setState(() => _bonus = v.round())),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Min: ${formatKwacha(_minAmount)}', style: theme.textTheme.bodySmall)),
                Expanded(child: Text('Max: ${formatKwacha(_maxAmount)}', style: theme.textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.save, size: 16),
              label: Text(_saving ? 'Saving…' : 'Save Settings'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _testing ? null : _testAirtime,
              icon: _testing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.zap, size: 16),
              label: Text(_testing ? 'Sending K1…' : 'Test airtime keys (send K1)'),
            ),
            const SizedBox(height: 4),
            Text(
              'Verifies the Africa\'s Talking airtime credentials with a real K1 top-up.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
