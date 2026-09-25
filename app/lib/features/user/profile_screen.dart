import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/session/session_controller.dart';
import '../../core/widgets/app_avatar.dart';
import '../../data/models/case_model.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    final user = repo.currentUser;
    final solved = repo.cases.where((c) => c.status == CaseStatus.solved || c.status == CaseStatus.closed).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(child: Text('My Profile', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppColors.textLight),
                onPressed: () => _editProfileSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(initials: user.name[0], seed: user.avatarSeed, size: 84, imageUrl: user.avatarUrl),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: InkWell(
                        onTap: () => _changeAvatar(context, ref),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 3),
                Text(user.email, style: const TextStyle(color: AppColors.textLight, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Total Cases', value: '${repo.cases.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Solved Cases', value: '$solved')),
            ],
          ),
          const SizedBox(height: 22),
          _ProfileTile(icon: Icons.person_outline_rounded, label: 'Personal Information', onTap: () => _editProfileSheet(context, ref)),
          _ProfileTile(icon: Icons.folder_outlined, label: 'My Cases', onTap: () => context.push('/cases')),
          _ProfileTile(icon: Icons.calendar_today_outlined, label: 'Appointments', onTap: () => context.push('/appointments')),
          _ProfileTile(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => context.push('/notifications')),
          _ProfileTile(icon: Icons.support_agent_rounded, label: 'Help & Support', onTap: () => context.push('/tickets')),
          const SizedBox(height: 18),
          const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 6),
          const _NotificationToggleTile(),
          _ProfileTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy',
            onTap: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Privacy'),
                content: const SingleChildScrollView(
                  child: Text(
                    'SkinCare only uses your case details, photos, and messages to connect you with a '
                    'dermatologist and provide consultation. Your information is shared only with the doctor '
                    'assigned to your case and the SkinCare admin team, and is never sold to third parties. '
                    'You can request deletion of your account and data at any time by contacting support.',
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ProfileTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: AppColors.error,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(appSessionProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(apiRepositoryProvider);
      final url = await repo.uploadFile(picked);
      await repo.updateProfile(avatar: url);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  void _editProfileSheet(BuildContext context, WidgetRef ref) {
    final repo = ref.read(apiRepositoryProvider);
    final nameController = TextEditingController(text: repo.currentUser.name);
    final emailController = TextEditingController(text: repo.currentUser.email);
    final ageController = TextEditingController(text: repo.currentUser.age?.toString() ?? '');
    String? gender = repo.currentUser.gender;
    bool saving = false;
    const genders = ['Male', 'Female', 'Other'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Profile', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
                const SizedBox(height: 12),
                const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: genders.map((g) {
                    final selected = gender == g;
                    return ChoiceChip(
                      label: Text(g),
                      selected: selected,
                      onSelected: (_) => setSheetState(() => gender = g),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              await repo.updateProfile(
                                name: nameController.text.trim(),
                                email: emailController.text.trim(),
                                gender: gender,
                                age: int.tryParse(ageController.text.trim()),
                              );
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                            } catch (e) {
                              setSheetState(() => saving = false);
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
                              }
                            }
                          },
                    child: Text(saving ? 'Saving…' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ProfileTile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppColors.textDark, size: 21),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: color ?? AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 13.5))),
            if (color == null) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Local on/off preference for notifications - no real push provider (Firebase)
/// is wired up yet, so this only controls whether in-app notifications are
/// shown; it's persisted so the choice survives app restarts.
class _NotificationToggleTile extends StatefulWidget {
  const _NotificationToggleTile();

  @override
  State<_NotificationToggleTile> createState() => _NotificationToggleTileState();
}

class _NotificationToggleTileState extends State<_NotificationToggleTile> {
  static const _prefKey = 'notifications_enabled';
  bool _enabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool(_prefKey) ?? true;
      _loaded = true;
    });
  }

  Future<void> _set(bool value) async {
    setState(() => _enabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.notifications_none_rounded, color: AppColors.textDark, size: 21),
          const SizedBox(width: 14),
          const Expanded(child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
          Switch(
            value: _enabled,
            activeThumbColor: AppColors.primary,
            onChanged: _loaded ? _set : null,
          ),
        ],
      ),
    );
  }
}
