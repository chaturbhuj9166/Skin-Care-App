import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/session/session_controller.dart';
import '../../core/widgets/app_avatar.dart';
import '../../data/models/case_model.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    final doctor = repo.currentDoctor;
    final cases = repo.doctorCases;
    final solved = cases.where((c) => c.status == CaseStatus.solved || c.status == CaseStatus.closed).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('My Profile', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(initials: doctor.initials, seed: doctor.avatarSeed, size: 84, imageUrl: doctor.avatarUrl),
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
                Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 3),
                Text('${doctor.specialization} • ${doctor.experienceYears} yrs experience', style: const TextStyle(color: AppColors.textLight, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Total Cases', value: '${cases.length}')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Solved', value: '$solved')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Rating', value: doctor.reviewCount > 0 ? doctor.rating.toStringAsFixed(1) : '—')),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              value: repo.doctorAvailable,
              onChanged: (v) => repo.toggleDoctorAvailability(v),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for new cases', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
          ),
          const SizedBox(height: 10),
          _ProfileTile(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () => _editProfileSheet(context, ref)),
          _ProfileTile(icon: Icons.lock_reset_rounded, label: 'Change Password', onTap: () => _changePasswordSheet(context, ref)),
          _ProfileTile(icon: Icons.calendar_today_outlined, label: 'Appointments', onTap: () => context.push('/doctor-appointments')),
          _ProfileTile(
            icon: Icons.support_agent_rounded,
            label: 'Help & Support',
            onTap: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Help & Support'),
                content: const Text('For account or technical issues, please contact the SkinCare admin team.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: AppColors.error))),
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
      await repo.updateDoctorProfile(avatar: url);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  void _changePasswordSheet(BuildContext context, WidgetRef ref) {
    final repo = ref.read(apiRepositoryProvider);
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool saving = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) {
        Future<void> save() async {
          if (newController.text.length < 6) {
            setSheetState(() => error = 'New password must be at least 6 characters');
            return;
          }
          if (newController.text != confirmController.text) {
            setSheetState(() => error = 'New passwords do not match');
            return;
          }
          setSheetState(() {
            saving = true;
            error = null;
          });
          try {
            await repo.changeDoctorPassword(oldController.text, newController.text);
            if (!sheetContext.mounted) return;
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
          } catch (e) {
            setSheetState(() {
              saving = false;
              error = apiErrorMessage(e);
            });
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Password', style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextField(controller: oldController, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
              const SizedBox(height: 12),
              TextField(controller: newController, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
              const SizedBox(height: 12),
              TextField(controller: confirmController, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Updating…' : 'Update Password'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _editProfileSheet(BuildContext context, WidgetRef ref) {
    final repo = ref.read(apiRepositoryProvider);
    final nameController = TextEditingController(text: repo.currentDoctor.name);
    final specController = TextEditingController(text: repo.currentDoctor.specialization);
    final experienceController = TextEditingController(text: '${repo.currentDoctor.experienceYears}');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Profile', style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: specController, decoration: const InputDecoration(labelText: 'Specialization')),
              const SizedBox(height: 12),
              TextField(
                controller: experienceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Experience (years)'),
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
                            await repo.updateDoctorProfile(
                              name: nameController.text.trim(),
                              specialization: specController.text.trim(),
                              experience: int.tryParse(experienceController.text.trim()),
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 10.5)),
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
