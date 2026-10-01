import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme_engine.dart';
import '../../auth/application/auth_state_provider.dart';
import '../application/profile_state_notifier.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final Profile? profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _pickedAvatar;
  Uint8List? _pickedAvatarBytes;
  XFile? _pickedCover;
  Uint8List? _pickedCoverBytes;
  String? _selectedProfileColor;
  bool _isSaving = false;

  static const _profileThemeHexColors = <String>[
    '#5865F2',
    '#EB459E',
    '#3BA55D',
    '#9B59B6',
    '#FAA61A',
    '#4F545C',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.profile?.firstName?.trim() ?? '';
    _lastNameController.text = widget.profile?.lastName?.trim() ?? '';
    _bioController.text = widget.profile?.bio?.trim() ?? '';
    _selectedProfileColor = widget.profile?.profileColor;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (file == null || !mounted) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedAvatar = file;
      _pickedAvatarBytes = bytes;
    });
  }

  Future<void> _pickCover() async {
    final file = await _picker.pickMedia(requestFullMetadata: true);
    if (file == null || !mounted) {
      return;
    }

    final extension = file.name.toLowerCase().split('.').last;
    const supportedExtensions = {'gif', 'png', 'jpg', 'jpeg', 'webp', 'heic'};
    if (!supportedExtensions.contains(extension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an image/GIF file for cover.'),
        ),
      );
      return;
    }

    // Keep original bytes/format so GIF covers remain animated when supported.
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedCover = file;
      _pickedCoverBytes = bytes;
    });
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _isSaving) {
      return;
    }

    final userId = ref.read(authUserIdProvider);
    if (userId == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? avatarUrl = widget.profile?.avatarUrl;
      String? coverUrl = widget.profile?.coverUrl;
      final selectedProfileColor = _selectedProfileColor;

      ref
          .read(profileStateProvider.notifier)
          .applyLocalProfileUpdate(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            bio: _bioController.text,
            profileColor: selectedProfileColor,
          );

      if (_pickedAvatar != null) {
        final bytes = await _pickedAvatar!.readAsBytes();
        final publicUrl = await ref
            .read(profileRepositoryProvider)
            .uploadAvatar(
              userId: userId,
              bytes: bytes,
              originalFileName: _pickedAvatar!.name,
            );
        avatarUrl = _withCacheBust(publicUrl);

        ref
            .read(profileStateProvider.notifier)
            .applyLocalProfileUpdate(avatarUrl: avatarUrl);
      }

      if (_pickedCover != null) {
        final bytes = await _pickedCover!.readAsBytes();
        final publicUrl = await ref
            .read(profileRepositoryProvider)
            .uploadCover(
              userId: userId,
              bytes: bytes,
              originalFileName: _pickedCover!.name,
            );
        coverUrl = _withCacheBust(publicUrl);

        ref
            .read(profileStateProvider.notifier)
            .applyLocalProfileUpdate(coverUrl: coverUrl);
      }

      ref
          .read(profileStateProvider.notifier)
          .saveProfileOptimistic(
            userId: userId,
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            bio: _bioController.text,
            avatarUrl: avatarUrl,
            coverUrl: coverUrl,
            profileColor: selectedProfileColor,
          );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on StorageException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save profile changes.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _withCacheBust(String url) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}t=$timestamp';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    final selectedTheme = _parseHexColor(_selectedProfileColor);
    final showAvatarPlaceholder =
        _pickedAvatarBytes == null &&
        (widget.profile?.avatarUrl == null ||
            widget.profile!.avatarUrl!.isEmpty);
    final ImageProvider<Object>? coverImageProvider = _pickedCoverBytes != null
        ? MemoryImage(_pickedCoverBytes!)
        : (widget.profile?.coverUrl != null &&
                  widget.profile!.coverUrl!.isNotEmpty
              ? NetworkImage(widget.profile!.coverUrl!)
              : null);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 229,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 165,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: coverImageProvider == null
                            ? LinearGradient(
                                colors: [
                                  selectedTheme ?? const Color(0xFF202225),
                                  const Color(0xFF111214),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        image: coverImageProvider != null
                            ? DecorationImage(
                                image: coverImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: surface.withValues(alpha: 0.9),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _pickCover,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Cover / GIF'),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: surface,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor: surface,
                              backgroundImage: _pickedAvatarBytes != null
                                  ? MemoryImage(_pickedAvatarBytes!)
                                  : (widget.profile?.avatarUrl != null &&
                                            widget
                                                .profile!
                                                .avatarUrl!
                                                .isNotEmpty
                                        ? NetworkImage(
                                            widget.profile!.avatarUrl!,
                                          )
                                        : null),
                              child: showAvatarPlaceholder
                                  ? Icon(
                                      Icons.person_rounded,
                                      color: accent,
                                      size: 38,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: surface,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _pickAvatar,
                            icon: const Icon(
                              Icons.face_retouching_natural,
                              size: 18,
                            ),
                            label: const Text('Avatar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'PROFILE DETAILS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _firstNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'First name',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: surface,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Last name',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: surface,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Bio',
                  alignLabelWithHint: true,
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: surface,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'PROFILE THEME',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _profileThemeHexColors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final hex = _profileThemeHexColors[index];
                    final color = _parseHexColor(hex) ?? Colors.grey;
                    final selected =
                        (_selectedProfileColor ?? '').toLowerCase() ==
                        hex.toLowerCase();
                    return GestureDetector(
                      onTap: () => setState(() => _selectedProfileColor = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color? _parseHexColor(String? input) {
  if (input == null || input.trim().isEmpty) {
    return null;
  }
  var value = input.trim().replaceAll('#', '');
  if (value.length == 6) {
    value = 'FF$value';
  }
  if (value.length != 8) {
    return null;
  }
  return Color(int.tryParse(value, radix: 16) ?? 0xFF202225);
}
