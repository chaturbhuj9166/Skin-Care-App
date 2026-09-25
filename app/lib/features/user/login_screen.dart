import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/session/complete_login.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/api/api_client.dart';
import '../../data/api/auth_api.dart';
import '../../data/api/phone_auth_service.dart';

/// One login screen for the one app: patients sign in with their phone
/// number + an OTP the server generates, doctors with the email + password
/// the Admin created for them.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _Country {
  final String flag;
  final String name;
  final String code;
  /// Exact number of digits in a mobile number (after the country code).
  final int digits;
  const _Country({required this.flag, required this.name, required this.code, required this.digits});
}

const _countries = [
  _Country(flag: '🇮🇳', name: 'India', code: '+91', digits: 10),
  _Country(flag: '🇺🇸', name: 'United States', code: '+1', digits: 10),
  _Country(flag: '🇬🇧', name: 'United Kingdom', code: '+44', digits: 10),
  _Country(flag: '🇦🇪', name: 'UAE', code: '+971', digits: 9),
  _Country(flag: '🇨🇦', name: 'Canada', code: '+1', digits: 10),
  _Country(flag: '🇦🇺', name: 'Australia', code: '+61', digits: 9),
  _Country(flag: '🇸🇬', name: 'Singapore', code: '+65', digits: 8),
];

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isDoctor = false;
  bool _loading = false;

  final _phoneController = TextEditingController();
  _Country _country = _countries.first;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendOtp() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != _country.digits) {
      _toast('Enter a valid ${_country.digits}-digit mobile number');
      return;
    }
    if (_country.code == '+91' && !RegExp(r'^[6-9]').hasMatch(digits)) {
      _toast('Indian mobile numbers start with 6, 7, 8 or 9');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final phone = '${_country.code}$digits';
    try {
      // Real SMS through Firebase on a phone; the server-generated OTP on
      // web/desktop, where Firebase has no config to start from.
      final request = firebaseReady ? await PhoneAuthService.instance.sendCode(phone) : await AuthApi.sendOtp(phone);
      if (!mounted) return;
      // Android can verify the number by itself before the OTP screen opens -
      // then there is no code to type and we log straight in.
      final autoIdToken = PhoneAuthService.instance.takeAutoIdToken() ?? request.autoIdToken;
      if (autoIdToken != null) {
        final next = await completeLogin(ref, await AuthApi.firebaseLogin(autoIdToken));
        if (!mounted) return;
        context.go(next);
        return;
      }
      context.push('/verify-otp', extra: request);
    } catch (e) {
      if (mounted) _toast(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doctorLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || password.isEmpty) {
      _toast('Enter your email and password');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final result = await AuthApi.doctorLogin(email, password);
      final next = await completeLogin(ref, result);
      if (!mounted) return;
      context.go(next);
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickCountry() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select country', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              ...(_countries.map((c) => ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(c.name),
                    trailing: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      setState(() {
                        _country = c;
                        // Drop digits beyond the new country's length.
                        if (_phoneController.text.length > c.digits) {
                          _phoneController.text = _phoneController.text.substring(0, c.digits);
                        }
                      });
                      Navigator.pop(context);
                    },
                  ))),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(topPadding: top, isDoctor: _isDoctor),
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 30, offset: const Offset(0, 12))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoleSwitch(
                        isDoctor: _isDoctor,
                        onChanged: (v) => setState(() => _isDoctor = v),
                      ),
                      const SizedBox(height: 22),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _isDoctor ? _doctorForm() : _patientForm(),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            ),
            const _TrustRow(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: const Text.rich(
                textAlign: TextAlign.center,
                TextSpan(
                  style: TextStyle(color: AppColors.textLight, fontSize: 12, height: 1.5),
                  children: [
                    TextSpan(text: 'By continuing, you agree to our '),
                    TextSpan(text: 'Terms', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    TextSpan(text: ' & '),
                    TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }

  Widget _patientForm() {
    return Column(
      key: const ValueKey('patient'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Mobile number'),
        Row(
          children: [
            InkWell(
              onTap: _pickCountry,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_country.flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(_country.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_country.digits)],
                style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
                decoration: InputDecoration(hintText: '9876543210'.substring(0, _country.digits), counterText: ''),
                onSubmitted: (_) => _sendOtp(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Expanded(
              child: Text("We'll send a 6-digit code to verify it's you.",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Get OTP', icon: Icons.sms_outlined, onPressed: _sendOtp, loading: _loading),
      ],
    );
  }

  Widget _doctorForm() {
    return Column(
      key: const ValueKey('doctor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Email'),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'doctor@skincareapp.com',
            prefixIcon: Icon(Icons.alternate_email_rounded, size: 20, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Password'),
        TextField(
          controller: _passwordController,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _doctorLogin(),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textMuted),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.textMuted),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Expanded(
              child: Text('Doctor accounts are created by the SkinCare admin.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Sign in as Doctor', icon: Icons.login_rounded, onPressed: _doctorLogin, loading: _loading),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final double topPadding;
  final bool isDoctor;
  const _Hero({required this.topPadding, required this.isDoctor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 28, 24, 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(right: -40, top: -30, child: _Bubble(size: 140, opacity: 0.08)),
          Positioned(left: -30, bottom: -40, child: _Bubble(size: 100, opacity: 0.06)),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Image.asset('assets/images/logo_icon_transparent.png', fit: BoxFit.contain),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack, begin: const Offset(0.6, 0.6)),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  isDoctor ? 'Welcome, Doctor' : 'Welcome to SkinCare',
                  key: ValueKey(isDoctor),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  isDoctor ? 'Sign in to review cases and help your patients.' : 'Expert dermatologists, right in your pocket.',
                  key: ValueKey('sub$isDoctor'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final double opacity;
  const _Bubble({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
    );
  }
}

/// Patient / Doctor segmented control with a sliding highlight.
class _RoleSwitch extends StatelessWidget {
  final bool isDoctor;
  final ValueChanged<bool> onChanged;
  const _RoleSwitch({required this.isDoctor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(String label, IconData icon, bool value) {
      final selected = isDoctor == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : AppColors.textLight),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: selected ? Colors.white : AppColors.textLight,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: isDoctor ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              option('Patient', Icons.person_rounded, false),
              option('Doctor', Icons.medical_services_rounded, true),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) => Expanded(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                child: Icon(icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          item(Icons.verified_user_rounded, 'Certified\ndermatologists'),
          item(Icons.lock_rounded, 'Private &\nsecure'),
          item(Icons.bolt_rounded, 'Fast\nsolutions'),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms, duration: 400.ms);
  }
}
