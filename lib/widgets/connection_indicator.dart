import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage_mode.dart';
import '../core/theme.dart';

/// Wraps [child] with a slim offline/online banner.
///
/// Only cloud-mode users depend on connectivity for their data — local mode
/// never calls the network for domain data — so this is a complete no-op
/// (no `Connectivity` listener, no banner) when [storageModeProvider] is
/// [StorageMode.local].
class ConnectionIndicator extends ConsumerStatefulWidget {
  const ConnectionIndicator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends ConsumerState<ConnectionIndicator> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(storageModeProvider) == StorageMode.cloud) {
      _startListening();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    if (_subscription != null) return;
    _connectivity.checkConnectivity().then(_updateConnectionStatus);
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    if (mounted) setState(() => _showBanner = false);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    final isOnline = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );

    setState(() {
      if (_isOnline && !isOnline) {
        _showBanner = true;
      } else if (!_isOnline && isOnline) {
        _showBanner = true;
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showBanner = false);
        });
      }
      _isOnline = isOnline;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StorageMode>(storageModeProvider, (previous, next) {
      if (next == StorageMode.cloud) {
        _startListening();
      } else {
        _stopListening();
      }
    });
    final mode = ref.watch(storageModeProvider);

    return Stack(
      children: [
        widget.child,
        if (mode == StorageMode.cloud && _showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _ConnectionBanner(
                isOnline: _isOnline,
                onDismiss: () => setState(() => _showBanner = false),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.isOnline, required this.onDismiss});

  final bool isOnline;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final tone = isOnline ? appColors.success : colorScheme.error;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: tone,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isOnline ? 'Back online' : 'No internet connection',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: tone, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
