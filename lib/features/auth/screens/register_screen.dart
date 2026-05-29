import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/loading_overlay.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signUp(
      email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    final state = ref.read(authNotifierProvider);
    if (!mounted) return;
    if (state is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error.toString())));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Check your email to confirm.')));
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider) is AsyncLoading;
    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: AppTheme.black,
        appBar: AppBar(
          title: const Text('Create Account'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => context.go('/login'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Join SplitWise',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 26,
                        fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  const Text('Create your free account',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outlined)),
                    validator: (v) => v == _passwordCtrl.text ? null : 'Passwords do not match',
                  ),
                  const SizedBox(height: 32),
                  GradientButton(
                    label: 'Create Account', icon: Icons.person_add_rounded,
                    onPressed: isLoading ? null : _submit, isLoading: isLoading,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: const Text('Sign in', style: TextStyle(
                            color: AppTheme.green, fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
