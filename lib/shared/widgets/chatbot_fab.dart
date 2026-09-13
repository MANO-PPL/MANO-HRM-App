import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/chatbot_service.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/shared/widgets/chatbot_sheet.dart';

class ChatbotFab extends StatefulWidget {
  final PageType currentPageType;

  const ChatbotFab({super.key, required this.currentPageType});

  @override
  State<ChatbotFab> createState() => _ChatbotFabState();
}

class _ChatbotFabState extends State<ChatbotFab> {
  OverlayState? _lastOverlayState;

  void _updateOverlay() {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    if (!authService.isAuthenticated || authService.user == null) {
      ChatbotOverlayManager.destroyAll();
      return;
    }

    final overlayState = Overlay.of(context);
    if (ChatbotOverlayManager.isWindowOpen) {
      if (ChatbotOverlayManager.isFabOpen) {
        ChatbotOverlayManager.hideFab();
      }
      return;
    }

    if (_lastOverlayState != overlayState || !ChatbotOverlayManager.isFabOpen) {
      _lastOverlayState = overlayState;
      ChatbotOverlayManager.showFab(context, widget.currentPageType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatbotService = context.watch<ChatbotService>();
    if (!chatbotService.isChatbotEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ChatbotOverlayManager.destroyAll();
      });
      return const SizedBox.shrink();
    }

    final authService = context.watch<AuthService>();
    if (!authService.isAuthenticated || authService.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ChatbotOverlayManager.destroyAll();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateOverlay();
      });
    }

    return const SizedBox.shrink(); // overlays handle representation, so return empty
  }
}

class ChatbotDraggableFab extends StatefulWidget {
  const ChatbotDraggableFab({super.key});

  @override
  State<ChatbotDraggableFab> createState() => _ChatbotDraggableFabState();
}

class _ChatbotDraggableFabState extends State<ChatbotDraggableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late ChatbotService _chatbotService;

  double _right = 0;
  double _bottom = 0;
  bool _isPositionInitialized = false;

  final double _fabSize = 56.0;

  @override
  void initState() {
    super.initState();
    _chatbotService = context.read<ChatbotService>();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 4.0, end: 14.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePosition();
    });
  }

  void _initializePosition() {
    if (!mounted) return;
    final screenSize = MediaQuery.of(context).size;
    final cachedPos = _chatbotService.fabPosition;

    setState(() {
      if (cachedPos != null) {
        _right = cachedPos.dx.clamp(8.0, screenSize.width - _fabSize - 8.0);
        _bottom = cachedPos.dy.clamp(8.0, screenSize.height - _fabSize - 8.0);
      } else {
        // Default position: bottom right
        _right = 20.0;
        _bottom = 100.0;
        _chatbotService.fabPosition = Offset(_right, _bottom);
      }
      _isPositionInitialized = true;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPositionInitialized) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      right: _right,
      bottom: _bottom,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _right -= details.delta.dx;
            _bottom -= details.delta.dy;
            _right = _right.clamp(8.0, screenSize.width - _fabSize - 8.0);
            _bottom = _bottom.clamp(8.0, screenSize.height - _fabSize - 8.0);
          });
        },
        onPanEnd: (_) {
          _chatbotService.fabPosition = Offset(_right, _bottom);
        },
        onTap: () {
          ChatbotOverlayManager.toggleWindow(context, navigationNotifier.value);
        },
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: _pulseAnimation.value,
                      spreadRadius: _pulseAnimation.value * 0.25,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              width: _fabSize,
              height: _fabSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A custom [FloatingActionButtonLocation] that dynamically shifts the Chatbot FAB up
/// by 76px only on pages that contain their own standard '+' Floating Action Button
/// to avoid visual overlaps.
class ChatbotFabLocation extends FloatingActionButtonLocation {
  final PageType pageType;
  const ChatbotFabLocation(this.pageType);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset standardOffset = FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    final hasExistingFab = pageType == PageType.employees ||
        pageType == PageType.leavesAndHolidays ||
        pageType == PageType.policies ||
        pageType == PageType.policyEngine ||
        pageType == PageType.dailyActivity;
        
    if (hasExistingFab) {
      return Offset(standardOffset.dx, standardOffset.dy - 76);
    }
    if (pageType == PageType.collaboration) {
      return Offset(standardOffset.dx, standardOffset.dy - 96);
    }
    return standardOffset;
  }
}

/// A dynamic custom [FloatingActionButtonLocation] that listens to a [ValueNotifier<PageType>]
/// to dynamically shift the Chatbot FAB up by 76px only on pages with standard action FABs.
class DynamicChatbotFabLocation extends FloatingActionButtonLocation {
  final ValueNotifier<PageType> navigationNotifier;
  const DynamicChatbotFabLocation(this.navigationNotifier);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset standardOffset = FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    final pageType = navigationNotifier.value;
    final hasExistingFab = pageType == PageType.employees ||
        pageType == PageType.leavesAndHolidays ||
        pageType == PageType.policies ||
        pageType == PageType.policyEngine ||
        pageType == PageType.dailyActivity;
        
    if (hasExistingFab) {
      return Offset(standardOffset.dx, standardOffset.dy - 76);
    }
    if (pageType == PageType.collaboration) {
      return Offset(standardOffset.dx, standardOffset.dy - 96);
    }
    return standardOffset;
  }
}

/// Global manager for the draggable chatbot overlay window.
class ChatbotOverlayManager {
  static OverlayEntry? _fabEntry;
  static OverlayEntry? _windowEntry;

  static bool get isWindowOpen => _windowEntry != null;
  static bool get isFabOpen => _fabEntry != null;

  static void showFab(BuildContext context, PageType pageType) {
    if (_fabEntry != null) {
      _fabEntry!.remove();
      _fabEntry = null;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.user == null) {
      return;
    }

    final chatbotService = Provider.of<ChatbotService>(context, listen: false);
    if (!chatbotService.isChatbotEnabled) {
      return;
    }

    _fabEntry = OverlayEntry(
      builder: (overlayContext) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatbotService>.value(value: chatbotService),
            ChangeNotifierProvider<AuthService>.value(value: authService),
          ],
          child: const ChatbotDraggableFab(),
        );
      },
    );

    Overlay.of(context).insert(_fabEntry!);
  }

  static void hideFab() {
    _fabEntry?.remove();
    _fabEntry = null;
  }

  static void toggleWindow(BuildContext context, PageType pageType) {
    if (_windowEntry != null) {
      hideWindow(context, pageType);
    } else {
      showWindow(context, pageType);
    }
  }

  static void showWindow(BuildContext context, PageType pageType) {
    if (_windowEntry != null) return;

    hideFab();

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.user == null) {
      return;
    }

    final chatbotService = Provider.of<ChatbotService>(context, listen: false);

    _windowEntry = OverlayEntry(
      builder: (overlayContext) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatbotService>.value(value: chatbotService),
            ChangeNotifierProvider<AuthService>.value(value: authService),
          ],
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  hideWindow(context, pageType);
                },
                child: const SizedBox.expand(),
              ),
              ChatbotSheet(
                currentPageType: pageType,
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_windowEntry!);
  }

  static void hideWindow(BuildContext context, PageType pageType) {
    if (_windowEntry != null) {
      _windowEntry!.remove();
      _windowEntry = null;
    }
    showFab(context, pageType);
  }

  static void destroyAll() {
    try {
      if (_windowEntry != null) {
        _windowEntry!.remove();
        _windowEntry = null;
      }
    } catch (_) {}
    try {
      hideFab();
    } catch (_) {}
  }
}

// [upd:2026-04-29T09:00:00+05:30]

// [upd:2026-05-08T14:00:00+05:30]
