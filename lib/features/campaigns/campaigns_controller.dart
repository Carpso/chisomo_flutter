import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/offline_cache.dart';
import 'models.dart';

class CampaignsController extends AsyncNotifier<List<Campaign>> {
  static const _cacheKey = 'campaigns_list';

  @override
  Future<List<Campaign>> build() async {
    final api = ref.read(apiClientProvider);
    final cache = ref.read(offlineCacheProvider);
    try {
      final res = await api.get('/api/campaigns');
      await cache.write(_cacheKey, res);
      ref.read(offlineModeProvider.notifier).set(false);
      return _parseCampaigns(res);
    } on ApiException {
      final cached = await cache.read(_cacheKey);
      if (cached == null) rethrow;
      ref.read(offlineModeProvider.notifier).set(true);
      return _parseCampaigns(cached);
    }
  }

  /// Parses the campaign list defensively so a single malformed row can never
  /// blank the whole home tab.
  static List<Campaign> _parseCampaigns(Map<String, dynamic> res) {
    return (res['campaigns'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((c) => Campaign.fromJson(Map<String, dynamic>.from(c)))
        .where((c) => c.id > 0)
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final campaignsProvider =
    AsyncNotifierProvider<CampaignsController, List<Campaign>>(CampaignsController.new);

class CampaignDetailController extends AsyncNotifier<CampaignDetail> {
  CampaignDetailController(this.campaignId);

  final int campaignId;

  @override
  Future<CampaignDetail> build() async {
    final api = ref.read(apiClientProvider);
    final cache = ref.read(offlineCacheProvider);
    final cacheKey = 'campaign_detail_$campaignId';
    try {
      final res = await api.get('/api/campaigns/$campaignId');
      await cache.write(cacheKey, res);
      // Record this as a view so a PRIVATE campaign opened via a shared invite
      // link stays findable under "Recently opened" (fire-and-forget).
      api.recordCampaignView(campaignId).then((_) {}, onError: (_) {});
      return CampaignDetail.fromJson(res);
    } on ApiException {
      final cached = await cache.read(cacheKey);
      if (cached == null) rethrow;
      ref.read(offlineModeProvider.notifier).set(true);
      return CampaignDetail.fromJson(cached);
    }
  }
}

final campaignDetailProvider = AsyncNotifierProvider
    .family<CampaignDetailController, CampaignDetail, int>(CampaignDetailController.new);

class HostController extends AsyncNotifier<HostData> {
  static const _cacheKey = 'host_me';

  @override
  Future<HostData> build() async {
    final api = ref.read(apiClientProvider);
    final cache = ref.read(offlineCacheProvider);
    try {
      final res = await api.get('/api/host/me', auth: true);
      await cache.write(_cacheKey, res);
      return HostData.fromJson(res);
    } on ApiException {
      final cached = await cache.read(_cacheKey);
      if (cached == null) rethrow;
      ref.read(offlineModeProvider.notifier).set(true);
      return HostData.fromJson(cached);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Map<String, dynamic>> createCampaign({
    required String title,
    required String description,
    required int goalCents,
    required int minWithdrawCents,
    DateTime? endsAt,
    String category = 'Other',
    String campaignType = 'community',
    bool isPrivate = false,
    bool waivePayoutFees = false,
    List<Map<String, dynamic>> eventTiers = const [],
    int eventCapacity = 0,
    String? eventDate,
    String? eventVenue,
  }) async {
    final res = await ref.read(apiClientProvider).post(
          '/api/campaigns',
          {
            'title': title,
            'description': description,
            'goalCents': goalCents,
            'minWithdrawCents': minWithdrawCents,
            'category': category,
            'campaignType': campaignType,
            'visibility': isPrivate ? 'private' : 'public',
            'waivePayoutFees': waivePayoutFees,
            if (eventTiers.isNotEmpty) 'eventTiers': eventTiers,
            if (eventCapacity > 0) 'eventCapacity': eventCapacity,
            if (eventDate != null) 'eventDate': eventDate,
            if (eventVenue != null && eventVenue.isNotEmpty) 'eventVenue': eventVenue,
            if (endsAt != null) 'endsAt': endsAt.toIso8601String().split('T')[0],
          },
          auth: true,
        );
    await refresh();
    return res;
  }

  Future<Map<String, dynamic>> updateCampaign(
    int campaignId,
    Map<String, dynamic> body,
  ) async {
    final res = await ref.read(apiClientProvider).updateCampaign(campaignId, body);
    await refresh();
    ref.invalidate(campaignsProvider);
    ref.invalidate(campaignDetailProvider(campaignId));
    return res;
  }

  Future<Map<String, dynamic>> withdraw(int campaignId) async {
    final res = await ref
        .read(apiClientProvider)
        .post('/api/campaigns/$campaignId/withdraw', {}, auth: true);
    await refresh();
    return res;
  }

  Future<Map<String, dynamic>> endCampaign(int campaignId) async {
    final res = await ref
        .read(apiClientProvider)
        .post('/api/campaigns/$campaignId/end', {}, auth: true);
    await refresh();
    return res;
  }

  Future<Map<String, dynamic>> applyAsHost({
    required String org,
    required String role,
    required String reason,
    String? orgType,
    String? kycType,
    String? kycDocUrl,
    String? kycNotes,
  }) async {
    final res = await ref.read(apiClientProvider).post(
          '/api/host/apply',
          {
            'org': org,
            'role': role,
            'reason': reason,
            if (orgType != null) 'orgType': orgType,
            if (kycType != null) 'kycType': kycType,
            if (kycDocUrl != null) 'kycDocUrl': kycDocUrl,
            if (kycNotes != null) 'kycNotes': kycNotes,
          },
          auth: true,
        );
    await refresh();
    return res;
  }
}

final hostProvider =
    AsyncNotifierProvider<HostController, HostData>(HostController.new);

class AdminController extends AsyncNotifier<AdminData> {
  @override
  Future<AdminData> build() async {
    final api = ref.read(apiClientProvider);
    final stats = await api.get('/api/admin/stats', auth: true);
    final apps = await api.get('/api/admin/applications', auth: true);
    final campaigns = await api.get('/api/admin/campaigns', auth: true);
    return AdminData.fromJson(stats, apps, campaigns);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Map<String, dynamic>> decideApplication(int id, {required bool approve, String? reason}) async {
    final res = await ref.read(apiClientProvider).post(
          '/api/admin/applications/$id/${approve ? 'approve' : 'reject'}',
          reason == null ? {} : {'reason': reason},
          auth: true,
        );
    await refresh();
    return res;
  }
}

final adminDataProvider =
    AsyncNotifierProvider<AdminController, AdminData>(AdminController.new);

class AdminLedger {
  final List<AdminTransaction> transactions;
  final List<Disbursement> disbursements;

  const AdminLedger({required this.transactions, required this.disbursements});
}

class AdminLedgerController extends AsyncNotifier<AdminLedger> {
  @override
  Future<AdminLedger> build() async {
    final api = ref.read(apiClientProvider);
    final txs = await api.getAdminTransactions();
    final disbs = await api.get('/api/admin/disbursements', auth: true);
    return AdminLedger(
      transactions: (txs['transactions'] as List<dynamic>? ?? [])
          .map((t) => AdminTransaction.fromJson(t as Map<String, dynamic>))
          .toList(),
      disbursements: (disbs['disbursements'] as List<dynamic>? ?? [])
          .map((d) => Disbursement.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Appends the next page of the transaction ledger (server caps at 1000).
  Future<void> loadMoreTransactions() async {
    final current = state.value;
    if (current == null) return;
    final res = await ref.read(apiClientProvider).getAdminTransactions(
          offset: current.transactions.length,
        );
    final more = (res['transactions'] as List<dynamic>? ?? [])
        .map((t) => AdminTransaction.fromJson(t as Map<String, dynamic>))
        .toList();
    if (more.isEmpty) return;
    state = AsyncValue.data(AdminLedger(
      transactions: [...current.transactions, ...more],
      disbursements: current.disbursements,
    ));
  }

  /// Fetches the full detail of a single transaction (admin ledger).
  Future<TransactionDetail> transactionDetail(int id) async {
    final res = await ref.read(apiClientProvider).get('/api/admin/transactions/$id', auth: true);
    return TransactionDetail.fromJson(res['transaction'] as Map<String, dynamic>? ?? {});
  }
}

final adminLedgerProvider =
    AsyncNotifierProvider<AdminLedgerController, AdminLedger>(AdminLedgerController.new);

class CampaignViewsController extends AsyncNotifier<List<Campaign>> {
  @override
  Future<List<Campaign>> build() async {
    final api = ref.read(apiClientProvider);
    final res = await api.getCampaignViews();
    return (res).map((c) => Campaign.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Campaigns the user has opened recently — including PRIVATE campaigns they
/// reached via a shared invite link, so those links never get lost.
final campaignViewsProvider =
    AsyncNotifierProvider<CampaignViewsController, List<Campaign>>(CampaignViewsController.new);

class UnreadNotificationsController extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final api = ref.read(apiClientProvider);
    try {
      return await api.getUnreadNotificationCount();
    } on ApiException {
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Unread in-app notification count shown as a badge on the bell icon.
final unreadNotificationsProvider =
    AsyncNotifierProvider<UnreadNotificationsController, int>(UnreadNotificationsController.new);

class PledgesController extends AsyncNotifier<List<Pledge>> {
  static const _cacheKey = 'pledges';

  @override
  Future<List<Pledge>> build() async {
    final api = ref.read(apiClientProvider);
    final cache = ref.read(offlineCacheProvider);
    try {
      final res = await api.get('/api/pledges', auth: true);
      await cache.write(_cacheKey, res);
      return (res['pledges'] as List<dynamic>? ?? [])
          .map((p) => Pledge.fromJson(p as Map<String, dynamic>))
          .toList();
    } on ApiException {
      final cached = await cache.read(_cacheKey);
      if (cached == null) rethrow;
      ref.read(offlineModeProvider.notifier).set(true);
      return (cached['pledges'] as List<dynamic>? ?? [])
          .map((p) => Pledge.fromJson(p as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Map<String, dynamic>> cancel(int campaignId) async {
    final res = await ref.read(apiClientProvider).cancelPledge(campaignId);
    await refresh();
    return res;
  }
}

final pledgesProvider =
    AsyncNotifierProvider<PledgesController, List<Pledge>>(PledgesController.new);

class PromotionInfoController extends AsyncNotifier<PromotionInfo> {
  @override
  Future<PromotionInfo> build() async {
    final res = await ref.read(apiClientProvider).getPromotionInfo();
    return PromotionInfo.fromJson(res);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final promotionInfoProvider =
    AsyncNotifierProvider<PromotionInfoController, PromotionInfo>(PromotionInfoController.new);

class AdminPromotionsController extends AsyncNotifier<List<AdminPromotion>> {
  @override
  Future<List<AdminPromotion>> build() async {
    final res = await ref.read(apiClientProvider).getAdminPromotions();
    return res.map((p) => AdminPromotion.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Map<String, dynamic>> decide(int id, {required bool approve}) async {
    final res = await ref.read(apiClientProvider).post(
          '/api/admin/promotions/$id/${approve ? 'approve' : 'reject'}',
          {},
          auth: true,
        );
    await refresh();
    ref.invalidate(campaignsProvider);
    return res;
  }
}

final promotionsProvider =
    AsyncNotifierProvider<AdminPromotionsController, List<AdminPromotion>>(AdminPromotionsController.new);

class MyPromotionsController extends AsyncNotifier<List<MyPromotion>> {
  @override
  Future<List<MyPromotion>> build() async {
    final res = await ref.read(apiClientProvider).get('/api/me/promotions', auth: true);
    return (res['promotions'] as List<dynamic>? ?? [])
        .map((p) => MyPromotion.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final myPromotionsProvider =
    AsyncNotifierProvider<MyPromotionsController, List<MyPromotion>>(MyPromotionsController.new);
