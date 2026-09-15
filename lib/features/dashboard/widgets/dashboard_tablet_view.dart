import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/dashboard/widgets/admin_dashboard_tablet_view.dart';
import 'package:flutter_application/features/dashboard/widgets/employee_dashboard_tablet_view.dart';
import 'package:flutter_application/features/dashboard/widgets/hr_dashboard_tablet_view.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch AuthService to react to role changes or initial load
    final authService = context.watch<AuthService>();
    final user = authService.user;
    
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (user.isEmployee) {
      return const EmployeeDashboardView();
    }

    if (user.isHr) {
      return const HrDashboardView();
    }

    // Default to Admin view
    return const AdminDashboardView();
  }
}

// [mod:2026-02-22T17:00:00+05:30]

// [upd:2026-05-03T11:30:00+05:30]
