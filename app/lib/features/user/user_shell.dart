import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/message_model.dart';
import '../shared/chat_list_screen.dart';
import 'home_screen.dart';
import 'my_cases_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class UserShell extends ConsumerStatefulWidget {
  final int initialIndex;
  const UserShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> {
  late int _index = widget.initialIndex;

  static const _pages = [
    HomeScreen(),
    MyCasesScreen(),
    ChatListScreen(currentRole: SenderType.user),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(apiRepositoryProvider).unreadNotificationCount;
    final tabs = [
      const NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      const NavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Cases'),
      const NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat'),
      NavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'Alerts', badgeCount: unread),
      const NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: FlatBottomNav(
        items: tabs,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
