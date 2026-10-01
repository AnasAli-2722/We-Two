import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_engine.dart';
import '../data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isBusy = false;
  bool _isLoginMode = true;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorText = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Email and password are required.';
      });
      return;
    }

    if (!_isLoginMode && confirmPassword != password) {
      setState(() {
        _errorText = 'Passwords do not match.';
      });
      return;
    }

    setState(() => _isBusy = true);
    final authRepository = ref.read(authRepositoryProvider);

    if (_isLoginMode) {
      try {
        await authRepository.signIn(email: email, password: password);
      } on AuthFailure catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = error.message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        if (!mounted) {
          return;
        }
        const message = 'Unable to sign in right now. Please try again.';
        setState(() {
          _errorText = message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(message)));
      } finally {
        if (mounted) {
          setState(() => _isBusy = false);
        }
      }
      return;
    }

    try {
      await authRepository.signUp(email: email, password: password);

      if (!mounted) {
        return;
      }

      _passwordController.clear();
      _confirmPasswordController.clear();
      _emailController.text = email;

      setState(() {
        _isLoginMode = true;
        _errorText = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration successful! Please check your email to verify your account.',
          ),
        ),
      );
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      const message = 'Unable to sign up right now. Please try again.';
      setState(() {
        _errorText = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = error.message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      const message = 'Unable to continue with Google right now.';
      setState(() => _errorText = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _continueWithPhone() async {
    if (_isBusy) {
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    var otpRequested = false;
    var isDialogBusy = false;
    String? phoneError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> requestOtp() async {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) {
                setDialogState(() => phoneError = 'Phone number is required.');
                return;
              }

              setDialogState(() {
                isDialogBusy = true;
                phoneError = null;
              });

              try {
                await authRepository.requestPhoneOtp(phone: phone);
                setDialogState(() => otpRequested = true);
                if (!dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('OTP sent. Please check your phone.'),
                  ),
                );
              } on AuthFailure catch (error) {
                setDialogState(() => phoneError = error.message);
              } catch (_) {
                setDialogState(
                  () => phoneError = 'Unable to send OTP right now.',
                );
              } finally {
                setDialogState(() => isDialogBusy = false);
              }
            }

            Future<void> verifyOtp() async {
              final phone = phoneController.text.trim();
              final otp = otpController.text.trim();

              if (otp.isEmpty) {
                setDialogState(() => phoneError = 'OTP code is required.');
                return;
              }

              setDialogState(() {
                isDialogBusy = true;
                phoneError = null;
              });

              try {
                await authRepository.verifyPhoneOtp(phone: phone, token: otp);
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Phone verification complete.')),
                );
              } on AuthFailure catch (error) {
                setDialogState(() => phoneError = error.message);
              } catch (_) {
                setDialogState(
                  () => phoneError = 'Unable to verify OTP right now.',
                );
              } finally {
                setDialogState(() => isDialogBusy = false);
              }
            }

            return AlertDialog(
              backgroundColor:
                  Theme.of(
                    dialogContext,
                  ).extension<WeTwoThemeColors>()?.surfaceAlt ??
                  Theme.of(dialogContext).colorScheme.surface,
              title: Text(
                'Continue with Phone Number',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      final appColors = theme.extension<WeTwoThemeColors>();
                      final accent =
                          appColors?.accent ?? theme.colorScheme.primary;
                      final surface =
                          appColors?.surface ?? theme.colorScheme.surface;
                      final onSurface = theme.colorScheme.onSurface;
                      return Column(
                        children: [
                          TextField(
                            controller: phoneController,
                            style: TextStyle(color: onSurface),
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration(
                              'Phone Number (E.164)',
                              accent,
                              surface,
                              onSurface,
                            ),
                          ),
                          if (otpRequested) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: otpController,
                              style: TextStyle(color: onSurface),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(
                                'OTP Code',
                                accent,
                                surface,
                                onSurface,
                              ),
                            ),
                          ],
                          if (phoneError != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              phoneError!,
                              style: TextStyle(color: accent, fontSize: 13),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogBusy
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isDialogBusy
                      ? null
                      : (otpRequested ? verifyOtp : requestOtp),
                  child: isDialogBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(otpRequested ? 'Verify OTP' : 'Send OTP'),
                ),
              ],
            );
          },
        );
      },
    );

    phoneController.dispose();
    otpController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _emailController,
                    style: TextStyle(color: onSurface),
                    decoration: _inputDecoration(
                      'Email',
                      accent,
                      surface,
                      onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    style: TextStyle(color: onSurface),
                    obscureText: true,
                    decoration: _inputDecoration(
                      'Password',
                      accent,
                      surface,
                      onSurface,
                    ),
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      style: TextStyle(color: onSurface),
                      obscureText: true,
                      decoration: _inputDecoration(
                        'Confirm Password',
                        accent,
                        surface,
                        onSurface,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _isBusy ? null : _submit,
                      child: _isBusy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLoginMode ? 'Login' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'OR',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : _continueWithGoogle,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Continue with Google'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : _continueWithPhone,
                      icon: const Icon(Icons.phone_android_rounded),
                      label: const Text('Continue with Phone Number'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isBusy
                        ? null
                        : () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                              _errorText = null;
                            });
                          },
                    child: Text(
                      _isLoginMode
                          ? 'Need an account? Sign Up'
                          : 'Already have an account? Login',
                      style: TextStyle(color: accent),
                    ),
                  ),
                  if (_errorText != null) ...[
                    Text(
                      _errorText!,
                      style: TextStyle(color: accent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    Color accent,
    Color surface,
    Color onSurface,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.45)),
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent),
      ),
    );
  }
}
