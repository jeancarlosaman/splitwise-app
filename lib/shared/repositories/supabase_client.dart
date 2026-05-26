import 'package:supabase_flutter/supabase_flutter.dart';

/// Convenience accessor for the Supabase client singleton.
SupabaseClient get supabase => Supabase.instance.client;
