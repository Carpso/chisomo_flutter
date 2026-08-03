import '../../core/money.dart';

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
  });

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: j['id'] as int,
        slug: j['slug'] as String,
        title: j['title'] as String,
        description: j['description'] as String? ?? '',
        imageUrl: j['imageUrl'] as String?,
        logoUrl: j['logoUrl'] as String?,
        goalCents: j['goalCents'] as int? ?? 0,
        hasGoal: j['hasGoal'] as bool? ?? ((j['goalCents'] as int? ?? 0) > 0),
        raisedCents: j['raisedCents'] as int? ?? 0,
        withdrawnCents: j['withdrawnCents'] as int? ?? 0,
        donorCount: j['donorCount'] as int? ?? 0,
        avgDonationCents: j['avgDonationCents'] as int? ?? 0,
        donorsNeededAtAvg: j['donorsNeededAtAvg'] as int?,
        dailyRateCents: j['dailyRateCents'] as int? ?? 0,
        estimatedEndDate: j['estimatedEndDate'] as String?,
        endsAt: j['endsAt'] as String?,
        status: j['status'] as String? ?? 'active',
        availableCents: j['availableCents'] as int?,
        minWithdrawCents: j['minWithdrawCents'] as int?,
        promoted: j['promoted'] as bool? ?? false,
        promotedUntil: j['promotedUntil'] as String?,
        createdAt: j['createdAt'] as String? ?? '',
      );

  double get progress => goalCents <= 0 ? 0 : (raisedCents / goalCents).clamp(0.0, 1.0);

  String get raisedLabel => formatKwacha(raisedCents);

  String get goalLabel => formatKwacha(goalCents);

  String get availableLabel =>
      availableCents == null ? '' : formatKwacha(availableCents!);
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
        promotedIds: (j['promotedIds'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
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

class Donor {
  final String username;
  final String? name;
  final bool isAnonymous;
  final int? amountCents;
  final String? tier;
  final String date;

  const Donor({
    required this.username,
    required this.name,
    required this.isAnonymous,
    required this.amountCents,
    required this.tier,
    required this.date,
  });

  factory Donor.fromJson(Map<String, dynamic> j) => Donor(
        username: j['username'] as String? ?? 'Giver',
        name: j['name'] as String?,
        isAnonymous: j['isAnonymous'] as bool? ?? false,
        amountCents: j['amountCents'] as int?,
        tier: j['tier'] as String?,
        date: j['date'] as String? ?? '',
      );

  String get displayName => name ?? username;

  bool get amountHidden => amountCents == null;
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
  final double momoPct;
  final double totalPct;
  final double disbursementPct;

  const FeesInfo({
    required this.platformPct,
    required this.platformMinFeeCents,
    required this.momoPct,
    required this.totalPct,
    required this.disbursementPct,
  });

  factory FeesInfo.fromJson(Map<String, dynamic> j) => FeesInfo(
        platformPct: (j['platformPct'] as num? ?? 1).toDouble(),
        platformMinFeeCents: j['platformMinFeeCents'] as int? ?? 300,
        momoPct: (j['momoPct'] as num? ?? 2.5).toDouble(),
        totalPct: (j['totalPct'] as num? ?? 3.5).toDouble(),
        disbursementPct: (j['disbursementPct'] as num? ?? 1.5).toDouble(),
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
  final String campaignTitle;
  final String name;
  final String phone;
  final int amountCents;
  final int platformFeeCents;
  final int lipilaFeeCents;
  final String status;
  final String date;

  const Transaction({
    required this.id,
    required this.campaignTitle,
    required this.name,
    required this.phone,
    required this.amountCents,
    required this.platformFeeCents,
    required this.lipilaFeeCents,
    required this.status,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as int,
        campaignTitle: j['campaignTitle'] as String? ?? '',
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        amountCents: j['amountCents'] as int? ?? 0,
        platformFeeCents: j['platformFeeCents'] as int? ?? 0,
        lipilaFeeCents: j['lipilaFeeCents'] as int? ?? 0,
        status: j['status'] as String? ?? '',
        date: j['date'] as String? ?? '',
      );
}

class HostUser {
  final int id;
  final String phone;
  final String username;
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
  final int confirmedDonations;
  final int donors;
  final int platformFeesCents;
  final int activeCampaigns;
  final int pendingApplications;
  final int dailyRateCents;

  const AdminStats({
    required this.totalRaisedCents,
    required this.confirmedDonations,
    required this.donors,
    required this.platformFeesCents,
    required this.activeCampaigns,
    required this.pendingApplications,
    required this.dailyRateCents,
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        totalRaisedCents: j['totalRaisedCents'] as int? ?? 0,
        confirmedDonations: j['confirmedDonations'] as int? ?? 0,
        donors: j['donors'] as int? ?? 0,
        platformFeesCents: j['platformFeesCents'] as int? ?? 0,
        activeCampaigns: j['activeCampaigns'] as int? ?? 0,
        pendingApplications: j['pendingApplications'] as int? ?? 0,
        dailyRateCents: j['dailyRateCents'] as int? ?? 0,
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

class Disbursement {
  final String kind; // payout | sweep
  final String id;
  final int? campaignId;
  final String campaignTitle;
  final int amountCents;
  final int lipilaFeeCents;
  final int platformFeeCents;
  final String? lipilaReference;
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

class AdminData {
  final AdminStats stats;
  final List<HostApplication> applications;
  final List<Campaign> topCampaigns;
  final List<LeaderboardEntry> topDonors;
  final List<AdminRecent> recent;
  final List<Campaign> allCampaigns;

  const AdminData({
    required this.stats,
    required this.applications,
    required this.topCampaigns,
    required this.topDonors,
    required this.recent,
    required this.allCampaigns,
  });

  factory AdminData.fromJson(Map<String, dynamic> statsJson, Map<String, dynamic> appsJson, Map<String, dynamic> campaignsJson) =>
      AdminData(
        stats: AdminStats.fromJson(statsJson['stats'] as Map<String, dynamic>? ?? {}),
        applications: (appsJson['applications'] as List<dynamic>? ?? [])
            .map((a) => HostApplication.fromJson(a as Map<String, dynamic>))
            .toList(),
        topCampaigns: (statsJson['topCampaigns'] as List<dynamic>? ?? [])
            .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
            .toList(),
        topDonors: (statsJson['topDonors'] as List<dynamic>? ?? [])
            .map((d) => LeaderboardEntry.fromJson(d as Map<String, dynamic>))
            .toList(),
        recent: (statsJson['recent'] as List<dynamic>? ?? [])
            .map((r) => AdminRecent.fromJson(r as Map<String, dynamic>))
            .toList(),
        allCampaigns: (campaignsJson['campaigns'] as List<dynamic>? ?? [])
            .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class HostData {
  final HostUser user;
  final List<Campaign> campaigns;
  final List<Transaction> transactions;

  const HostData({required this.user, required this.campaigns, required this.transactions});

  factory HostData.fromJson(Map<String, dynamic> j) => HostData(
        user: HostUser.fromJson(j['user'] as Map<String, dynamic>? ?? {}),
        campaigns: (j['campaigns'] as List<dynamic>? ?? [])
            .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
            .toList(),
        transactions: (j['transactions'] as List<dynamic>? ?? [])
            .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
