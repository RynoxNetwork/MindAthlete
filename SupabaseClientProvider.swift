import Supabase
import Foundation

enum MAEnv {
  static let url = URL(string: "https://hmsuuebvgijrjqefgmmr.supabase.co ")!    // <- pega tu URL
  static let anonKey = "<eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtc3V1ZWJ2Z2lqcmpxZWZnbW1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0NjQwNDcsImV4cCI6MjA3NjA0MDA0N30.euJSINq4UywU95rZRyYT1bCQYVdURXhWAIBzLigB6u8 >"                           // <- pega tu anon key
}

struct MAClients {
  static let shared = SupabaseClient(supabaseURL: MAEnv.url, supabaseKey: MAEnv.anonKey)
}
