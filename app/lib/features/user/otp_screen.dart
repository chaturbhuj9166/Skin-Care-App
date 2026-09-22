import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/session/complete_login.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/api/api_client.dart';
import '../../data/api/auth_api.dart';

/// Verifies the server-generated OTP from POST /auth/send-otp.
///
/// No SMS provider is wired up yet, so the backend returns the code as
/// `devOtp` and this screen shows it in a card the user can tap to auto-fill.
/// Once real SMS delivery exists the backend stops sending `devOtp` and the
/// card simply disappears - nothing else here changes.
class OtpScreen extends ConsumerStatefulWidget {
  final OtpRequest request;
  const OtpScreen({super.key, required this.request});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _resendSeconds = 60;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late OtpRequest _request = widget.request;
  bool _loading = false;
  bool _resending = false;
  int _secondsLeft = _resendSeconds;
  int _errorTick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _focusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _startCountdown() {
    _secondsLeft = _resendSeconds;
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
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _controller.text;
    if (otp.length != 6) {
      _toast('Enter the 6-digit code');
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await AuthApi.verifyOtp(_request.phone, otp);
      final next = await completeLogin(ref, result);
      if (!mounted) return;
      context.go(next);
    } catch (e) {
      if (!mounted) return;
      _controller.clear();
      setState(() => _errorTick++);
      _toast(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      final request = await AuthApi.sendOtp(_request.phone);
      if (!mounted) return;
      setState(() => _request = request);
      _controller.clear();
      _focusNode.requestFocus();
      _startCountdown();
      _toast('A new code has been sent');
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _autofill() {
    final code = _request.devOtp;
    if (code == null) return;
    _controller.text = code;
    setState(() {});
    _verify();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 30),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack, begin: const Offset(0.6, 0.6)),
              const SizedBox(height: 18),
              Text('Verify your number', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.5, fontFamily: 'Inter'),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit code sent to '),
                    TextSpan(text: _request.phone, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (_request.devOtp != null) ...[
                const SizedBox(height: 20),
                _DevOtpCard(code: _request.devOtp!, onAutofill: _loading ? null : _autofill),
              ],
              const SizedBox(height: 26),
              _OtpBoxes(
                controller: _controller,
                focusNode: _focusNode,
                errorTick: _errorTick,
                onChanged: (v) {
                  setState(() {});
                  if (v.length == 6) _verify();
                },
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Verify & Continue', onPressed: _verify, loading: _loading),
              const SizedBox(height: 20),
              Center(
                child: _secondsLeft > 0
                    ? Text.rich(
                        TextSpan(
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          children: [
                            const TextSpan(text: "Didn't get it? Resend in "),
                            TextSpan(
                              text: '00:${_secondsLeft.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _resending ? null : _resend,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(_resending ? 'Sending…' : 'Resend code'),
                      ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Change number', style: TextStyle(color: AppColors.textLight)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six visual boxes over one real (transparent) text field, so paste,
/// keyboard autofill and backspace all behave like a normal input.
class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int errorTick;
  final ValueChanged<String> onChanged;

  const _OtpBoxes({required this.controller, required this.focusNode, required this.errorTick, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final boxes = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final filled = i < text.length;
        final active = focusNode.hasFocus && (i == text.length || (i == 5 && text.length == 6));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.primary : (filled ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border),
              width: active ? 1.8 : 1.2,
            ),
          ),
          child: Text(
            filled ? text[i] : '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark, fontFamily: 'Poppins'),
          ),
        );
      }),
    );

    return Stack(
      children: [
        // A new key per failed attempt replays the shake.
        errorTick == 0 ? boxes : boxes.animate(key: ValueKey(errorTick)).shakeX(duration: 400.ms, hz: 5, amount: 6),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              showCursor: false,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(border: InputBorder.none, filled: false, counterText: ''),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _DevOtpCard extends StatelessWidget {
  final String code;
  final VoidCallback? onAutofill;
  const _DevOtpCard({required this.code, required this.onAutofill});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF7E6), Color(0xFFFEF3E2)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sms_rounded, size: 15, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text('Your verification code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92600A))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  code.split('').join(' '),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark, letterSpacing: 2),
                ),
                const SizedBox(height: 2),
                const Text('Valid for 5 minutes', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAutofill,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Auto-fill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1, end: 0);
  }
}
