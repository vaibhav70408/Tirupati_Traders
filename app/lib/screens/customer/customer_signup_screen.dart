import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_controller.dart';
import '../../application/auth/auth_state.dart';
import '../../theme/app_colors.dart';
import 'customer_home_screen.dart';
import 'customer_profile_completion_screen.dart';
import 'otp_screen.dart';

class CustomerSignupScreen extends ConsumerStatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  ConsumerState<CustomerSignupScreen> createState() =>
      _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends ConsumerState<CustomerSignupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _sendOtp() {
    final name = _name.text.trim();
    final digits = _phone.text.trim();
    final address = _address.text.trim();

    if (name.length < 2) {
      _show('Please enter your full name');
      return;
    }
    if (digits.length != 10) {
      _show('Enter a valid 10-digit mobile number');
      return;
    }
    if (address.length < 5) {
      _show('Please enter a complete delivery address');
      return;
    }

    ref
        .read(authControllerProvider.notifier)
        .startSignup(name: name, phoneNumber: '+91$digits', address: address);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.signedIn && next.profileExists) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
          (route) => route.isFirst,
        );
      } else if (next.signedIn && next.needsProfile) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerProfileCompletionScreen(
              phoneNumber: next.phoneNumber ?? '',
            ),
          ),
          (route) => route.isFirst,
        );
      } else if (next.phase == AuthPhase.codeSent &&
          previous?.phase != AuthPhase.codeSent) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(phoneNumber: next.phoneNumber ?? ''),
          ),
        );
      } else if (next.error != null && next.error != previous?.error) {
        _show(next.error!);
      }
    });

    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.saffron, AppColors.saffronDark],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'TT',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Join Tirupati Traders',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter your details to start ordering',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            _label('FULL NAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Ramesh Kumar'),
            ),
            const SizedBox(height: 18),
            _label('MOBILE NUMBER'),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              textInputAction: TextInputAction.next,
              maxLength: 10,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                prefixText: '+91  ',
                prefixStyle: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                hintText: '98765 43210',
                counterText: '',
              ),
            ),
            const SizedBox(height: 18),
            _label('DELIVERY ADDRESS'),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'House no, street, landmark, city, pincode',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: auth.isBusy ? null : _sendOtp,
              child: auth.phase == AuthPhase.sendingCode
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send OTP'),
            ),
            const SizedBox(height: 24),
            const Text(
              'By continuing you agree to our Terms & Privacy Policy',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
    );
  }
}
