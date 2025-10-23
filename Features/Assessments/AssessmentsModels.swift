import Foundation

enum SubscriptionTier: String {
    case free
    case premium
}

extension AssessmentStatus {
    var isActionable: Bool {
        switch self {
        case .neverTaken: return true
        case .available: return true
        case .lockedUntil: return false
        }
    }
}

enum AssessmentStatus: Equatable {
    case neverTaken
    case available(lastTaken: Date?)
    case lockedUntil(Date)
}

enum AssessmentInstrument: String, CaseIterable, Identifiable {
    case poms = "POMS"
    case idep = "IDEP"
    case selfEsteem = "SELF_ESTEEM"

    struct Subscale: Identifiable {
        let id: String
        let title: String
        let description: String
    }

    struct Item: Identifiable {
        let id: String
        let prompt: String
        let subscaleId: String
        let isReversed: Bool
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .poms: return "POMS"
        case .idep: return "IDEP"
        case .selfEsteem: return "Autoestima (Rosenberg)"
        }
    }

    var shortTitle: String {
        switch self {
        case .poms: return "POMS"
        case .idep: return "IDEP"
        case .selfEsteem: return "Autoestima"
        }
    }

    var description: String {
        switch self {
        case .poms:
            return "Evalúa estados de ánimo como tensión, vigor y fatiga para ajustar las cargas mentales."
        case .idep:
            return "Identifica indicadores de bienestar psicológico y recursos de afrontamiento en deportistas."
        case .selfEsteem:
            return "Mide la autopercepción y seguridad personal para personalizar feedback motivacional."
        }
    }

    var estimatedDuration: String {
        switch self {
        case .poms: return "20 ítems · 4 min"
        case .idep: return "28 ítems · 6 min"
        case .selfEsteem: return "10 ítems · 3 min"
        }
    }

    var iconName: String {
        switch self {
        case .poms: return "gauge"
        case .idep: return "brain.head.profile"
        case .selfEsteem: return "star.circle"
        }
    }

    var items: [Item] {
        switch self {
        case .poms:
            return POMSDefinition.items
        case .idep:
            return IDEPDefinition.items
        case .selfEsteem:
            return SelfEsteemDefinition.items
        }
    }

    var itemCount: Int {
        items.count
    }

    var subscales: [Subscale] {
        switch self {
        case .poms:
            return POMSDefinition.subscales
        case .idep:
            return IDEPDefinition.subscales
        case .selfEsteem:
            return SelfEsteemDefinition.subscales
        }
    }

    var freeRetakeInterval: DateComponents {
        DateComponents(weekOfYear: 8)
    }

    var itemCodePrefix: String {
        switch self {
        case .poms: return "POMS"
        case .idep: return "IDEP"
        case .selfEsteem: return "SELF"
        }
    }
}

enum AssessmentEligibility {
    static func status(for instrument: AssessmentInstrument,
                       lastTaken: Date?,
                       tier: SubscriptionTier,
                       referenceDate: Date = Date(),
                       calendar: Calendar = .current) -> AssessmentStatus {
        guard let lastTaken else {
            return .neverTaken
        }

        guard tier == .free else {
            return .available(lastTaken: lastTaken)
        }

        if let next = calendar.date(byAdding: instrument.freeRetakeInterval, to: lastTaken),
           next > referenceDate {
            return .lockedUntil(next)
        }

        return .available(lastTaken: lastTaken)
    }

    static func pendingInstruments(latestAssessments: [AssessmentInstrument: Date],
                                   tier: SubscriptionTier,
                                   referenceDate: Date = Date(),
                                   calendar: Calendar = .current) -> [AssessmentInstrument] {
        AssessmentInstrument.allCases.filter { instrument in
            let lastTaken = latestAssessments[instrument]
            let status = status(for: instrument, lastTaken: lastTaken, tier: tier, referenceDate: referenceDate, calendar: calendar)
            switch status {
            case .neverTaken:
                return true
            case .available:
                return true
            case .lockedUntil:
                return true
            }
        }
    }
}

// MARK: - Definition data

private enum POMSDefinition {
    static let subscales: [AssessmentInstrument.Subscale] = [
        .init(id: "tension", title: "Tensión", description: "Nerviosismo y estrés percibido."),
        .init(id: "vigor", title: "Vigor", description: "Energía y motivación percibida."),
        .init(id: "fatigue", title: "Fatiga", description: "Sensación de cansancio físico o mental."),
        .init(id: "calma", title: "Calma", description: "Equilibrio y control emocional.")
    ]

    static let items: [AssessmentInstrument.Item] = [
        .init(id: "poms_01", prompt: "Me siento tenso/a", subscaleId: "tension", isReversed: false),
        .init(id: "poms_02", prompt: "Estoy lleno/a de energía", subscaleId: "vigor", isReversed: false),
        .init(id: "poms_03", prompt: "Me siento agotado/a", subscaleId: "fatigue", isReversed: false),
        .init(id: "poms_04", prompt: "Me siento tranquilo/a", subscaleId: "calma", isReversed: false),
        .init(id: "poms_05", prompt: "Estoy preocupado/a por algo", subscaleId: "tension", isReversed: false),
        .init(id: "poms_06", prompt: "Tengo ganas de entrenar", subscaleId: "vigor", isReversed: false),
        .init(id: "poms_07", prompt: "Siento que me falta energía", subscaleId: "fatigue", isReversed: false),
        .init(id: "poms_08", prompt: "Estoy en control de mis emociones", subscaleId: "calma", isReversed: false),
        .init(id: "poms_09", prompt: "Me siento inquieto/a", subscaleId: "tension", isReversed: false),
        .init(id: "poms_10", prompt: "Estoy entusiasmado/a por mis metas", subscaleId: "vigor", isReversed: false),
        .init(id: "poms_11", prompt: "Me cuesta concentrarme por el cansancio", subscaleId: "fatigue", isReversed: false),
        .init(id: "poms_12", prompt: "Estoy respirando con calma", subscaleId: "calma", isReversed: false),
        .init(id: "poms_13", prompt: "Me siento bajo presión", subscaleId: "tension", isReversed: false),
        .init(id: "poms_14", prompt: "Me siento fuerte y listo/a", subscaleId: "vigor", isReversed: false),
        .init(id: "poms_15", prompt: "Siento pesadez en el cuerpo", subscaleId: "fatigue", isReversed: false),
        .init(id: "poms_16", prompt: "Estoy relajado/a", subscaleId: "calma", isReversed: false),
        .init(id: "poms_17", prompt: "Estoy ansioso/a por el próximo reto", subscaleId: "tension", isReversed: false),
        .init(id: "poms_18", prompt: "Me siento positivo/a", subscaleId: "vigor", isReversed: false),
        .init(id: "poms_19", prompt: "Mi mente está cansada", subscaleId: "fatigue", isReversed: false),
        .init(id: "poms_20", prompt: "Estoy centrado/a y presente", subscaleId: "calma", isReversed: false)
    ]
}

private enum IDEPDefinition {
    static let subscales: [AssessmentInstrument.Subscale] = [
        .init(id: "autoeficacia", title: "Autoeficacia", description: "Confianza en tus recursos personales."),
        .init(id: "regulacion", title: "Regulación emocional", description: "Capacidad para gestionar emociones."),
        .init(id: "apoyo", title: "Apoyo social", description: "Percepción del acompañamiento del entorno."),
        .init(id: "estres", title: "Estrés competitivo", description: "Presión percibida ante el desempeño.")
    ]

    static let items: [AssessmentInstrument.Item] = [
        .init(id: "idep_01", prompt: "Sé cómo adaptarme a situaciones difíciles", subscaleId: "autoeficacia", isReversed: false),
        .init(id: "idep_02", prompt: "Puedo mantener la calma bajo presión", subscaleId: "regulacion", isReversed: false),
        .init(id: "idep_03", prompt: "Cuento con personas que me apoyan", subscaleId: "apoyo", isReversed: false),
        .init(id: "idep_04", prompt: "Las competencias me generan mucha tensión", subscaleId: "estres", isReversed: false),
        .init(id: "idep_05", prompt: "Confío en mis decisiones bajo presión", subscaleId: "autoeficacia", isReversed: false),
        .init(id: "idep_06", prompt: "Identifico mis emociones fácilmente", subscaleId: "regulacion", isReversed: false),
        .init(id: "idep_07", prompt: "Mi entorno conoce mis objetivos deportivos", subscaleId: "apoyo", isReversed: false),
        .init(id: "idep_08", prompt: "Pienso demasiado en posibles errores", subscaleId: "estres", isReversed: false),
        .init(id: "idep_09", prompt: "Tengo herramientas mentales para enfocarme", subscaleId: "autoeficacia", isReversed: false),
        .init(id: "idep_10", prompt: "Soy capaz de respirar y bajar pulsaciones", subscaleId: "regulacion", isReversed: false),
        .init(id: "idep_11", prompt: "Mis entrenadores me brindan soporte emocional", subscaleId: "apoyo", isReversed: false),
        .init(id: "idep_12", prompt: "Antes de competir siento pensamientos intrusivos", subscaleId: "estres", isReversed: false),
        .init(id: "idep_13", prompt: "Confío en que puedo mejorar siempre", subscaleId: "autoeficacia", isReversed: false),
        .init(id: "idep_14", prompt: "Puedo recuperar el foco cuando me distraigo", subscaleId: "regulacion", isReversed: false),
        .init(id: "idep_15", prompt: "Me siento acompañado/a en mi proceso deportivo", subscaleId: "apoyo", isReversed: false),
        .init(id: "idep_16", prompt: "Me preocupa decepcionar a los demás", subscaleId: "estres", isReversed: false),
        .init(id: "idep_17", prompt: "Tengo estrategias para gestionar el estrés", subscaleId: "autoeficacia", isReversed: false),
        .init(id: "idep_18", prompt: "Identifico cuando mis emociones me desbordan", subscaleId: "regulacion", isReversed: false),
        .init(id: "idep_19", prompt: "Mi familia entiende mis metas deportivas", subscaleId: "apoyo", isReversed: false),
        .init(id: "idep_20", prompt: "Me cuesta dormir antes de momentos importantes", subscaleId: "estres", isReversed: false),
        .init(id: "idep_21", prompt: "Puedo motivarme incluso después de fallar", subscaleId: "autoeficacia", isReversed: false),
        .init(id: "idep_22", prompt: "Soy consciente de la tensión en mi cuerpo", subscaleId: "regulacion", isReversed: false),
        .init(id: "idep_23", prompt: "Sé a quién acudir cuando necesito ayuda", subscaleId: "apoyo", isReversed: false),
        .init(id: "idep_24", prompt: "Temo perder oportunidades si no destaco", subscaleId: "estres", isReversed: false),
        .init(id: "idep_25", prompt: "Aprendo rápido de mis errores mentales", subscaleId: "autoeficacia", isReversed: false),
        .init(id: "idep_26", prompt: "Uso técnicas para equilibrar mis emociones", subscaleId: "regulacion", isReversed: false),
        .init(id: "idep_27", prompt: "Mis compañeros me alientan cuando lo necesito", subscaleId: "apoyo", isReversed: false),
        .init(id: "idep_28", prompt: "Las expectativas externas me presionan", subscaleId: "estres", isReversed: false)
    ]
}

private enum SelfEsteemDefinition {
    static let subscales: [AssessmentInstrument.Subscale] = [
        .init(id: "autoestima", title: "Autoestima global", description: "Valoración general del propio valor.")
    ]

    static let items: [AssessmentInstrument.Item] = [
        .init(id: "self_01", prompt: "Me siento una persona valiosa, al menos en igual medida que los demás", subscaleId: "autoestima", isReversed: false),
        .init(id: "self_02", prompt: "Siento que tengo cualidades positivas", subscaleId: "autoestima", isReversed: false),
        .init(id: "self_03", prompt: "En general me inclino a pensar que soy un fracasado/a", subscaleId: "autoestima", isReversed: true),
        .init(id: "self_04", prompt: "Soy capaz de hacer las cosas tan bien como la mayoría", subscaleId: "autoestima", isReversed: false),
        .init(id: "self_05", prompt: "Siento que no tengo mucho de lo que estar orgulloso/a", subscaleId: "autoestima", isReversed: true),
        .init(id: "self_06", prompt: "Tengo una actitud positiva hacia mí mismo/a", subscaleId: "autoestima", isReversed: false),
        .init(id: "self_07", prompt: "En general estoy satisfecho/a conmigo mismo/a", subscaleId: "autoestima", isReversed: false),
        .init(id: "self_08", prompt: "Me gustaría valorarme más", subscaleId: "autoestima", isReversed: true),
        .init(id: "self_09", prompt: "A veces siento que no sirvo para nada", subscaleId: "autoestima", isReversed: true),
        .init(id: "self_10", prompt: "Me considero digno/a de respeto", subscaleId: "autoestima", isReversed: false)
    ]
}
