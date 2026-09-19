import 'package:flutter/material.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../data/models/message_model.dart';
import '../shared/chat_list_screen.dart';
import 'doctor_appointments_screen.dart';
import 'doctor_cases_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'doctor_profile_screen.dart';

const _tabs = [
  NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
  NavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Cases'),
  NavItem(icon: Icons.event_outlined, activeIcon: Icons.event_rounded, label: 'Appointments'),
  NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat'),
  NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
];

class DoctorShell extends StatefulWidget {
  final int initialIndex;
  const DoctorShell({super.key, this.initialIndex = 0});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  late int _index = widget.initialIndex;

  static const _pages = [
    DoctorDashboardScreen(),
    DoctorCasesScreen(),
    DoctorAppointmentsScreen(),
    ChatListScreen(currentRole: SenderType.doctor),
    DoctorProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: FlatBottomNav(items: _tabs, currentIndex: _index, onTap: (i) => setState(() => _index = i)),
    );
  }
}
