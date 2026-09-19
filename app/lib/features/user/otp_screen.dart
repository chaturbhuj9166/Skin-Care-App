import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/session/session_controller.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';

/// No real SMS/OTP provider is wired up yet - the backend accepts any
/// syntactically valid 6-digit code (see auth.controller.js's verifyOtp).
/// Swap this screen's verify call for real Firebase Phone-Auth once a
/// Firebase project is available.
class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the 6-digit code')));
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.post('/auth/verify-otp', data: {
        'phone': widget.phone,
        'otp': _otp,
      });
      final token = res.data['token'] as String;
      final isDoctor = res.data['role'] == 'DOCTOR';
      final isNewUser = !isDoctor && (res.data['user']?['name'] as String?) == 'New User';
      // Set the token and load the right data set BEFORE flipping `loggedIn`,
      // so the router's redirect (which fires the moment session state
      // changes) never lands on a home screen before currentUser/currentDoctor
      // is ready.
      ApiClient.instance.setToken(token);
      final repo = ref.read(apiRepositoryProvider);
      if (isDoctor) {
        await repo.bootstrapDoctor();
      } else {
        await repo.bootstrapUser();
      }
      await ref.read(appSessionProvider.notifier).login(token, isDoctor ? AppRole.doctor : AppRole.user);
      if (!mounted) return;
      context.go(isDoctor ? '/dashboard' : (isNewUser ? '/complete-profile' : '/home'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP resent')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify your number', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to ${widget.phone}',
                style: const TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        } else if (value.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        setState(() {});
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Verify', onPressed: _verify, loading: _loading),
              const SizedBox(height: 20),
              Center(
                child: _secondsLeft > 0
                    ? Text('Resend code in 00:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13))
                    : TextButton(onPressed: _resend, child: const Text('Resend code')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
