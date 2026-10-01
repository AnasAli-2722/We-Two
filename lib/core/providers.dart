import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseConfiguredProvider = Provider<bool>((ref) {
  try {
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
});
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
