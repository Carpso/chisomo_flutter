import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';

/// Live countdown ("ends in Xd Yh Zm") shown under a campaign title when it has a deadline.
class CountdownBanner extends StatefulWidget {
  final DateTime endsAt;

  const CountdownBanner({super.key, required this.endsAt});

  @override
  State<CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<CountdownBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _remaining() {
    final diff = widget.endsAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _remaining();
    final urgent = d < const Duration(days: 3);

    final String label;
    if (d.inDays > 0) {
      label = 'Ends in ${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m';
    } else if (d.inHours > 0) {
      label = 'Ends in ${d.inHours}h ${d.inMinutes % 60}m';
    } else if (d.inMinutes > 0) {
      label = 'Ends in ${d.inMinutes}m';
    } else {
      label = 'Campaign deadline reached';
    }

    final color = urgent ? AppColors.danger : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.clock, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
