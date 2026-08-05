import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/phone_field.dart';
import '../campaigns/campaigns_controller.dart';
import 'auth_controller.dart';

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
  ];

  bool _busy = false;
  bool _linksBusy = false;
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
  }

  Future<void> _linkAccount() async {
    String phoneE164 = '';
    var linkType = _linkTypes.first.$1;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link an account'),
        content: Form(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (phoneE164.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter their phone number')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Send request'),
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

  Future<void> _removeLink(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove link?'),
        content: const Text('This account will no longer be linked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _pendingAction.add(id));
    try {
      await ref.read(apiClientProvider).delete('/api/user/links/$id', auth: true);
      await _fetchLinks();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove the link. Try again.')),
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
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: AlertDialog(
            title: const Text('Edit profile'),
            content: SingleChildScrollView(
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
              FilledButton(
                onPressed: saving || usernameController.text.trim().length < 3
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
                              const SnackBar(content: Text('Profile updated')),
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
              ),
            ],
          ),
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
          const SnackBar(content: Text('Profile photo updated')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
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
            child: ListTile(
              leading: const Icon(LucideIcons.logOut, color: AppColors.primary),
              title: const Text('Sign out'),
              onTap: _busy
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (!mounted) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) context.go('/login');
                      });
                    },
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Family & groups',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                label: const Text('Link account'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Link family or group accounts to see their contributions together.',
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
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          ((link['otherUser']?['username'] as String? ?? '?').isNotEmpty
                                  ? link['otherUser']['username'] as String
                                  : '?')
                              .substring(0, 1),
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
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_pendingAction.contains(link['id']))
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Icon(
                                    link['status'] == 'accepted'
                                        ? LucideIcons.checkCircle
                                        : LucideIcons.clock,
                                    color: link['status'] == 'accepted'
                                        ? AppColors.primary
                                        : AppColors.gold,
                                    size: 18,
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove link',
                                  icon: const Icon(LucideIcons.link2Off,
                                      size: 18, color: AppColors.textMuted),
                                  onPressed: _pendingAction.contains(link['id'])
                                      ? null
                                      : () => _removeLink(link['id']),
                                ),
                              ],
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
          Text(
            'Kingdom Sponsor v0.4.0',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
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
}
