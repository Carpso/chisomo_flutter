import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import 'campaigns_controller.dart';

/// A pulsing "LIVE" indicator.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.6), blurRadius: 10)],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.radio, size: 12, color: Colors.white),
            SizedBox(width: 4),
            Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

/// Real-time donor feed: auto-scrolling list of the latest confirmed gifts
/// shown while a campaign/event is live. Refreshes every 4 seconds.
class LiveDonorFeed extends ConsumerStatefulWidget {
  final int campaignId;

  const LiveDonorFeed({super.key, required this.campaignId});

  @override
  ConsumerState<LiveDonorFeed> createState() => _LiveDonorFeedState();
}

class _LiveDonorFeedState extends ConsumerState<LiveDonorFeed> {
  List<dynamic> _donations = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final donations = await ref.read(apiClientProvider).getLiveDonations(widget.campaignId);
      if (mounted && donations.isNotEmpty) setState(() => _donations = donations);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_donations.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 92,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.heartPulse, size: 13, color: AppColors.danger),
              SizedBox(width: 5),
              Text('Live giving', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _donations.length,
              itemBuilder: (context, i) {
                final d = _donations[i];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d['name'] ?? 'Anonymous'}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(
                        d['hidden'] == true
                            ? '•••'
                            : formatKwacha(d['amountCents'] as int? ?? 0),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Host/admin live-session toggle button shown on the campaign/event detail.
class LiveToggleButton extends ConsumerStatefulWidget {
  final int campaignId;
  final bool currentlyLive;

  const LiveToggleButton({super.key, required this.campaignId, required this.currentlyLive});

  @override
  ConsumerState<LiveToggleButton> createState() => _LiveToggleButtonState();
}

class _LiveToggleButtonState extends ConsumerState<LiveToggleButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final next = !widget.currentlyLive;
      await ref.read(apiClientProvider).setLive(widget.campaignId, next);
      ref.invalidate(campaignDetailProvider(widget.campaignId));
      ref.invalidate(campaignsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next ? 'You are LIVE!' : 'Live session ended')),
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not toggle live.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _toggle,
      icon: _busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(widget.currentlyLive ? LucideIcons.radio : LucideIcons.video, size: 16,
              color: widget.currentlyLive ? AppColors.danger : AppColors.primary),
      label: Text(widget.currentlyLive ? 'End Live' : 'Go Live', style: const TextStyle(fontSize: 13)),
      style: widget.currentlyLive
          ? OutlinedButton.styleFrom(foregroundColor: AppColors.danger)
          : null,
    );
  }
}
