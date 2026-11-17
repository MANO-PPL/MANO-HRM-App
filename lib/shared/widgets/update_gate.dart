import 'dart:async';
import 'package:flutter/material.dart';

import '../services/context_service.dart';
import '../services/update_policy.dart';
import 'force_update_dialog.dart';

/// Idempotent latch controller for the application update gate (R10).
class UpdateGateController extends ChangeNotifier {
  static final UpdateGateController instance = UpdateGateController._internal();

  UpdateGateController._internal();

  UpdatePolicyInfo? _blockingInfo;

  bool get isBlocked => _blockingInfo != null;
  UpdatePolicyInfo? get blockingInfo => _blockingInfo;

  /// Latches a blocking update requirement. Five concurrent 426s produce one gate (R10).
  void require(UpdatePolicyInfo info) {
    if (_blockingInfo != null) return; // Already latched
    _blockingInfo = info;
    notifyListeners();
  }

  /// Clears the update gate overlay if minAppVersion is relaxed / rolled back (R10).
  void clear() {
    if (_blockingInfo == null) return;
    _blockingInfo = null;
    notifyListeners();
  }
}

/// Root widget overlay placed in MaterialApp.builder (R10).
/// Paints above all Navigator routes without needing BuildContext in Dio interceptors.
class UpdateGate extends StatefulWidget {
  final Widget child;
  final ContextService? contextService;

  const UpdateGate({
    super.key,
    required this.child,
    this.contextService,
  });

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  final UpdateGateController _controller = UpdateGateController.instance;
  Timer? _rollbackPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _stopRollbackPoll();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.isBlocked) {
      _startRollbackPoll();
    } else {
      _stopRollbackPoll();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _controller.isBlocked) {
      _checkRollback();
    }
  }

  void _startRollbackPoll() {
    _rollbackPollTimer?.cancel();
    _rollbackPollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkRollback();
    });
  }

  void _stopRollbackPoll() {
    _rollbackPollTimer?.cancel();
    _rollbackPollTimer = null;
  }

  Future<void> _checkRollback() async {
    final cs = widget.contextService;
    if (cs == null) return;

    try {
      await cs.syncSystemContext();
      final currentClientVer = _controller.blockingInfo?.clientVersion ?? '0.0.0';
      final policy = UpdatePolicy.evaluate(
        system: cs.system,
        clientVersion: currentClientVer,
      );

      if (!policy.isBlocking) {
        debugPrint('[UpdateGate] Server relaxed minAppVersion, clearing update gate');
        _controller.clear();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final blockingInfo = _controller.blockingInfo;

    return Stack(
      children: [
        widget.child,
        if (blockingInfo != null)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: ForceUpdateDialog(info: blockingInfo),
              ),
            ),
          ),
      ],
    );
  }
}
