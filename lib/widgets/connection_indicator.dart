import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/theme.dart';

/// Connection status indicator widget
/// Shows when the app is offline
/// Follows SKILL.md guidelines for proper state management
class ConnectionIndicator extends StatefulWidget {
  final Widget child;

  const ConnectionIndicator({
    super.key,
    required this.child,
  });

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      // If we can't check connectivity, assume we're online
      if (mounted) {
        setState(() {
          _isOnline = true;
          _showBanner = false;
        });
      }
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (!mounted) return;

    // Check if any result indicates connectivity
    final isOnline = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);

    setState(() {
      // Only show banner if we're transitioning from online to offline
      if (_isOnline && !isOnline) {
        _showBanner = true;
      } else if (!_isOnline && isOnline) {
        // Auto-hide banner after 3 seconds when back online
        _showBanner = true;
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showBanner = false;
            });
          }
        });
      }
      _isOnline = isOnline;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _ConnectionBanner(
                isOnline: _isOnline,
                onDismiss: () {
                  setState(() {
                    _showBanner = false;
                  });
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Connection banner widget
class _ConnectionBanner extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onDismiss;

  const _ConnectionBanner({
    required this.isOnline,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isOnline ? AppTheme.success : AppTheme.error,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isOnline
                    ? 'Back online'
                    : 'No internet connection',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
