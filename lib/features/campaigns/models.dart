import '../../core/money.dart';

/// Curated campaign categories (kept in sync with the backend list in
/// `src/categories.ts` — the API validates against its copy).
const kCampaignCategories = [
  'Other',
  'Church & Ministry',
  'Missions & Evangelism',
  'Music & Worship',
  'Bible School & Discipleship',
  'Education & School Fees',
  'Bursary & Scholarships',
  'Medical & Health',
  'Disability Support',
  'Funeral & Memorial',
  'Children & Orphans',
  "Women's Empowerment",
  'Youth & Sports',
  'Marriage & Family',
  'Elderly Care',
  'Community Development',
  'Food & Hunger Relief',
  'Water & Sanitation',
  'Solar & Electricity',
  'Disaster & Emergency Relief',
  'Refugee & Migrant Support',
  'Prison Ministry',
  'Agriculture & Farming',
  'Livestock & Seeds',
  'Business & Startups',
  'Construction & Buildings',
  'Transport & Vehicles',
  'Clothing & Household',
  'Technology & Devices',
  'Weddings & Celebrations',
  'Environmental & Conservation',
];

/// Alphabetical category list for dropdowns ('Other' stays first).
final List<String> kSortedCategories = [
  'Other',
  ...(kCampaignCategories.where((c) => c != 'Other').toList()..sort()),
];

/// Campaign market segments (kept in sync with backend `CAMPAIGN_TYPES`).
const kCampaignTypes = <String, String>{
  'community': 'Community project',
  'ngo': 'NGO / organisation',
  'faith': 'Church & faith',
  'emergency': 'Emergency / urgent',
  'medical': 'Medical & treatment',
  'sponsor': 'Sponsorship / event',
};

class Campaign {
  final int id;
  final String slug;
  final String title;
  final String description;
  final String? imageUrl;
  final String? logoUrl;
  final int goalCents;
  final bool hasGoal;
  final int raisedCents;
  final int withdrawnCents;
  final int donorCount;
  final int donationCount;
  final int avgDonationCents;
  final int? donorsNeededAtAvg;
  final int dailyRateCents;
  final String? estimatedEndDate;
  final String? endsAt;
  final String status;
  final int? availableCents;
  final int? minWithdrawCents;
  final bool promoted;
  final String? promotedUntil;
  final String createdAt;
  final String? shareUrl;
  final String? hostName;
  final String category;
  final String visibility;
  final bool hostVerified;
  final String campaignType;
  final String? hostOrg;
  final bool waivePayoutFees;
  final List<EventTier> eventTiers;
  final int eventCapacity;
  final String? eventDate;
  final String? eventVenue;
  final int ticketsSold;
  final int rsvpCount;
  final bool isMine;
  final bool isLive;

  const Campaign({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.logoUrl,
    required this.goalCents,
    required this.hasGoal,
    required this.raisedCents,
    required this.withdrawnCents,
    required this.donorCount,
    required this.donationCount,
    required this.avgDonationCents,
    required this.donorsNeededAtAvg,
    required this.dailyRateCents,
    this.estimatedEndDate,
    this.endsAt,
    required this.status,
    this.availableCents,
    this.minWithdrawCents,
    this.promoted = false,
    this.promotedUntil,
    required this.createdAt,
    this.shareUrl,
    this.hostName,
    this.category = 'Other',
    this.visibility = 'public',
    this.hostVerified = false,
    this.campaignType = 'community',
    this.hostOrg,
    this.waivePayoutFees = false,
    this.eventTiers = const [],
    this.eventCapacity = 0,
    this.eventDate,
    this.eventVenue,
    this.ticketsSold = 0,
    this.rsvpCount = 0,
    this.isMine = false,
    this.isLive = false,
  });

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
    id: (j['id'] is num) ? (j['id'] as num).toInt() : 0,
    slug: j['slug'] as String? ?? '',
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    imageUrl: j['imageUrl'] as String?,
    logoUrl: j['logoUrl'] as String?,
    goalCents: (j['goalCents'] is num) ? (j['goalCents'] as num).toInt() : 0,
    hasGoal: j['hasGoal'] as bool? ?? ((j['goalCents'] is num && (j['goalCents'] as num) > 0)),
    raisedCents: (j['raisedCents'] is num) ? (j['raisedCents'] as num).toInt() : 0,
    withdrawnCents: (j['withdrawnCents'] is num) ? (j['withdrawnCents'] as num).toInt() : 0,
    donorCount: (j['donorCount'] is num) ? (j['donorCount'] as num).toInt() : 0,
    donationCount: (j['donationCount'] is num) ? (j['donationCount'] as num).toInt() : ((j['donorCount'] is num) ? (j['donorCount'] as num).toInt() : 0),
    avgDonationCents: (j['avgDonationCents'] is num) ? (j['avgDonationCents'] as num).toInt() : 0,
    donorsNeededAtAvg: (j['donorsNeededAtAvg'] is num) ? (j['donorsNeededAtAvg'] as num).toInt() : null,
    dailyRateCents: (j['dailyRateCents'] is num) ? (j['dailyRateCents'] as num).toInt() : 0,
    estimatedEndDate: j['estimatedEndDate'] as String?,
    endsAt: j['endsAt'] as String?,
    status: j['status'] as String? ?? 'active',
    availableCents: (j['availableCents'] is num) ? (j['availableCents'] as num).toInt() : null,
    minWithdrawCents: (j['minWithdrawCents'] is num) ? (j['minWithdrawCents'] as num).toInt() : null,
    promoted: j['promoted'] == true,
    promotedUntil: j['promotedUntil'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
    shareUrl: j['shareUrl'] as String?,
    hostName: j['hostName'] as String?,
    category: j['category'] as String? ?? 'Other',
    visibility: j['visibility'] as String? ?? 'public',
    hostVerified: j['hostVerified'] == true,
    campaignType: j['campaignType'] as String? ?? 'community',
    hostOrg: j['hostOrg'] as String?,
    waivePayoutFees: j['waivePayoutFees'] == true,
    eventTiers: (j['eventTiers'] is List)
        ? (j['eventTiers'] as List).whereType<Map>().map((t) => EventTier.fromJson(Map<String, dynamic>.from(t))).toList()
        : const [],
    eventCapacity: (j['eventCapacity'] is num) ? (j['eventCapacity'] as num).toInt() : 0,
    eventDate: j['eventDate'] as String?,
    eventVenue: j['eventVenue'] as String?,
    ticketsSold: (j['ticketsSold'] is num) ? (j['ticketsSold'] as num).toInt() : 0,
    rsvpCount: (j['rsvpCount'] is num) ? (j['rsvpCount'] as num).toInt() : 0,
    isMine: j['isMine'] == true,
    isLive: j['isLive'] == true,
  );

  double get progress =>
      goalCents <= 0 ? 0 : (raisedCents / goalCents).clamp(0.0, 1.0);

  bool get isPrivate => visibility == 'private';

  /// True when the campaign is an event (ticketed tiers OR the event type).
  /// Mirrors the backend's `isEventLike` so a ticketed event whose tiers failed
  /// to parse still routes to the event/buy-ticket flow instead of RSVP.
  bool get isEvent => eventTiers.isNotEmpty || campaignType == 'event';

  /// Events that sell tickets (have tiers) use the Buy Ticket button; events
  /// with no tiers are free and use RSVP instead.
  bool get isTicketedEvent => isEvent && eventTiers.isNotEmpty;

  bool get isSoldOut => eventCapacity > 0 && ticketsSold >= eventCapacity;

  String get raisedLabel => formatKwacha(raisedCents);

  String get goalLabel => formatKwacha(goalCents);

  String get availableLabel =>
      availableCents == null ? '' : formatKwacha(availableCents!);
}

/// A purchasable ticket tier for an event-style campaign.
class EventTier {
  final String name;
  final int amountCents;

  const EventTier({required this.name, required this.amountCents});

  factory EventTier.fromJson(Map<String, dynamic> j) => EventTier(
    name: j['name'] as String? ?? 'Ticket',
    amountCents: (j['amountCents'] is num) ? (j['amountCents'] as num).toInt() : 0,
  );

  Map<String, dynamic> toJson() => {'name': name, 'amountCents': amountCents};
}

/// A donor's monthly "give again" reminder on a campaign.
class Pledge {
  final int id;
  final int campaignId;
  final String campaignTitle;
  final String campaignSlug;
  final int amountCents;
  final int dayOfMonth;
  final bool active;
  final String? lastRemindedAt;

  const Pledge({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.campaignSlug,
    required this.amountCents,
    required this.dayOfMonth,
    required this.active,
    this.lastRemindedAt,
  });

  factory Pledge.fromJson(Map<String, dynamic> j) => Pledge(
    id: j['id'] as int,
    campaignId: j['campaignId'] as int,
    campaignTitle: j['campaignTitle'] as String? ?? '',
    campaignSlug: j['campaignSlug'] as String? ?? '',
    amountCents: j['amountCents'] as int? ?? 0,
    dayOfMonth: j['dayOfMonth'] as int? ?? 1,
    active: j['active'] as bool? ?? false,
    lastRemindedAt: j['lastRemindedAt'] as String?,
  );
}

/// Live state of the paid top-5 promotion slots.
class PromotionInfo {
  final int slots;
  final int active;
  final int available;
  final int priceCents;
  final int days;
  final List<int> promotedIds;

  const PromotionInfo({
    required this.slots,
    required this.active,
    required this.available,
    required this.priceCents,
    required this.days,
    required this.promotedIds,
  });

  factory PromotionInfo.fromJson(Map<String, dynamic> j) => PromotionInfo(
    slots: j['slots'] as int? ?? 5,
    active: j['active'] as int? ?? 0,
    available: j['available'] as int? ?? 5,
    priceCents: j['priceCents'] as int? ?? 15000,
    days: j['days'] as int? ?? 7,
    promotedIds: (j['promotedIds'] as List<dynamic>? ?? [])
        .map((e) => e as int)
        .toList(),
  );
}

class AdminPromotion {
  final int id;
  final int campaignId;
  final String campaignTitle;
  final String hostPhone;
  final int amountCents;
  final int days;
  final String status;
  final String? reference;
  final String? expiresAt;
  final String createdAt;

  const AdminPromotion({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.hostPhone,
    required this.amountCents,
    required this.days,
    required this.status,
    required this.reference,
    required this.expiresAt,
    required this.createdAt,
  });

  factory AdminPromotion.fromJson(Map<String, dynamic> j) => AdminPromotion(
    id: j['id'] as int? ?? 0,
    campaignId: j['campaignId'] as int? ?? 0,
    campaignTitle: j['campaignTitle'] as String? ?? '',
    hostPhone: j['hostPhone'] as String? ?? '',
    amountCents: j['amountCents'] as int? ?? 0,
    days: j['days'] as int? ?? 0,
    status: j['status'] as String? ?? '',
    reference: j['reference'] as String?,
    expiresAt: j['expiresAt'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );
}

/// A host's own promotion purchase history.
class MyPromotion {
  final int id;
  final int campaignId;
  final String campaignTitle;
  final int amountCents;
  final int days;
  final String status;
  final String? reference;
  final String? expiresAt;
  final String createdAt;

  const MyPromotion({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.amountCents,
    required this.days,
    required this.status,
    this.reference,
    this.expiresAt,
    required this.createdAt,
  });

  factory MyPromotion.fromJson(Map<String, dynamic> j) => MyPromotion(
    id: j['id'] as int? ?? 0,
    campaignId: j['campaignId'] as int? ?? 0,
    campaignTitle: j['campaignTitle'] as String? ?? '',
    amountCents: j['amountCents'] as int? ?? 0,
    days: j['days'] as int? ?? 0,
    status: j['status'] as String? ?? '',
    reference: j['reference'] as String?,
    expiresAt: j['expiresAt'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Awaiting payment';
      case 'pending_approval':
        return 'Paid — awaiting approval';
      case 'active':
        return 'Live on top of the list';
      case 'rejected':
        return 'Rejected by admin';
      case 'expired':
        return 'Expired';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }
}

class Donor {
  final String username;
  final String? name;
  final String? avatarUrl;
  final bool isAnonymous;
  final int? amountCents;
  final String? tier;
  final String date;
  final int donationCount;
  final int hiddenCount;

  const Donor({
    required this.username,
    required this.name,
    this.avatarUrl,
    required this.isAnonymous,
    required this.amountCents,
    required this.tier,
    required this.date,
    this.donationCount = 1,
    this.hiddenCount = 0,
  });

  factory Donor.fromJson(Map<String, dynamic> j) => Donor(
    username: j['username'] as String? ?? 'Giver',
    name: j['name'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    isAnonymous: j['isAnonymous'] as bool? ?? false,
    amountCents: j['amountCents'] as int?,
    tier: j['tier'] as String?,
    date: j['date'] as String? ?? '',
    donationCount: j['donationCount'] as int? ?? 1,
    hiddenCount: j['hiddenCount'] as int? ?? 0,
  );

  String get displayName => name ?? username;

  bool get amountHidden => amountCents == null;

  /// Smart summary of the donor's (possibly merged) donations:
  /// date, how many donations, and whether some amounts are hidden.
  String get summary {
    final parts = <String>[date];
    if (donationCount > 1) parts.add('$donationCount donations');
    if (hiddenCount > 0) {
      parts.add(
        hiddenCount == donationCount ? 'amount hidden' : '$hiddenCount hidden',
      );
    }
    return parts.join(' • ');
  }
}

class LeaderboardEntry {
  final String username;
  final int totalCents;
  final String tier;

  const LeaderboardEntry({
    required this.username,
    required this.totalCents,
    required this.tier,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    username: j['username'] as String? ?? 'Giver',
    totalCents: j['totalCents'] as int? ?? 0,
    tier: j['tier'] as String? ?? 'Giver',
  );
}

class FeesInfo {
  final double platformPct;
  final int platformMinFeeCents;
  final int platformFixedFeeCents;
  final double momoPct;
  final double totalPct;
  final double disbursementPct;
  final double cardPct;
  final int cardMinFeeCents;
  final double cardLipilaPct;

  const FeesInfo({
    required this.platformPct,
    required this.platformMinFeeCents,
    required this.platformFixedFeeCents,
    required this.momoPct,
    required this.totalPct,
    required this.disbursementPct,
    this.cardPct = 2,
    this.cardMinFeeCents = 500,
    this.cardLipilaPct = 2.5,
  });

  factory FeesInfo.fromJson(Map<String, dynamic> j) => FeesInfo(
    platformPct: (j['platformPct'] as num? ?? 1).toDouble(),
    platformMinFeeCents: j['platformMinFeeCents'] as int? ?? 300,
    platformFixedFeeCents: j['platformFixedFeeCents'] as int? ?? 48,
    momoPct: (j['momoPct'] as num? ?? 2.5).toDouble(),
    totalPct: (j['totalPct'] as num? ?? 3.5).toDouble(),
    disbursementPct: (j['disbursementPct'] as num? ?? 1.5).toDouble(),
    cardPct: (j['cardPct'] as num? ?? 2).toDouble(),
    cardMinFeeCents: j['cardMinFeeCents'] as int? ?? 500,
    cardLipilaPct: (j['cardLipilaPct'] as num? ?? 2.5).toDouble(),
  );
}

class CampaignDetail {
  final Campaign campaign;
  final List<Donor> donors;
  final List<LeaderboardEntry> leaderboard;
  final FeesInfo fees;

  const CampaignDetail({
    required this.campaign,
    required this.donors,
    required this.leaderboard,
    required this.fees,
  });

  factory CampaignDetail.fromJson(Map<String, dynamic> j) => CampaignDetail(
    campaign: Campaign.fromJson(j['campaign'] as Map<String, dynamic>),
    donors: (j['donors'] as List<dynamic>? ?? [])
        .map((d) => Donor.fromJson(d as Map<String, dynamic>))
        .toList(),
    leaderboard: (j['leaderboard'] as List<dynamic>? ?? [])
        .map((l) => LeaderboardEntry.fromJson(l as Map<String, dynamic>))
        .toList(),
    fees: FeesInfo.fromJson(j['fees'] as Map<String, dynamic>? ?? {}),
  );
}

class Transaction {
  final int id;
  final int? campaignId;
  final String campaignTitle;
  final String? donorName;
  final bool isAnonymous;
  final String phone;
  final int amountCents;
  final int platformFeeCents;
  final int lipilaFeeCents;
  final String status;
  final String? lipilaReference;
  final String? lipilaIdentifier;
  final String? confirmedAt;
  final String createdAt;

  const Transaction({
    required this.id,
    this.campaignId,
    required this.campaignTitle,
    this.donorName,
    this.isAnonymous = false,
    required this.phone,
    required this.amountCents,
    required this.platformFeeCents,
    required this.lipilaFeeCents,
    required this.status,
    this.lipilaReference,
    this.lipilaIdentifier,
    this.confirmedAt,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: j['id'] as int,
    campaignId: j['campaignId'] as int?,
    campaignTitle: j['campaignTitle'] as String? ?? '',
    donorName: j['donorName'] as String?,
    isAnonymous: j['isAnonymous'] as bool? ?? false,
    phone: j['phone'] as String? ?? '',
    amountCents: j['amountCents'] as int? ?? 0,
    platformFeeCents: j['platformFeeCents'] as int? ?? 0,
    lipilaFeeCents: j['lipilaFeeCents'] as int? ?? 0,
    status: j['status'] as String? ?? '',
    lipilaReference: j['lipilaReference'] as String?,
    lipilaIdentifier: j['lipilaIdentifier'] as String?,
    confirmedAt: j['confirmedAt'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );

  String get displayName => isAnonymous ? 'Anonymous' : (donorName ?? 'Giver');
}

class HostUser {
  final int id;
  final String phone;
  final String username;
  final String? name;
  final String? avatarUrl;
  final bool isHost;
  final bool isAdmin;
  final String hostStatus;
  final String? hostOrg;
  final String? hostRole;
  final String? hostRejection;
  final int totalGivenCents;
  final String tier;

  const HostUser({
    required this.id,
    required this.phone,
    required this.username,
    this.name,
    this.avatarUrl,
    required this.isHost,
    required this.isAdmin,
    required this.hostStatus,
    required this.hostOrg,
    required this.hostRole,
    required this.hostRejection,
    required this.totalGivenCents,
    required this.tier,
  });

  factory HostUser.fromJson(Map<String, dynamic> j) => HostUser(
    id: j['id'] as int? ?? 0,
    phone: j['phone'] as String? ?? '',
    username: j['username'] as String? ?? 'Giver',
    name: j['name'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    isHost: j['isHost'] as bool? ?? false,
    isAdmin: j['isAdmin'] as bool? ?? false,
    hostStatus: j['hostStatus'] as String? ?? 'none',
    hostOrg: j['hostOrg'] as String?,
    hostRole: j['hostRole'] as String?,
    hostRejection: j['hostRejection'] as String?,
    totalGivenCents: j['totalGivenCents'] as int? ?? 0,
    tier: j['tier'] as String? ?? 'Giver',
  );
}

class HostApplication {
  final int id;
  final String phone;
  final String username;
  final String hostStatus;
  final String? org;
  final String? role;
  final String? reason;
  final String? rejection;
  final String appliedAt;

  const HostApplication({
    required this.id,
    required this.phone,
    required this.username,
    required this.hostStatus,
    required this.org,
    required this.role,
    required this.reason,
    required this.rejection,
    required this.appliedAt,
  });

  factory HostApplication.fromJson(Map<String, dynamic> j) => HostApplication(
    id: j['id'] as int,
    phone: j['phone'] as String? ?? '',
    username: j['username'] as String? ?? 'Giver',
    hostStatus: j['hostStatus'] as String? ?? 'none',
    org: j['org'] as String?,
    role: j['role'] as String?,
    reason: j['reason'] as String?,
    rejection: j['rejection'] as String?,
    appliedAt: j['appliedAt'] as String? ?? '',
  );
}

class AdminStats {
  final int totalRaisedCents;
  final int totalActiveRaisedCents;
  final int confirmedDonations;
  final int donors;
  final int platformFeesCents;
  final int activeCampaigns;
  final int pendingApplications;
  final int dailyRateCents;
  final int usersTotal;
  final int hostsTotal;
  final int newUsers7d;
  final int newUsers30d;
  final int campaignsTotal;
  final int newCampaigns7d;
  final int newCampaigns30d;
  final int donationsTotal;
  final int newDonations7d;
  final int newDonations30d;
  final int receiptsDownloaded;
  final int receiptsDownloaded7d;
  final int activePledges;
  final int openTickets;
  final int pendingDeleteRequests;
  final int qualifiedReferrers;
  final int totalProcessedCents;
  final int assistants;
  final int pendingEditRequests;
  final int activeEvents;
  final int ticketsSold;
  final int ticketsSoldValueCents;
  final int pendingAnnouncements;
  final int cardEmails;

  const AdminStats({
    required this.totalRaisedCents,
    required this.totalActiveRaisedCents,
    required this.confirmedDonations,
    required this.donors,
    required this.platformFeesCents,
    required this.activeCampaigns,
    required this.pendingApplications,
    required this.dailyRateCents,
    required this.usersTotal,
    required this.hostsTotal,
    required this.newUsers7d,
    required this.newUsers30d,
    required this.campaignsTotal,
    required this.newCampaigns7d,
    required this.newCampaigns30d,
    required this.donationsTotal,
    required this.newDonations7d,
    required this.newDonations30d,
    required this.receiptsDownloaded,
    required this.receiptsDownloaded7d,
    required this.activePledges,
    required this.openTickets,
    required this.pendingDeleteRequests,
    this.qualifiedReferrers = 0,
    this.totalProcessedCents = 0,
    this.assistants = 0,
    this.pendingEditRequests = 0,
    this.activeEvents = 0,
    this.ticketsSold = 0,
    this.ticketsSoldValueCents = 0,
    this.pendingAnnouncements = 0,
    this.cardEmails = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
    totalRaisedCents: j['totalRaisedCents'] as int? ?? 0,
    totalActiveRaisedCents: j['totalActiveRaisedCents'] as int? ?? j['totalRaisedCents'] as int? ?? 0,
    confirmedDonations: j['confirmedDonations'] as int? ?? 0,
    donors: j['donors'] as int? ?? 0,
    platformFeesCents: j['platformFeesCents'] as int? ?? 0,
    activeCampaigns: j['activeCampaigns'] as int? ?? 0,
    pendingApplications: j['pendingApplications'] as int? ?? 0,
    dailyRateCents: j['dailyRateCents'] as int? ?? 0,
    usersTotal: j['usersTotal'] as int? ?? 0,
    hostsTotal: j['hostsTotal'] as int? ?? 0,
    newUsers7d: j['newUsers7d'] as int? ?? 0,
    newUsers30d: j['newUsers30d'] as int? ?? 0,
    campaignsTotal: j['campaignsTotal'] as int? ?? 0,
    newCampaigns7d: j['newCampaigns7d'] as int? ?? 0,
    newCampaigns30d: j['newCampaigns30d'] as int? ?? 0,
    donationsTotal: j['donationsTotal'] as int? ?? 0,
    newDonations7d: j['newDonations7d'] as int? ?? 0,
    newDonations30d: j['newDonations30d'] as int? ?? 0,
    receiptsDownloaded: j['receiptsDownloaded'] as int? ?? 0,
    receiptsDownloaded7d: j['receiptsDownloaded7d'] as int? ?? 0,
    activePledges: j['activePledges'] as int? ?? 0,
    openTickets: j['openTickets'] as int? ?? 0,
    pendingDeleteRequests: j['pendingDeleteRequests'] as int? ?? 0,
    qualifiedReferrers: j['qualifiedReferrers'] as int? ?? 0,
    totalProcessedCents: j['totalProcessedCents'] as int? ?? 0,
    assistants: j['assistants'] as int? ?? 0,
    pendingEditRequests: j['pendingEditRequests'] as int? ?? 0,
    activeEvents: j['activeEvents'] as int? ?? 0,
    ticketsSold: j['ticketsSold'] as int? ?? 0,
    ticketsSoldValueCents: j['ticketsSoldValueCents'] as int? ?? 0,
    pendingAnnouncements: j['pendingAnnouncements'] as int? ?? 0,
    cardEmails: j['cardEmails'] as int? ?? 0,
  );
}

class AdminTransaction {
  final int id;
  final int? campaignId;
  final String campaignTitle;
  final String? donorName;
  final bool isAnonymous;
  final String phone;
  final int amountCents;
  final int platformFeeCents;
  final int lipilaFeeCents;
  final String status;
  final String? lipilaReference;
  final String? confirmedAt;
  final String createdAt;

  const AdminTransaction({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.donorName,
    required this.isAnonymous,
    required this.phone,
    required this.amountCents,
    required this.platformFeeCents,
    required this.lipilaFeeCents,
    required this.status,
    required this.lipilaReference,
    required this.confirmedAt,
    required this.createdAt,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> j) => AdminTransaction(
    id: j['id'] as int? ?? 0,
    campaignId: j['campaignId'] as int?,
    campaignTitle: j['campaignTitle'] as String? ?? '',
    donorName: j['donorName'] as String?,
    isAnonymous: j['isAnonymous'] as bool? ?? false,
    phone: j['phone'] as String? ?? '',
    amountCents: j['amountCents'] as int? ?? 0,
    platformFeeCents: j['platformFeeCents'] as int? ?? 0,
    lipilaFeeCents: j['lipilaFeeCents'] as int? ?? 0,
    status: j['status'] as String? ?? '',
    lipilaReference: j['lipilaReference'] as String?,
    confirmedAt: j['confirmedAt'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );

  String get displayName => isAnonymous ? 'Anonymous' : (donorName ?? 'Giver');
}

/// Full detail for one transaction (admin view).
class TransactionDetail {
  final int id;
  final int? campaignId;
  final String campaignTitle;
  final String? donorUsername;
  final String? donorName;
  final bool isAnonymous;
  final String phone;
  final int amountCents;
  final int platformFeeCents;
  final int lipilaFeeCents;
  final int payoutCents;
  final String status;
  final String? lipilaReference;
  final String? lipilaIdentifier;
  final String? confirmedAt;
  final String createdAt;
  final bool hideAmount;

  const TransactionDetail({
    required this.id,
    this.campaignId,
    required this.campaignTitle,
    this.donorUsername,
    this.donorName,
    this.isAnonymous = false,
    required this.phone,
    required this.amountCents,
    required this.platformFeeCents,
    required this.lipilaFeeCents,
    required this.payoutCents,
    required this.status,
    this.lipilaReference,
    this.lipilaIdentifier,
    this.confirmedAt,
    required this.createdAt,
    this.hideAmount = false,
  });

  factory TransactionDetail.fromJson(Map<String, dynamic> j) =>
      TransactionDetail(
        id: j['id'] as int? ?? 0,
        campaignId: j['campaignId'] as int?,
        campaignTitle: j['campaignTitle'] as String? ?? '',
        donorUsername: j['donorUsername'] as String?,
        donorName: j['donorName'] as String?,
        isAnonymous: j['isAnonymous'] as bool? ?? false,
        phone: j['phone'] as String? ?? '',
        amountCents: j['amountCents'] as int? ?? 0,
        platformFeeCents: j['platformFeeCents'] as int? ?? 0,
        lipilaFeeCents: j['lipilaFeeCents'] as int? ?? 0,
        payoutCents: j['payoutCents'] as int? ?? 0,
        status: j['status'] as String? ?? '',
        lipilaReference: j['lipilaReference'] as String?,
        lipilaIdentifier: j['lipilaIdentifier'] as String?,
        confirmedAt: j['confirmedAt'] as String?,
        createdAt: j['createdAt'] as String? ?? '',
        hideAmount: j['hideAmount'] as bool? ?? false,
      );

  String get displayName =>
      isAnonymous ? 'Anonymous' : (donorName ?? donorUsername ?? 'Giver');
}

class Disbursement {
  final String kind; // payout | sweep | admin_withdraw
  final String id;
  final int? campaignId;
  final String campaignTitle;
  final int amountCents;
  final int lipilaFeeCents;
  final int platformFeeCents;
  final String? lipilaReference;
  final String? hostPhone;
  final String status;
  final String createdAt;

  const Disbursement({
    required this.kind,
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.amountCents,
    required this.lipilaFeeCents,
    required this.platformFeeCents,
    required this.lipilaReference,
    this.hostPhone,
    required this.status,
    required this.createdAt,
  });

  factory Disbursement.fromJson(Map<String, dynamic> j) => Disbursement(
    kind: j['kind'] as String? ?? 'payout',
    id: j['id'] as String? ?? '',
    campaignId: j['campaignId'] as int?,
    campaignTitle: j['campaignTitle'] as String? ?? '',
    amountCents: j['amountCents'] as int? ?? 0,
    lipilaFeeCents: j['lipilaFeeCents'] as int? ?? 0,
    platformFeeCents: j['platformFeeCents'] as int? ?? 0,
    lipilaReference: j['lipilaReference'] as String?,
    hostPhone: j['hostPhone'] as String?,
    status: j['status'] as String? ?? '',
    createdAt: j['createdAt'] as String? ?? '',
  );
}

class AdminRecent {
  final String username;
  final int amountCents;
  final int platformFeeCents;
  final String campaignTitle;
  final String date;

  const AdminRecent({
    required this.username,
    required this.amountCents,
    required this.platformFeeCents,
    required this.campaignTitle,
    required this.date,
  });

  factory AdminRecent.fromJson(Map<String, dynamic> j) => AdminRecent(
    username: j['username'] as String? ?? 'Giver',
    amountCents: j['amountCents'] as int? ?? 0,
    platformFeeCents: j['platformFeeCents'] as int? ?? 0,
    campaignTitle: j['campaignTitle'] as String? ?? '',
    date: j['date'] as String? ?? '',
  );
}

class ReferralEntry {
  final String username;
  final int invites;

  const ReferralEntry({required this.username, required this.invites});

  factory ReferralEntry.fromJson(Map<String, dynamic> j) => ReferralEntry(
    username: j['username'] as String? ?? 'Giver',
    invites: j['invites'] as int? ?? 0,
  );
}

class RecentUser {
  final int id;
  final String phone;
  final String username;
  final String? name;
  final String hostStatus;
  final String createdAt;

  const RecentUser({
    required this.id,
    required this.phone,
    required this.username,
    this.name,
    required this.hostStatus,
    required this.createdAt,
  });

  factory RecentUser.fromJson(Map<String, dynamic> j) => RecentUser(
    id: j['id'] as int? ?? 0,
    phone: j['phone'] as String? ?? '',
    username: j['username'] as String? ?? 'Giver',
    name: j['name'] as String?,
    hostStatus: j['hostStatus'] as String? ?? 'none',
    createdAt: j['createdAt'] as String? ?? '',
  );

  String get displayName => name ?? username;
}

/// A user row in the admin "All users" list (name, phone, giving, invites…).
class AdminUser {
  final int id;
  final String phone;
  final String username;
  final String? name;
  final String? avatarUrl;
  final String hostStatus;
  final String? hostOrg;
  final String? orgType;
  final String? lastLoginAt;
  final String kycStatus;
  final String? kycType;
  final String? kycDocUrl;
  final bool isHost;
  final bool banned;
  final String? banReason;
  final String? referralRewardedAt;
  final int givenCents;
  final int invites;
  final String createdAt;

  const AdminUser({
    required this.id,
    required this.phone,
    required this.username,
    this.name,
    this.avatarUrl,
    required this.hostStatus,
    this.hostOrg,
    this.orgType,
    this.lastLoginAt,
    this.kycStatus = 'none',
    this.kycType,
    this.kycDocUrl,
    required this.isHost,
    required this.banned,
    this.banReason,
    this.referralRewardedAt,
    required this.givenCents,
    required this.invites,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] as int? ?? 0,
    phone: j['phone'] as String? ?? '',
    username: j['username'] as String? ?? 'Giver',
    name: j['name'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    hostStatus: j['hostStatus'] as String? ?? 'none',
    hostOrg: j['hostOrg'] as String?,
    orgType: j['orgType'] as String?,
    lastLoginAt: j['lastLoginAt'] as String?,
    kycStatus: j['kycStatus'] as String? ?? 'none',
    kycType: j['kycType'] as String?,
    kycDocUrl: j['kycDocUrl'] as String?,
    isHost: j['isHost'] as bool? ?? false,
    banned: j['banned'] as bool? ?? false,
    banReason: j['banReason'] as String?,
    referralRewardedAt: j['referralRewardedAt'] as String?,
    givenCents: j['givenCents'] as int? ?? 0,
    invites: j['invites'] as int? ?? 0,
    createdAt: j['createdAt'] as String? ?? '',
  );

  String get displayName => name ?? username;
}

class AdminData {
  final AdminStats stats;
  final List<HostApplication> applications;
  final List<Campaign> topCampaigns;
  final List<LeaderboardEntry> topDonors;
  final List<ReferralEntry> topReferrers;
  final List<AdminRecent> recent;
  final List<RecentUser> recentUsers;
  final List<Campaign> allCampaigns;

  const AdminData({
    required this.stats,
    required this.applications,
    required this.topCampaigns,
    required this.topDonors,
    required this.topReferrers,
    required this.recent,
    required this.recentUsers,
    required this.allCampaigns,
  });

  factory AdminData.fromJson(
    Map<String, dynamic> statsJson,
    Map<String, dynamic> appsJson,
    Map<String, dynamic> campaignsJson,
  ) => AdminData(
    stats: AdminStats.fromJson(
      statsJson['stats'] as Map<String, dynamic>? ?? {},
    ),
    applications: (appsJson['applications'] as List<dynamic>? ?? [])
        .map((a) => HostApplication.fromJson(a as Map<String, dynamic>))
        .toList(),
    topCampaigns: (statsJson['topCampaigns'] as List<dynamic>? ?? [])
        .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
        .toList(),
    topDonors: (statsJson['topDonors'] as List<dynamic>? ?? [])
        .map((d) => LeaderboardEntry.fromJson(d as Map<String, dynamic>))
        .toList(),
    topReferrers: (statsJson['topReferrers'] as List<dynamic>? ?? [])
        .map((r) => ReferralEntry.fromJson(r as Map<String, dynamic>))
        .toList(),
    recent: (statsJson['recent'] as List<dynamic>? ?? [])
        .map((r) => AdminRecent.fromJson(r as Map<String, dynamic>))
        .toList(),
    recentUsers: (statsJson['recentUsers'] as List<dynamic>? ?? [])
        .map((r) => RecentUser.fromJson(r as Map<String, dynamic>))
        .toList(),
    allCampaigns: (campaignsJson['campaigns'] as List<dynamic>? ?? [])
        .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class HostPayout {
  final int id;
  final String campaignTitle;
  final int amountCents;
  final int disbursementFeeCents;
  final int platformFeeCents;
  final String status;
  final String? reference;
  final String date;

  const HostPayout({
    required this.id,
    required this.campaignTitle,
    required this.amountCents,
    required this.disbursementFeeCents,
    required this.platformFeeCents,
    required this.status,
    required this.reference,
    required this.date,
  });

  factory HostPayout.fromJson(Map<String, dynamic> j) => HostPayout(
    id: j['id'] as int? ?? 0,
    campaignTitle: j['campaignTitle'] as String? ?? '',
    amountCents: j['amountCents'] as int? ?? 0,
    disbursementFeeCents: j['disbursementFeeCents'] as int? ?? 0,
    platformFeeCents: j['platformFeeCents'] as int? ?? 0,
    status: j['status'] as String? ?? '',
    reference: j['reference'] as String?,
    date: j['date'] as String? ?? '',
  );
}

class HostData {
  final HostUser user;
  final List<Campaign> campaigns;
  final List<Transaction> transactions;
  final List<HostPayout> payouts;

  const HostData({
    required this.user,
    required this.campaigns,
    required this.transactions,
    required this.payouts,
  });

  factory HostData.fromJson(Map<String, dynamic> j) => HostData(
    user: HostUser.fromJson(j['user'] as Map<String, dynamic>? ?? {}),
    campaigns: (j['campaigns'] as List<dynamic>? ?? [])
        .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
        .toList(),
    transactions: (j['transactions'] as List<dynamic>? ?? [])
        .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
        .toList(),
    payouts: (j['payouts'] as List<dynamic>? ?? [])
        .map((p) => HostPayout.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}
