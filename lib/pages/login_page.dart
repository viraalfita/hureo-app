import 'package:attendance/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logic/auth/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _companyCodeController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  // Animation controller untuk panah
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();

    _arrowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _arrowAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
    _startArrowAnimation();
  }

  void _startArrowAnimation() => _arrowController.repeat(reverse: true);
  void _stopArrowAnimation() {
    _arrowController.stop();
    _arrowController.reset();
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _companyCodeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true; // biar spinner langsung muncul (UX sama)
      _errorMessage = '';
    });
    _stopArrowAnimation();

    // PANGGIL CUBIT (bukan ApiService)
    context.read<AuthCubit>().login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
      _companyCodeController.text.trim(),
    );
  }

  String _getErrorMessage(dynamic error) {
    final t = error.toString().toLowerCase();
    if (t.contains('timeout') || t.contains('socketexception')) {
      return "Connection timeout. Please check your internet connection.";
    } else if (t.contains('401') || t.contains('unauthorized')) {
      return "Invalid username or password.";
    } else if (t.contains('404') || t.contains('not found')) {
      return "Company code not found.";
    } else if (t.contains('500')) {
      return "Server error. Please try again later.";
    } else {
      return "An error occurred. Please try again.";
    }
  }

  void _clearError() {
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, state) {
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
          _stopArrowAnimation();
        } else if (state is AuthFailure) {
          setState(() {
            _isLoading = false;
            _errorMessage = _getErrorMessage(state.message);
          });
          _startArrowAnimation();
        } else if (state is AuthAuthenticated) {
          Navigator.pushReplacementNamed(ctx, "/login-success");
        } else {
          // AuthLoggedOut / AuthInitial
          setState(() => _isLoading = false);
          _startArrowAnimation();
        }
      },
      builder: (ctx, state) {
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo Section
                    Center(
                      child: Image.asset(
                        'assets/images/logo-hureo.png',
                        width: 92,
                        height: 92,
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      "Selamat Datang 👋",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        text: "Masuk ke akun",
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                        children: [
                          TextSpan(
                            text: " HUREO (Karyawan)",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error Message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.red.shade600,
                                size: 18,
                              ),
                              onPressed: _clearError,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    if (_errorMessage.isNotEmpty) const SizedBox(height: 16),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      onChanged: (_) => _clearError(),
                      decoration: InputDecoration(
                        labelText: "Username",
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? "Tolong isi username kamu"
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      onChanged: (_) => _clearError(),
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.blue,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.blue.withOpacity(0.6),
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? "Please enter your password"
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Company Code Field
                    TextFormField(
                      controller: _companyCodeController,
                      onChanged: (_) => _clearError(),
                      decoration: InputDecoration(
                        labelText: "Kode Perusahaan",
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.business_rounded,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? "Tolong isi kode perusahaan kamu"
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Login Button dengan animasi panah
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          shadowColor: Colors.blue.withOpacity(0.3),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Masuk",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedBuilder(
                                    animation: _arrowAnimation,
                                    builder: (context, child) {
                                      return Transform.translate(
                                        offset: Offset(
                                          _arrowAnimation.value,
                                          0,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 20,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
