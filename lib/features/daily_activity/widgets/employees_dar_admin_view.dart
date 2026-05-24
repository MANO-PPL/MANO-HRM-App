import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/layout/responsive_layout.dart';
import '../../../shared/services/auth_service.dart';
import './dar_admin/dar_admin_controller.dart';
import './dar_admin/dar_admin_mobile_view.dart';
import './dar_admin/dar_admin_tablet_portrait_view.dart';
import './dar_admin/dar_admin_tablet_landscape_view.dart';

/// Thin shell that wires the [DarAdminController] into the widget tree and
/// delegates rendering to the correct responsive layout variant.
class EmployeesDarAdminView extends StatefulWidget {
  const EmployeesDarAdminView({super.key});

  @override
  State<EmployeesDarAdminView> createState() =>
      _EmployeesDarAdminViewState();
}

class _EmployeesDarAdminViewState
    extends State<EmployeesDarAdminView> {
  late DarAdminController _ctrl;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _ctrl = DarAdminController(auth);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DarAdminController>.value(
      value: _ctrl,
      child: const ResponsiveLayout(
        mobile: DarAdminMobileView(),
        tabletPortrait: DarAdminTabletPortraitView(),
        tabletLandscape: DarAdminTabletLandscapeView(),
      ),
    );
  }
}
