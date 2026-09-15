import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/holidays/core/holiday_service.dart';
import 'package:flutter_application/features/holidays/widgets/holidays_tab_view.dart';

class HolidaysView extends StatelessWidget {
  const HolidaysView({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final holidayService = HolidayService(authService.dio);

    return HolidaysTabView(holidayService: holidayService);
  }
}
