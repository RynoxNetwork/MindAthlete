import Foundation

struct QuoteService {
  private static let quotes: [String] = [
    "Apunta alto y entrena tu mente.",
    "Confía en tu rutina. Hoy sumas 1%.",
    "Respira, enfoca, ejecuta.",
    "Constancia vence intensidad.",
    "El cuerpo sigue donde va la mente.",
    "La calma es tu ventaja competitiva.",
    "Entrena como compites: presente y confiado.",
    "Tu mejor versión empieza con un pensamiento.",
    "Lo pequeño hecho hoy es lo grande mañana.",
    "Mindset fuerte, juego inteligente."
  ]

  func randomQuote() -> String {
    Self.quotes.randomElement() ?? "Entrena tu mente."
  }
}
