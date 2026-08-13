import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Live FX rates for USD <-> ZMW using the free open.er-api.com (no key).
/// Ported from the shared Lipila integration so any project wiring Lipila can
/// reuse the same live exchange-rate logic.
class FxService {
  static const String defaultBaseUrl = 'https://open.er-api.com/v6/latest';

  final String baseCurrency;
  final String targetCurrency;
  final String baseUrl;

  double _zmwPerTarget = 0;
  DateTime? _lastUpdated;
  double _fallbackRate = 18.0;

  FxService({
    this.baseCurrency = 'ZMW',
    this.targetCurrency = 'USD',
    this.baseUrl = defaultBaseUrl,
  });

  /// How many [baseCurrency] units equal 1 [targetCurrency] unit.  double get ratePerUnit => _zmwPerTarget;

  bool get isRateLoaded => _zmwPerTarget > 0;

  DateTime? get lastUpdated => _lastUpdated;

  void setFallbackRate(double rate) => _fallbackRate = rate;

  /// Fetch the live rate. Cached for 60 seconds (real-time-ish, polite to the
  /// free API). Returns a Future of unit-per-target. Falls back if offline.
  Future<double> fetchRate({bool force = false}) async {
    if (!force &&
        _zmwPerTarget > 0 &&
        _lastUpdated != null &&
        DateTime.now().difference(_lastUpdated!).inSeconds < 60) {
      return _zmwPerTarget;
    }
    try {
      final uri = Uri.parse('$baseUrl/$baseCurrency');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final targetPerBase =
            (data['rates']?[targetCurrency] as num?)?.toDouble() ?? 0;
        if (targetPerBase > 0) {
          _zmwPerTarget = 1 / targetPerBase; // ZMW per 1 USD
          _lastUpdated = DateTime.now();
          return _zmwPerTarget;
        }
      }
    } catch (e) {
      debugPrint('FxService: FX fetch error: $e');
    }
    if (_zmwPerTarget > 0) return _zmwPerTarget;
    return _fallbackRate;
  }

  /// Convert an amount in [baseCurrency] (ZMW) to [targetCurrency] (USD).
  double toTarget(double zmwAmount, double rate) => zmwAmount / rate;

  /// Convert a USD amount to ZMW.
  double fromTarget(double usdAmount, double rate) => usdAmount * rate;
}

final fxServiceProvider = Provider<FxService>((ref) => FxService());

/// Reactive provider that emits the live ZMW->USD rate (ZMW per 1 USD).
final zmwPerUsdProvider = FutureProvider<double>((ref) async {
  return ref.watch(fxServiceProvider).fetchRate();
});

/// Which currency the signed-in user prefers for displaying amounts.
enum CurrencyPref { zmw, usd }

class CurrencyController extends Notifier<CurrencyPref> {
  static const _key = 'currency_pref';

  CurrencyController([this._initial = CurrencyPref.zmw]);
  final CurrencyPref _initial;

  @override
  CurrencyPref build() => _initial;

  Future<void> set(CurrencyPref pref) async {
    state = pref;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pref.name);
  }

  static Future<CurrencyPref> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    return name == CurrencyPref.usd.name ? CurrencyPref.usd : CurrencyPref.zmw;
  }
}

final currencyPrefProvider =
    NotifierProvider<CurrencyController, CurrencyPref>(CurrencyController.new);

/// Formats cents in the preferred currency. When USD is selected the ZMW amount
/// is converted using the given live rate (falls back to ZMW if rate unknown).
String formatAmountCents(int cents, CurrencyPref pref, {double? rate}) {
  if (pref == CurrencyPref.usd && rate != null && rate > 0) {
    final usd = cents / 100 / rate;
    return '\$${usd.toStringAsFixed(2)}';
  }
  final k = cents / 100;
  final t = k.toStringAsFixed(2);
  final whole = t.endsWith('.00') ? k.toStringAsFixed(0) : t;
  return 'K$whole';
}
