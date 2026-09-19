import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _Country {
  final String flag;
  final String name;
  final String code;
  const _Country({required this.flag, required this.name, required this.code});
}

const _countries = [
  _Country(flag: '🇮🇳', name: 'India', code: '+91'),
  _Country(flag: '🇺🇸', name: 'United States', code: '+1'),
  _Country(flag: '🇬🇧', name: 'United Kingdom', code: '+44'),
  _Country(flag: '🇦🇪', name: 'UAE', code: '+971'),
  _Country(flag: '🇨🇦', name: 'Canada', code: '+1'),
  _Country(flag: '🇦🇺', name: 'Australia', code: '+61'),
  _Country(flag: '🇸🇬', name: 'Singapore', code: '+65'),
];

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '98765 43210');
  _Country _country = _countries.first;
  bool _loading = false;

  Future<void> _sendOtp() async {
    if (_phoneController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }
    setState(() => _loading = true);
    // No Firebase project is wired up yet, so this just simulates the "OTP
    // sent" delay - see auth.controller.js's verifyOtp for the dummy backend
    // side, which accepts any syntactically valid 6-digit code.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _loading = false);
    final fullPhone = '${_country.code}${_phoneController.text.trim()}';
    context.push('/verify-otp', extra: fullPhone);
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
                      setState(() => _country = c);
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Image.asset('assets/images/logo_icon_transparent.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 20),
                    Text('Welcome back', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    const Text(
                      "Enter your phone number, we'll send you a verification code.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: _pickCountry,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 52,
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
                          const SizedBox(width: 2),
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(hintText: '98765 43210'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Send OTP', onPressed: _sendOtp, loading: _loading),
              const SizedBox(height: 32),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(color: AppColors.textLight, fontSize: 12.5),
                    children: [
                      TextSpan(text: 'By continuing, you agree to our '),
                      TextSpan(text: 'Terms', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      TextSpan(text: ' & '),
                      TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
