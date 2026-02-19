/// Supabase Configuration
/// Replace these values with your actual Supabase project credentials
class SupabaseConfig {
  // Supabase project URL
  static const String supabaseUrl = 'https://prghjnknjkrckbiqydgi.supabase.co';
  
  // Supabase anon/public key
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByZ2hqbmtuamtyY2tiaXF5ZGdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDA4MDksImV4cCI6MjA4NjkxNjgwOX0.xJLCs_dNbPX514vHcjQ_FU_CctS22BKTICzHvRoR4HM';
  
  // Realtime configuration
  static const Duration realtimeTimeout = Duration(seconds: 30);
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
}
