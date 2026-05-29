import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signIn(
      email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    final state = ref.read(authNotifierProvider);
    if (mounted && state is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading;
    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: AppTheme.black,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Logo
                    Center(
                      child: Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          color: AppTheme.greenSubtle,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: AppTheme.green.withOpacity(0.35), width: 1),
                        ),
                        child: const Center(child: Text('💸', style: TextStyle(fontSize: 44))),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('SplitWise', textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 34,
                          fontWeight: FontWeight.w800, letterSpacing: -1)),
                    const SizedBox(height: 6),
                    const Text('Split expenses, not friendships', textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 48),
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
                    const SizedBox(height: 28),
                    GradientButton(
                      label: 'Sign In', icon: Icons.login_rounded,
                      onPressed: isLoading ? null : _submit, isLoading: isLoading,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?",
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        TextButton(
                          onPressed: () => context.go('/register'),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('Sign up', style: TextStyle(
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
      ),
    );
  }
}
