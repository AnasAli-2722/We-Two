import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_error_reporter.dart';
import '../../../core/theme/app_theme_engine.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/application/auth_state_provider.dart';
import '../../chat/application/duo_state_notifier.dart';
import '../data/profile_repository.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Timer? _usernameDebounce;
  int _usernameCheckVersion = 0;

  Uint8List? _selectedAvatarBytes;
  String? _selectedAvatarFileName;
  String? _existingAvatarUrl;

  String? _usernameSyncError;
  String? _usernameAsyncError;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_handleUsernameChanged);
    unawaited(_bootstrapExistingProfile());
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_handleUsernameChanged);
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final hasFullName = _fullNameController.text.trim().isNotEmpty;
    final hasUsername = _usernameController.text.trim().isNotEmpty;
    return !_isSubmitting &&
        hasFullName &&
        hasUsername &&
        _usernameSyncError == null &&
        _usernameAsyncError == null &&
        _isUsernameAvailable &&
        !_isCheckingUsername;
  }

  Future<void> _bootstrapExistingProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getCurrentProfile(userId);

      if (!mounted || profile == null) {
        return;
      }

      _fullNameController.text = profile.fullName;
      _usernameController.text = profile.username;
      _existingAvatarUrl = profile.avatarUrl;
      _handleUsernameChanged();
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'profiles',
        operation: 'bootstrapProfileSetup',
      );
    }
  }

  void _handleUsernameChanged() {
    final username = _usernameController.text.trim();
    final syncError = _validateUsernameFormat(username);

    _usernameDebounce?.cancel();
    _usernameCheckVersion += 1;

    if (!mounted) {
      return;
    }

    setState(() {
      _usernameSyncError = syncError;
      _usernameAsyncError = null;
      _isCheckingUsername = false;
      _isUsernameAvailable = false;
    });

    if (syncError != null || username.isEmpty) {
      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_checkUsernameAvailability(username));
    });
  }

  String? _validateUsernameFormat(String username) {
    if (username.isEmpty) {
      return 'Username is required';
    }
    if (!_usernameRegex.hasMatch(username)) {
      return 'Use 3-20 characters: letters, numbers, underscore only';
    }
    return null;
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return false;
    }

    final currentVersion = _usernameCheckVersion;
    if (mounted) {
      setState(() {
        _isCheckingUsername = true;
        _usernameAsyncError = null;
      });
    }

    try {
      final available = await ref
          .read(profileRepositoryProvider)
          .isUsernameAvailable(username: username, userId: userId);

      if (!mounted || currentVersion != _usernameCheckVersion) {
        return false;
      }

      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = available;
        _usernameAsyncError = available ? null : 'Username is already taken';
      });
      return available;
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'profiles',
        operation: 'usernameAvailabilityCheck',
        context: <String, Object?>{'username': username},
      );

      if (!mounted || currentVersion != _usernameCheckVersion) {
        return false;
      }

      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameAsyncError = 'Unable to validate username right now';
      });
      return false;
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAvatarBytes = bytes;
      _selectedAvatarFileName = picked.name;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final syncError = _validateUsernameFormat(username);
    if (syncError != null) {
      setState(() => _usernameSyncError = syncError);
      return;
    }

    final available = await _checkUsernameAvailability(username);
    if (!mounted) {
      return;
    }
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an available username.')),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session not found. Please sign in again.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final profileRepository = ref.read(profileRepositoryProvider);
      String? avatarUrl = _existingAvatarUrl;

      if (_selectedAvatarBytes != null && _selectedAvatarFileName != null) {
        avatarUrl = await profileRepository.uploadAvatar(
          userId: userId,
          bytes: _selectedAvatarBytes!,
          originalFileName: _selectedAvatarFileName!,
        );
      }

      await profileRepository.completeProfile(
        userId: userId,
        fullName: _fullNameController.text,
        username: username,
        avatarUrl: avatarUrl,
      );

      final gate = await ref.refresh(authGateProvider.future);
      ref.invalidate(duoStateProvider);

      if (!mounted) {
        return;
      }

      if (gate == AuthGate.authenticated) {
        context.go('/chat');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved, but setup is still required.'),
          ),
        );
      }
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'profiles',
        operation: 'completeProfile',
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete profile: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    final onSurface = theme.colorScheme.onSurface;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: 'Choose avatar',
                        child: GestureDetector(
                          onTap: _isSubmitting ? null : _pickAvatar,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: surface,
                                backgroundImage: _selectedAvatarBytes != null
                                    ? MemoryImage(_selectedAvatarBytes!)
                                    : (_existingAvatarUrl != null &&
                                              _existingAvatarUrl!.isNotEmpty
                                          ? NetworkImage(_existingAvatarUrl!)
                                                as ImageProvider<Object>
                                          : null),
                                child:
                                    _selectedAvatarBytes == null &&
                                        (_existingAvatarUrl == null ||
                                            _existingAvatarUrl!.isEmpty)
                                    ? Icon(
                                        Icons.person_rounded,
                                        color: accent,
                                        size: 42,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: background,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Complete your profile',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your name and username to continue.',
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _fullNameController,
                        style: TextStyle(color: onSurface),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Full name is required';
                          }
                          return null;
                        },
                        decoration: _inputDecoration('Full Name *', accent),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usernameController,
                        style: TextStyle(color: onSurface),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          return _validateUsernameFormat(value?.trim() ?? '');
                        },
                        decoration: _inputDecoration('Username *', accent)
                            .copyWith(
                              errorText:
                                  _usernameSyncError ?? _usernameAsyncError,
                              suffixIcon: _buildUsernameSuffix(),
                            ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _canSubmit ? _submit : null,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save & Continue'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                await ref
                                    .read(authRepositoryProvider)
                                    .signOut();
                              },
                        child: Text(
                          'Sign out',
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, Color accent) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;

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

  Widget? _buildUsernameSuffix() {
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final hasValue = _usernameController.text.trim().isNotEmpty;
    if (!hasValue || _usernameSyncError != null) {
      return null;
    }

    if (_usernameAsyncError != null) {
      return const Icon(Icons.close_rounded, color: Colors.redAccent);
    }

    if (_isUsernameAvailable) {
      return const Icon(Icons.check_circle_rounded, color: Colors.green);
    }

    return null;
  }
}
