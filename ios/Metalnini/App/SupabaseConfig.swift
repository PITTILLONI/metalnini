import Foundation

/// Connexion au projet Supabase METALNINI.
/// La clé publique (« publishable » / anon) est faite pour être embarquée dans l'app : elle ne donne accès
/// qu'à ce que les règles RLS autorisent. La clé secrète (service_role) ne doit JAMAIS figurer ici.
enum SupabaseConfig {
    static let url = URL(string: "https://mdnevzmczljycmgbsrsu.supabase.co")!
    static let publishableKey = "sb_publishable_5icL9XXH9Hmn4sQMxm5F3Q_PtClnwQs"
}
