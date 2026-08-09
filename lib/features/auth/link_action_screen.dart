import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'auth_controller.dart';

class LinkActionScreen extends ConsumerStatefulWidget {
  const LinkActionScreen({super.key});

  @override
  ConsumerState<LinkActionScreen> createState() => _LinkActionScreenState();
}

class _LinkActionScreenState extends ConsumerState<LinkActionScreen> {
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  Future<void> _handle() async {
    final loc = GoRouterState.of(context).matchedLocation;
    final segments = loc.split('/').where((s) => s.isNotEmpty).toList();
    // Route is /settings/links/<id>/accept (or /reject); the id is second-to-last.
    final idStr = segments.length >= 2 ? segments[segments.length - 2] : '';
    final linkId = int.tryParse(idStr);
    if (linkId == null) {
      setState(() => _message = 'Invalid link.');
      return;
    }

    final isAccept = loc.endsWith('/accept');
    final api = ref.read(apiClientProvider);

    try {
      if (isAccept) {
        await api.acceptLink(linkId);
      } else {
        await api.rejectLink(linkId);
      }
      ref.read(linksVersionProvider.notifier).bump();
      setState(() {
        _success = true;
        _message = isAccept
            ? 'Account linked! Your combined giving is now visible in Settings.'
            : 'Link request declined.';
      });
    } on ApiException catch (e) {
      setState(() => _message = e.message);
    } catch (_) {
      setState(() => _message = 'Something went wrong. Please try again in the app.');
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/settings');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account link')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_message == null)
                const CircularProgressIndicator()
              else
                Icon(
                  _success ? LucideIcons.checkCircle : LucideIcons.xCircle,
                  size: 48,
                  color: _success ? AppColors.primary : AppColors.danger,
                ),
              const SizedBox(height: 16),
              Text(
                _message ?? 'Processing…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
