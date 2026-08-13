import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/fx_service.dart';
import '../../core/l10n.dart';
import '../../core/push_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/home_carousel.dart';
import '../../core/widgets/info_badge.dart';
import '../../core/widgets/phone_field.dart';
import '../campaigns/campaigns_controller.dart';
import 'auth_controller.dart';

/// First letter of a name for avatars; safe for null/empty values.
String _initial(String? name) {
  final n = name?.trim();
  if (n == null || n.isEmpty) return '?';
  return n.substring(0, 1).toUpperCase();
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _linkTypes = <(String, String)>[
    ('family', 'Family'),
    ('couple', 'Couple'),
    ('team', 'Team'),
    ('friend', 'Friend'),
  ];

  bool _busy = false;
  bool _linksBusy = false;
  bool _testing = false;
  bool _notificationsEnabled = true;
  String? _error;
  List<dynamic> _links = [];
  final Set<int> _pendingAction = {};

  Future<void> _fetchLinks() async {
    try {
      final res = await ref.read(apiClientProvider).getLinks();
      if (mounted) setState(() => _links = res['links'] as List<dynamic>? ?? []);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _fetchLinks();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final enabled = await ref.read(apiClientProvider).getNotificationsEnabled();
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (_) {}
  }

  Future<void> _setNotifications(bool enabled) async {
    setState(() => _busy = true);
    try {
      if (enabled) {
        // Turning push ON also requests the Android 13+ POST_NOTIFICATIONS
        // runtime permission (and re-registers the FCM token) so notifications
        // actually start flowing.
        await ensurePushRegistered();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Push notifications enabled')),
          );
        }
      }
      await ref.read(apiClientProvider).setNotificationsEnabled(enabled);
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update notification settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testNotification() async {
    setState(() => _testing = true);
    try {
      // Make sure the permission is granted + the FCM token re-registered,
      // then ask the backend to push a test to this device.
      await ensurePushRegistered();
      final res = await ref.read(apiClientProvider).sendMyTestPush();
      if (!mounted) return;
      final err = res['error'] as String?;
      final msg = res['message'] as String?;
      final sent = (res['sentCount'] as num?)?.toInt() ?? 0;
      if (err != null && res['ok'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sent == 0
                  ? 'Notification recorded in-app, but your phone has no registered '
                      'device token yet — open the app fully and check notification permission, then try again.'
                  : (msg ?? 'Test push sent — check your notification shade.'),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the test push. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _linkAccount() async {
    String phoneE164 = '';
    var linkType = _linkTypes.first.$1;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link an account'),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              PhoneField(
                onChanged: (e164) => phoneE164 = e164,
                labelText: 'Their mobile number',
                helperText: 'The account you want to link',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: linkType,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: [
                  for (final (value, label) in _linkTypes)
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: (v) => linkType = v ?? 'family',
              ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (phoneE164.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter their phone number.')),
                );
                return;
              }
              if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phoneE164)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Enter a complete phone number (e.g. +260 977 123 456).')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _linksBusy = true);
    try {
      await ref.read(apiClientProvider).linkUser(phoneE164, linkType);
      await _fetchLinks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link request sent. They will receive an SMS to accept.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the link request. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _linksBusy = false);
    }
  }

  Future<void> _respondToLink(int id, bool accept) async {
    setState(() => _pendingAction.add(id));
    try {
      final api = ref.read(apiClientProvider);
      if (accept) {
        await api.acceptLink(id);
      } else {
        await api.rejectLink(id);
      }
      await _fetchLinks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'Account linked!' : 'Link request rejected.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingAction.remove(id));
    }
  }

  Future<void> _editProfile() async {
    final auth = ref.read(authControllerProvider).value;
    final nameController = TextEditingController(text: auth?.name ?? '');
    final usernameController = TextEditingController(text: auth?.username ?? '');
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      hintText: 'How you appear to campaign hosts',
                      prefixIcon: Icon(LucideIcons.userCircle),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    textCapitalization: TextCapitalization.none,
                    maxLength: 24,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText: '3-24 letters, numbers or underscores',
                      prefixIcon: Icon(LucideIcons.atSign),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([nameController, usernameController]),
                builder: (context, _) {
                  final ready = usernameController.text.trim().length >= 3;
                  return FilledButton(
                    onPressed: saving || !ready
                        ? null
                        : () async {
                        setDialogState(() => saving = true);
                        try {
                          await ref
                              .read(authControllerProvider.notifier)
                              .saveProfile(
                                name: nameController.text.trim(),
                                username: usernameController.text.trim(),
                              );
                          ref.invalidate(hostProvider);
                          if (ctx.mounted) {
                            Navigator.pop(ctx, true);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Profile updated.')),
                            );
                          }
                        } on ApiException catch (e) {
                          setDialogState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx)
                                .showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        } catch (_) {
                          setDialogState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Could not save. Try again.')),
                            );
                          }
                        }
                      },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  );
                },
              ),
            ],
        ),
      ),
    );
    if (ok == true && mounted) setState(() {});
    nameController.dispose();
    usernameController.dispose();
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > 3 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo must be under 3 MB. Pick a smaller image.')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await ref.read(apiClientProvider).uploadAvatar(bytes, picked.name);
      final url = res['avatarUrl'] as String?;
      if (url != null) {
        ref.read(authControllerProvider.notifier).setAvatar(url);
        ref.invalidate(hostProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload the photo. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _linkStatusLabel(Map<String, dynamic> link) {
    final isInitiator = link['isInitiator'] == true;
    return switch (link['status']) {
      'pending' => isInitiator ? 'Waiting for them to accept' : 'Wants to link with you',
      'accepted' => 'Linked',
      'rejected' => 'Rejected',
      _ => '${link['status']}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).value;
    final phone = auth?.phone;
    final theme = Theme.of(context);
    final carouselAuto = ref.watch(carouselAutoSlideProvider);
    ref.listen(linksVersionProvider, (_, __) => _fetchLinks());

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(authControllerProvider);
          await _fetchLinks();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _busy ? null : _changePhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Avatar(url: auth?.avatarUrl, name: auth?.username ?? 'Giver', radius: 24),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: _busy
                            ? const Padding(
                                padding: EdgeInsets.all(4),
                                child: AppIconSpinner(size: 12),
                              )
                            : const Icon(LucideIcons.camera, size: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(auth?.name?.isNotEmpty == true ? auth!.name! : phone ?? 'Signed in'),
              subtitle: Text(
                auth?.username != null
                    ? '$phone • ${auth!.username}'
                    : phone ?? 'Account',
              ),
              trailing: IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(LucideIcons.pencil, size: 18),
                onPressed: _editProfile,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: const Icon(LucideIcons.bell, color: AppColors.primary, size: 20),
                  title: const Text('Push notifications',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Donation confirmations, new donors, updates',
                      style: TextStyle(fontSize: 11)),
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _notificationsEnabled,
                      onChanged: _busy ? null : (v) => _setNotifications(v),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: const Icon(LucideIcons.radio, color: AppColors.primary, size: 20),
                  title: const Text('Test notification',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Send a test push to this phone',
                      style: TextStyle(fontSize: 11)),
                  trailing: _testing ? const SizedBox(width: 18, height: 18, child: AppIconSpinner(size: 18)) : const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                  onTap: _testing ? null : _testNotification,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: const Icon(LucideIcons.slidersHorizontal, color: AppColors.primary, size: 20),
              title: const Text('Auto-slide carousel',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text('Rotate the home carousel on its own',
                  style: TextStyle(fontSize: 11)),
              trailing: Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: carouselAuto,
                  onChanged: (v) =>
                      ref.read(carouselAutoSlideProvider.notifier).set(v),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: const Icon(LucideIcons.globe, color: AppColors.primary, size: 20),
              title: const Text('Language',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text('English · Chinyanja · Chibemba · Chitonga',
                  style: TextStyle(fontSize: 11)),
              trailing: DropdownButton<AppLang>(
                value: ref.watch(languageProvider),
                underline: const SizedBox.shrink(),
                items: [
                  for (final l in AppLang.values)
                    DropdownMenuItem(value: l, child: Text(l.label)),
                ],
                onChanged: (v) {
                  if (v != null) ref.read(languageProvider.notifier).set(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: const Icon(LucideIcons.banknote, color: AppColors.primary, size: 20),
              title: const Text('Currency',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text('Zambian Kwacha (K) or US Dollar (\$) at live rates',
                  style: TextStyle(fontSize: 11)),
              trailing: DropdownButton<CurrencyPref>(
                value: ref.watch(currencyPrefProvider),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: CurrencyPref.zmw, child: Text('ZMW (K)')),
                  DropdownMenuItem(value: CurrencyPref.usd, child: Text('USD (\$)')),
                ],
                onChanged: (v) {
                  if (v != null) ref.read(currencyPrefProvider.notifier).set(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: const Icon(LucideIcons.qrCode, color: AppColors.primary, size: 20),
              title: const Text('My QR Code',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text('Show to staff to confirm your profile',
                  style: TextStyle(fontSize: 11)),
              trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
              onTap: () => context.push('/my-qr'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: const Icon(LucideIcons.trophy, color: AppColors.gold, size: 20),
              title: const Text('Achievements',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text('Your badges, level and giving progress',
                  style: TextStyle(fontSize: 11)),
              trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
              onTap: () => context.push('/achievements'),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Family & friends',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              InfoBadge(
                title: 'Family & friends',
                text:
                    'Link family, couple, friend or team accounts to pool your giving. '
                    'When you link, both sides can see the combined amount you have '
                    'all given, share monthly reminder pledges, and your combined '
                    'donor badge grows faster together. The other person gets an SMS '
                    'with a link to accept your request — nothing links until they agree.',
              ),
              OutlinedButton.icon(
                onPressed: _linksBusy ? null : _linkAccount,
                icon: _linksBusy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: AppIconSpinner(size: 16),
                      )
                    : const Icon(LucideIcons.userPlus, size: 16),
                label: const Text('Link Account'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Link family, friends, couple or team accounts to see your combined giving. '
            'The other person must accept before the link activates.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          if (_links.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(LucideIcons.users, color: AppColors.textMuted),
                title: const Text('No linked accounts'),
                subtitle: const Text('Tap "Link account" to connect with someone'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final link in _links)
                    ListTile(
                      dense: true,
                      onTap: () => context.push('/settings/links/${link['id']}/detail'),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          _initial(link['otherUser']?['username'] as String?),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(link['otherUser']?['username'] ?? 'Unknown'),
                      subtitle: Text(
                        '${link['linkType']} • ${_linkStatusLabel(link)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: link['status'] == 'pending' &&
                              link['isInitiator'] != true
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Accept',
                                  icon: const Icon(LucideIcons.checkCircle,
                                      color: AppColors.primary, size: 20),
                                  onPressed: _pendingAction.contains(link['id'])
                                      ? null
                                      : () => _respondToLink(link['id'], true),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Reject',
                                  icon: const Icon(LucideIcons.xCircle,
                                      color: AppColors.danger, size: 20),
                                  onPressed: _pendingAction.contains(link['id'])
                                      ? null
                                      : () => _respondToLink(link['id'], false),
                                ),
                              ],
                            )
                          : _pendingAction.contains(link['id'])
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  link['status'] == 'accepted'
                                      ? LucideIcons.checkCircle
                                      : LucideIcons.clock,
                                  color: link['status'] == 'accepted'
                                      ? AppColors.primary
                                      : AppColors.gold,
                                  size: 18,
                                ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.userPlus, color: AppColors.primary),
                  title: const Text('Invite friends'),
                  subtitle: const Text('Share your referral code and earn the app growth'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push('/settings/referrals'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(LucideIcons.receipt, color: AppColors.primary),
                  title: const Text('My receipts'),
                  subtitle: const Text('Download PDF receipts for your gifts'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push('/settings/receipts'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading:
                      const Icon(LucideIcons.headphones, color: AppColors.primary),
                  title: const Text('Help & support'),
                  subtitle: const Text('Message the admin about any issue'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push('/settings/support'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(LucideIcons.lifeBuoy, color: AppColors.primary),
                  title: const Text('How-Tos'),
                  subtitle: const Text('Tips for giving, hosting and linking accounts'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => _showHowTos(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(LucideIcons.shieldCheck, color: AppColors.primary),
                  title: const Text('Privacy & terms'),
                  subtitle: const Text('Data handling, terms of service, legal (Carpso Solutions)'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push('/settings/legal'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(LucideIcons.trash2, color: AppColors.danger),
              title: const Text('Delete account'),
              subtitle: const Text('Permanently erase your account and personal data'),
              textColor: AppColors.danger,
              onTap: _busy ? null : _deleteAccount,
              trailing: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: AppIconSpinner(size: 20),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.logOut, color: AppColors.primary),
              title: const Text('Sign out'),
              onTap: _busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign out?'),
                          content: const Text('You will need to verify your phone number again to sign back in.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sign out'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      await ref.read(authControllerProvider.notifier).logout();
                      if (!mounted) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) context.go('/login');
                      });
                    },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 24),
          _VersionFooter(),
        ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your profile, pledges, links and device tokens. '
          'Transaction records are retained anonymously for financial compliance. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Future<void> _showHowTos(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How-Tos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HowToItem(
                icon: Icons.favorite,
                title: 'Giving to a campaign',
                body: 'Choose a campaign from the home list, tap Donate, '
                    'then enter an amount and confirm with your mobile '
                    'money PIN. You can give once or set up a monthly '
                    'pledge. Keep your receipt — it’s auto-saved in '
                    'Settings > My receipts.',
              ),
              SizedBox(height: 16),
              _HowToItem(
                icon: Icons.campaign,
                title: 'Hosting a campaign',
                body: 'Go to Host > New campaign, add a title, goal and '
                    'story, then publish. Promote it through your linked '
                    'accounts and the carousel. Track donors and progress '
                    'any time from the Host dashboard.',
              ),
              SizedBox(height: 16),
              _HowToItem(
                icon: Icons.family_restroom,
                title: 'Linking accounts',
                body: 'In Settings > Family & friends, tap Link account '
                    'and enter the phone number of the person you want '
                    'to connect (family, couple, friend or team). They must '
                    'accept the SMS invite before the link activates — '
                    'then you can see combined giving stats.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _HowToItem extends StatelessWidget {
  const _HowToItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// App version footer — reads the real version so it never drifts from the
/// build (pubspec + Play Console).
class _VersionFooter extends StatefulWidget {
  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  String _label = 'Kingdom Sponsor';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _label = 'Kingdom Sponsor v${info.version}');
      }
    } catch (_) {
      if (mounted) setState(() => _label = 'Kingdom Sponsor');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _label,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
    );
  }
}
