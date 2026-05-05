import Foundation

// MARK: - Supabase Configuration
// 1. Supabase dashboard'dan Project Settings → API'ye git
// 2. "Project URL" ve "anon public" key'i kopyala
// 3. Aşağıdaki değerleri doldur

enum SupabaseConfig {
    /// Supabase project URL — https://zxseytwpunjajypzrmmr.supabase.co
    static let url = "https://zxseytwpunjajypzrmmr.supabase.co"

    /// Supabase anon/public key (güvenli, client-side kullanım için)
    static let anonKey = "sb_publishable_O5eohcdqoPLjwsXIPUDTMA_2XINzzKX"
}
