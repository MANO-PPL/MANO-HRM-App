import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../shared/layout/responsive_layout.dart';
import '../../shared/services/auth_service.dart';
import 'tablet/views/daily_activity_view.dart';
import 'mobile/views/daily_activity_view.dart';
import 'widgets/employees_dar_admin_view.dart';

class DailyActivityScreen extends StatelessWidget {
  const DailyActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final isAdmin = auth.user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final myDarView = const ResponsiveLayout(
      mobile: MobileDailyActivityView(),
      tabletPortrait: TabletDailyActivityView(isLandscape: false),
      tabletLandscape: TabletDailyActivityView(isLandscape: true),
    );

    if (!isAdmin) {
      return myDarView;
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Pill Styled Tab Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!,
                ),
              ),
              child: TabBar(
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF2D3139) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                dividerColor: Colors.transparent,
                labelColor: isDark ? Colors.white : const Color(0xFF5B60F6),
                unselectedLabelColor: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.person_outline, size: 16),
                          SizedBox(width: 8),
                          Text("My DAR"),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.people_outline, size: 16),
                          SizedBox(width: 8),
                          Text("Employees' DAR"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Expanded Views Content
            Expanded(
              child: TabBarView(
                children: [
                  myDarView,
                  const EmployeesDarAdminView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
