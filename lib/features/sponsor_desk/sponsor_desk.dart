import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// A curated grant / empowerment opportunity shown on the Sponsor Desk.
class SponsorOpportunity {
  final int id;
  final String title;
  final String description;
  final String organization;
  final String category;
  final String amountLabel;
  final String? deadline;
  final String link;
  final String audience;
  final String? publishedAt;

  const SponsorOpportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.organization,
    required this.category,
    required this.amountLabel,
    this.deadline,
    required this.link,
    required this.audience,
    this.publishedAt,
  });

  factory SponsorOpportunity.fromJson(Map<String, dynamic> j) => SponsorOpportunity(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        organization: j['organization'] as String? ?? '',
        category: j['category'] as String? ?? 'Grant',
        amountLabel: j['amountLabel'] as String? ?? '',
        deadline: j['deadline'] as String?,
        link: j['link'] as String? ?? '',
        audience: j['audience'] as String? ?? 'hosts',
        publishedAt: j['publishedAt'] as String?,
      );

  bool get hasDeadline => deadline != null && deadline!.isNotEmpty;

  bool get hasLink => link.isNotEmpty && link.startsWith('http');
}

/// Public Sponsor Desk feed for hosts (published, active opportunities).
final sponsorDeskProvider = FutureProvider<List<SponsorOpportunity>>((ref) async {
  final rows = await ref.read(apiClientProvider).getSponsorDesk();
  return rows
      .whereType<Map>()
      .map((o) => SponsorOpportunity.fromJson(Map<String, dynamic>.from(o)))
      .where((o) => o.id > 0)
      .toList();
});
