import Foundation
import Supabase

enum MAEnv {
  static let url = URL(string: "https://hmsuuebvgijrjqefgmmr.supabase.co")!
  static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtc3V1ZWJ2Z2lqcmpxZWZnbW1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0NjQwNDcsImV4cCI6MjA3NjA0MDA0N30.euJSINq4UywU95rZRyYT1bCQYVdURXhWAIBzLigB6u8"
  // Reemplaza este valor por tu OAuth Client ID de Google (no el reversed ID).
  static let googleClientID = "353076160309-vd4dfs0tvqd2rk0v3j5baso2oindj56o.apps.googleusercontent.com"
}

struct MAClients {
  static let shared = SupabaseClient(supabaseURL: MAEnv.url, supabaseKey: MAEnv.anonKey)
}
