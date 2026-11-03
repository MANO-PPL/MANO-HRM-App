import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class AttendanceHeaderWidget extends StatefulWidget {
  final bool showTabBar;
  final TabController? tabController;
  final void Function(int)? onTabChanged;

  const AttendanceHeaderWidget({
    super.key,
    this.showTabBar = true,
    this.tabController,
    this.onTabChanged,
  });

  @override
  State<AttendanceHeaderWidget> createState() => _AttendanceHeaderWidgetState();
}

class _AttendanceHeaderWidgetState extends State<AttendanceHeaderWidget> with WidgetsBindingObserver {
  late DateTime _currentTime;
  Timer? _timer;

  String _address = 'Locating...';
  bool _isLoadingLoc = false;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTime = DateTime.now();
    _startClock();
    _fetchAndGeocodeLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchAndGeocodeLocation();
    }
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _fetchAndGeocodeLocation() async {
    if (_isLoadingLoc) return;
    setState(() {
      _isLoadingLoc = true;
      _address = 'Locating...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() {
          _address = 'Location Services Disabled';
          _isLoadingLoc = false;
        });
        context.showToast(
          "Location services are disabled.",
          isWarning: true,
          actionLabel: "ENABLE",
          onActionPressed: () async {
            await Geolocator.openLocationSettings();
          },
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          setState(() {
            _address = 'Location Access Denied';
            _isLoadingLoc = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _address = 'Location Access Denied';
          _isLoadingLoc = false;
        });
        context.showToast(
          "Location permission permanently denied.",
          isWarning: true,
          actionLabel: "SETTINGS",
          onActionPressed: () async {
            await openAppSettings();
          },
        );
        return;
      }

      Position? position;

      // 1. Try to get a fresh last known position first (under 15s age) for speed
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          final age = DateTime.now().difference(lastKnown.timestamp);
          if (age.inSeconds < 15) {
            position = lastKnown;
          }
        }
      } catch (_) {}

      // 2. Otherwise, request a new position with timeout fallback
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 4),
            ),
          );
        } catch (e) {
          debugPrint("Header location fetch failed/timed out: $e. Trying fallback...");
          try {
            position = await Geolocator.getLastKnownPosition();
          } catch (_) {}
          if (position == null) {
            try {
              position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 3),
                ),
              );
            } catch (_) {}
          }
        }
      }

      if (!mounted) return;
      if (position == null) {
        setState(() {
          _address = 'Could not acquire location';
          _isLoadingLoc = false;
        });
        return;
      }
      final pos = position;

      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}';

      try {
        final response = await _dio.get(
          url,
          options: Options(
            headers: {
              'User-Agent': 'Attendance-App/1.0 (madhavan200@gmail.com)',
            },
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );
        if (!mounted) return;

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>?;
          String? simplifiedAddress;

          if (addr != null) {
            simplifiedAddress = addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['city_district'] ??
                addr['city'] ??
                addr['town'] ??
                addr['village'];
          }

          simplifiedAddress ??= (data['display_name'] as String?)?.split(',').first;

          setState(() {
            _address = simplifiedAddress ?? 'Unknown Location';
            _isLoadingLoc = false;
          });
          return;
        }
      } catch (e) {
        debugPrint("Geocoding API failed or timed out: $e");
      }

      // Fallback: Show raw coordinates if Nominatim is unreachable or slow
      if (mounted) {
        setState(() {
          _address = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          _isLoadingLoc = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = 'Location Error';
          _isLoadingLoc = false;
        });
      }
    }
  }

  Widget _buildLocationPill(bool isDark) {
    return InkWell(
      onTap: _fetchAndGeocodeLocation,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x33232644) : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
              size: 14,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (_isLoadingLoc) ...[
              const SizedBox(width: 5),
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;
    final firstName = user?.name.split(' ').first ?? 'User';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final hour = _currentTime.hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    final dateStr = DateFormat('d MMMM yyyy').format(_currentTime);
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);

    final cardBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.12);
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.18);

    Widget tabBarWidget = AttendanceTabBar(
      maxWidth: 480,
      controller: widget.tabController,
      onTap: widget.onTabChanged,
    );

    if (isLandscape) {
      // Landscape Layout (side-by-side greeting & time card)
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 12, 16, widget.showTabBar ? 34 : 26),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF090A1A), const Color(0xFF05060A)]
                : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Column: Greeting & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$greeting, $firstName!',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: constrained glassy card
                    SizedBox(
                      width: 360,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderColor, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF232644) : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'CURRENT TIME',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      timeStr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LOCATION',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildLocationPill(isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.showTabBar) const SizedBox(height: 24),
              ],
            ),

            if (widget.showTabBar)
              Positioned(
                bottom: -20,
                left: 0,
                right: 0,
                child: Center(child: tabBarWidget),
              ),
          ],
        ),
      );
    } else if (isMobile) {
      // Mobile Portrait Layout - Made more compact for smaller mobile devices
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(12, 10, 12, widget.showTabBar ? 38 : 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF090A1A), const Color(0xFF05060A)]
                : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $firstName!',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                // Clock & Location Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorderColor, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF232644) : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'CURRENT TIME',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      timeStr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LOCATION',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildLocationPill(isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showTabBar) const SizedBox(height: 28),
              ],
            ),

            if (widget.showTabBar)
              Positioned(
                bottom: -24,
                left: 0,
                right: 0,
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: tabBarWidget),
                ),
              ),
          ],
        ),
      );
    } else {
      // Tablet Portrait Layout
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 14, 16, widget.showTabBar ? 34 : 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF090A1A), const Color(0xFF05060A)]
                : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $firstName!',
                  style: GoogleFonts.poppins(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                // Clock & Location Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorderColor, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF232644) : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'CURRENT TIME',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      timeStr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LOCATION',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildLocationPill(isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showTabBar) const SizedBox(height: 24),
              ],
            ),

            if (widget.showTabBar)
              Positioned(
                bottom: -20,
                left: 0,
                right: 0,
                child: Center(child: tabBarWidget),
              ),
          ],
        ),
      );
    }
  }
}

/// Reusable floating two-tab bar matching Attendance-Web
class AttendanceTabBar extends StatefulWidget {
  final double? maxWidth;
  final TabController? controller;
  final void Function(int)? onTap;

  const AttendanceTabBar({
    super.key,
    this.maxWidth,
    this.controller,
    this.onTap,
  });

  @override
  State<AttendanceTabBar> createState() => _AttendanceTabBarState();
}

class _AttendanceTabBarState extends State<AttendanceTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller?.animation?.addListener(_onAnimUpdate);
    widget.controller?.addListener(_onAnimUpdate);
  }

  @override
  void didUpdateWidget(AttendanceTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.animation?.removeListener(_onAnimUpdate);
      oldWidget.controller?.removeListener(_onAnimUpdate);
      widget.controller?.animation?.addListener(_onAnimUpdate);
      widget.controller?.addListener(_onAnimUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller?.animation?.removeListener(_onAnimUpdate);
    widget.controller?.removeListener(_onAnimUpdate);
    super.dispose();
  }

  void _onAnimUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = widget.controller;
    final double animValue = controller?.animation?.value ?? (controller?.index.toDouble() ?? 0.0);

    final activeColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    Widget bar = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF161B22).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              if (!isDark)
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;
              final pillLeft = (animValue * tabWidth).clamp(0.0, tabWidth);

              final t0 = (1.0 - animValue).clamp(0.0, 1.0);
              final t1 = (animValue - 0.0).clamp(0.0, 1.0);

              final color0 = Color.lerp(inactiveColor, activeColor, t0)!;
              final color1 = Color.lerp(inactiveColor, activeColor, t1)!;

              return Stack(
                children: [
                  // Sliding Active Indicator Pill
                  Positioned(
                    left: pillLeft,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF21262D) : Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF30363D)
                              : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab Buttons Row
                  Row(
                    children: [
                      // Tab 0: Attendance
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () {
                              if (controller != null && controller.index != 0) {
                                controller.animateTo(0);
                              }
                              widget.onTap?.call(0);
                            },
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 15,
                                    color: color0,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      "Attendance",
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: t0 > 0.5 ? FontWeight.w600 : FontWeight.w500,
                                        color: color0,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Tab 1: My Attendance
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () {
                              if (controller != null && controller.index != 1) {
                                controller.animateTo(1);
                              }
                              widget.onTap?.call(1);
                            },
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 15,
                                    color: color1,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      "My Attendance",
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: t1 > 0.5 ? FontWeight.w600 : FontWeight.w500,
                                        color: color1,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (widget.maxWidth != null) {
      return SizedBox(
        width: widget.maxWidth,
        child: bar,
      );
    }
    return bar;
  }
}

// [mod:2026-02-17T14:00:00+05:30]
