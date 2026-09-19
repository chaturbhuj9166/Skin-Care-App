import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';

/// Shown once, right after a brand-new account's first OTP verification, so
/// the user has an obvious place to set their name and photo before landing
/// on Home - rather than only discovering avatar upload later inside the
/// Profile tab's edit sheet.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  String? _pickedAvatarUrl;
  bool _uploadingPhoto = false;
  bool _saving = false;

  Future<void> _pickPhoto() async {
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
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await ref.read(apiRepositoryProvider).uploadFile(picked);
      if (!mounted) return;
      setState(() => _pickedAvatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      if (name.isNotEmpty || _pickedAvatarUrl != null) {
        await ref.read(apiRepositoryProvider).updateProfile(
              name: name.isNotEmpty ? name : null,
              avatar: _pickedAvatarUrl,
            );
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(apiRepositoryProvider).currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text('Complete your profile', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text(
                'Add a photo and your name so your doctor knows who they\'re talking to.',
                style: TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              Center(
                child: InkWell(
                  onTap: _uploadingPhoto ? null : _pickPhoto,
                  borderRadius: BorderRadius.circular(50),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _uploadingPhoto
                          ? const SizedBox(
                              width: 96,
                              height: 96,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : AppAvatar(
                              initials: user.name.isNotEmpty ? user.name[0] : '?',
                              seed: user.avatarSeed,
                              size: 96,
                              imageUrl: _pickedAvatarUrl,
                            ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text('Your Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Enter your full name', prefixIcon: Icon(Icons.person_outline_rounded)),
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Continue', onPressed: _continue, loading: _saving),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => context.go('/home'),
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
