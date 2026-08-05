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
      return (res['campaigns'] as List<dynamic>? ?? [])
          .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
          .toList();
    } on ApiException {
      final cached = await cache.read(_cacheKey);
      if (cached == null) rethrow;
      ref.read(offlineModeProvider.notifier).set(true);
      return (cached['campaigns'] as List<dynamic>? ?? [])
          .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
          .toList();
    }
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
  }) async {
    final res = await ref.read(apiClientProvider).post(
          '/api/campaigns',
          {
            'title': title,
            'description': description,
            'goalCents': goalCents,
            'minWithdrawCents': minWithdrawCents,
            if (endsAt != null) 'endsAt': endsAt.toIso8601String().split('T')[0],
          },
          auth: true,
        );
    await refresh();
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
  }) async {
    final res = await ref.read(apiClientProvider).post(
          '/api/host/apply',
          {'org': org, 'role': role, 'reason': reason},
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
    final txs = await api.get('/api/admin/transactions', auth: true);
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

  /// Fetches the full detail of a single transaction (admin ledger).
  Future<TransactionDetail> transactionDetail(int id) async {
    final res = await ref.read(apiClientProvider).get('/api/admin/transactions/$id', auth: true);
    return TransactionDetail.fromJson(res['transaction'] as Map<String, dynamic>? ?? {});
  }
}

final adminLedgerProvider =
    AsyncNotifierProvider<AdminLedgerController, AdminLedger>(AdminLedgerController.new);

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
