import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_controller.dart';
import '../../application/auth/auth_state.dart';
import '../../theme/app_colors.dart';
import 'customer_home_screen.dart';

class CustomerProfileCompletionScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const CustomerProfileCompletionScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<CustomerProfileCompletionScreen> createState() =>
      _CustomerProfileCompletionScreenState();
}

class _CustomerProfileCompletionScreenState
    extends ConsumerState<CustomerProfileCompletionScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final address = _address.text.trim();

    if (name.length < 2) {
      _show('Please enter your full name');
      return;
    }
    if (address.length < 5) {
      _show('Please enter a complete delivery address');
      return;
    }

    ref
        .read(authControllerProvider.notifier)
        .saveProfile(name: name, address: address);
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
        title: const Text('Complete Profile'),
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
              'Almost there!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your number ${widget.phoneNumber} is verified. Add your name and address to continue.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: auth.isBusy ? null : _save,
              child: auth.phase == AuthPhase.verifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save & Continue'),
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
