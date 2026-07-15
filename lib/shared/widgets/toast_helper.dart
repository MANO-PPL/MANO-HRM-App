import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/attendance/providers/attendance_provider.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import '../services/auth_service.dart';
import '../utils/error_helper.dart';

OverlayEntry? _currentToastEntry;

extension ToastExtension on BuildContext {
  void showExceptionToast(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    final message = friendlyError(error, fallback: fallback);
    showToast(
      message,
      isError: true,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  void showToast(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    if (!mounted) return;

    final displayMessage = isError ? sanitizeErrorMessage(message) : message;

    try {
      _currentToastEntry?.remove();
    } catch (_) {}
    _currentToastEntry = null;

    final isDark = Theme.of(this).brightness == Brightness.dark;

    Color bgColor;
    IconData icon;

    if (isError) {
      bgColor = const Color(0xFFDA3637);
      icon = Icons.error_outline;
    } else if (isWarning) {
      bgColor = const Color(0xFFD29922);
      icon = Icons.warning_amber_outlined;
    } else if (isSuccess) {
      bgColor = const Color(0xFF2EA043);
      icon = Icons.check_circle_outline;
    } else {
      bgColor = isDark ? const Color(0xFF21262D) : const Color(0xFF24292F);
      icon = Icons.info_outline;
    }

    final overlay = navigatorKey.currentState?.overlay ?? Overlay.of(this);
    
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return AnimatedToastWidget(
          message: displayMessage,
          icon: icon,
          bgColor: bgColor,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed,
          onDismissed: () {
            if (_currentToastEntry == entry) {
              try {
                entry.remove();
              } catch (_) {}
              _currentToastEntry = null;
            }
          },
        );
      },
    );

    _currentToastEntry = entry;
    overlay.insert(entry);
  }

  void showInAppNotification({
    required String title,
    required String body,
    required String type,
    VoidCallback? onTap,
  }) {
    if (!mounted) return;

    final overlay = navigatorKey.currentState?.overlay ?? Overlay.of(this);
    
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return InAppNotificationBanner(
          title: title,
          body: body,
          type: type,
          onTap: () {
            try {
              entry.remove();
            } catch (_) {}
            if (onTap != null) onTap();
          },
          onDismissed: () {
            try {
              entry.remove();
            } catch (_) {}
          },
        );
      },
    );

    overlay.insert(entry);
  }

  void checkAndShowShiftStartBanner() {
    if (!mounted) return;
    final attendanceProvider = Provider.of<AttendanceProvider>(this, listen: false);
    final todayRecords = attendanceProvider.records;
    final latestRecord = todayRecords.isNotEmpty ? todayRecords.last : null;
    final hasClockedIn = latestRecord != null && latestRecord.timeIn != null;

    if (!hasClockedIn) {
      final shift = attendanceProvider.shiftPolicy;
      final startStr = shift?.startTime ?? '09:00';
      try {
        final parts = startStr.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);

          final now = DateTime.now();
          final shiftStart = DateTime(now.year, now.month, now.day, hour, minute);

          // Check if current time is within [shiftStart - 15 mins, shiftStart + 15 mins]
          final windowStart = shiftStart.subtract(const Duration(minutes: 15));
          final windowEnd = shiftStart.add(const Duration(minutes: 15));

          if (now.isAfter(windowStart) && now.isBefore(windowEnd)) {
            showInAppNotification(
              title: 'Shift Starting Soon',
              body: 'Your shift starts at $startStr. Please remember to clock in!',
              type: 'warning',
              onTap: () {
                navigateTo(PageType.myAttendance);
              },
            );
          }
        }
      } catch (e) {
        debugPrint('Error checking shift start banner: $e');
      }
    }
  }
}

class AnimatedToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color bgColor;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final VoidCallback onDismissed;

  const AnimatedToastWidget({
    super.key,
    required this.message,
    required this.icon,
    required this.bgColor,
    this.actionLabel,
    this.onActionPressed,
    required this.onDismissed,
  });

  @override
  State<AnimatedToastWidget> createState() => _AnimatedToastWidgetState();
}

class _AnimatedToastWidgetState extends State<AnimatedToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    _dismissTimer = Timer(Duration(seconds: widget.actionLabel != null ? 5 : 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismissed();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;
    
    return Positioned(
      bottom: 24 + bottomInset + bottomPadding,
      left: 20,
      right: 20,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: widget.bgColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: widget.bgColor.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null && widget.onActionPressed != null) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        widget.onDismissed();
                        widget.onActionPressed!();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        widget.actionLabel!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String type;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const InAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(begin: -150.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismissed();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 12 + topPadding,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -10) {
                _controller.reverse().then((_) {
                  widget.onDismissed();
                });
              }
            },
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            isDark ? 'assets/app_icon_dark.png' : 'assets/app_icon_light.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B60F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'now',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFF374151),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

