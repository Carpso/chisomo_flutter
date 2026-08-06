import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api_client.dart';

/// Per-contribution receipt download state so the UI can toggle between
/// "Download receipt" and "Open receipt" and show in-flight spinners.
class ReceiptState {
  final bool isLoading;
  final bool isDownloaded;
  final bool isOpening;
  final String? error;

  const ReceiptState({
    this.isLoading = false,
    this.isDownloaded = false,
    this.isOpening = false,
    this.error,
  });

  ReceiptState copyWith({
    bool? isLoading,
    bool? isDownloaded,
    bool? isOpening,
    String? error,
  }) {
    return ReceiptState(
      isLoading: isLoading ?? this.isLoading,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isOpening: isOpening ?? this.isOpening,
      error: error ?? this.error,
    );
  }
}

/// Local folder + filename used for downloaded receipt PDFs.
Future<String> receiptFilePath(int contributionId) async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/receipt_$contributionId.pdf';
}

class ReceiptController extends Notifier<Map<int, ReceiptState>> {
  @override
  Map<int, ReceiptState> build() => const {};

  ReceiptState stateFor(int contributionId) =>
      state[contributionId] ?? const ReceiptState();

  Future<bool> isDownloaded(int contributionId) async {
    return File(await receiptFilePath(contributionId)).existsSync();
  }

  void _patch(int contributionId, ReceiptState next) {
    state = {...state, contributionId: next};
  }

  /// Downloads the receipt PDF into the app documents folder.
  /// Returns the local path on success or null on failure.
  Future<String?> download(WidgetRef ref, int contributionId) async {
    if (stateFor(contributionId).isLoading) return null;
    _patch(
      contributionId,
      stateFor(contributionId).copyWith(isLoading: true, error: null),
    );
    try {
      final api = ref.read(apiClientProvider);
      final token = api.token;
      if (token == null) throw Exception('Not signed in');
      final response = await http.get(
        Uri.parse(api.receiptUrl(contributionId)),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      final file = File(await receiptFilePath(contributionId));
      await file.writeAsBytes(response.bodyBytes);
      _patch(
        contributionId,
        stateFor(contributionId).copyWith(isLoading: false, isDownloaded: true),
      );
      return file.path;
    } catch (e) {
      _patch(
        contributionId,
        stateFor(
          contributionId,
        ).copyWith(isLoading: false, error: e.toString()),
      );
      return null;
    }
  }

  /// Opens the downloaded PDF with the device's PDF viewer.
  Future<bool> open(int contributionId) async {
    _patch(contributionId, stateFor(contributionId).copyWith(isOpening: true));
    try {
      final file = File(await receiptFilePath(contributionId));
      if (!file.existsSync()) return false;
      final result = await OpenFile.open(file.path);
      return result.type == ResultType.done;
    } finally {
      _patch(
        contributionId,
        stateFor(contributionId).copyWith(isOpening: false),
      );
    }
  }

  /// First tap downloads the PDF (and offers a "View" action), later taps
  /// open the already-downloaded PDF directly.
  Future<void> downloadThenView(
    BuildContext context,
    WidgetRef ref,
    int contributionId,
  ) async {
    if (stateFor(contributionId).isLoading) return;
    if (await isDownloaded(contributionId)) {
      await open(contributionId);
      return;
    }
    final path = await download(ref, contributionId);
    if (path == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Receipt downloaded'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => open(contributionId),
        ),
      ),
    );
  }
}

final receiptControllerProvider =
    NotifierProvider<ReceiptController, Map<int, ReceiptState>>(
      ReceiptController.new,
    );
