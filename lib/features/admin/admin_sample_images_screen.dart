import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin: upload sample poster images that hosts and event creators can reuse
/// on the create screens (shown alongside the bundled samples).
class AdminSampleImagesScreen extends ConsumerStatefulWidget {
  const AdminSampleImagesScreen({super.key});

  @override
  ConsumerState<AdminSampleImagesScreen> createState() => _AdminSampleImagesScreenState();
}

class _AdminSampleImagesScreenState extends ConsumerState<AdminSampleImagesScreen> {
  List<String> _images = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final images = await ref.read(apiClientProvider).getAdminSampleImages();
      if (mounted) setState(() { _images = images; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load sample images.'; _loading = false; });
    }
  }

  Future<void> _upload() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 3 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be under 3 MB.')));
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      final res = await ref.read(apiClientProvider).uploadSampleImage(bytes, picked.name);
      if (mounted) {
        setState(() => _images = (res['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample image added')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove sample image?'),
        content: const Text('Hosts and event creators will no longer see this in the sample picker.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteSampleImage(url);
      if (mounted) setState(() => _images.remove(url));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample images'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(LucideIcons.refreshCw, size: 18)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(LucideIcons.plus),
        label: const Text('Upload image'),
      ),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: _images.length + (_images.isEmpty ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_images.isEmpty) {
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.image, size: 32, color: AppColors.textMuted),
                              SizedBox(height: 8),
                              Text('No uploaded samples yet.\nTap Upload image to add one.',
                                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }
                    final url = _images[i];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.surface, child: const Icon(LucideIcons.image, color: AppColors.textMuted))),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Remove',
                            style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.55)),
                            icon: const Icon(LucideIcons.x, size: 15, color: Colors.white),
                            onPressed: () => _remove(url),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
