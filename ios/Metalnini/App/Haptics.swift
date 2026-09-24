import CoreHaptics
import UIKit
import MetalniniKit

/// Retour haptique natif (Core Haptics), avec repli sur les générateurs UIKit si le moteur n'est pas disponible.
/// Plus la carte est rare, plus le retour est long et appuyé.
@MainActor
final class Haptics {
    static let shared = Haptics()
    private var engine: CHHapticEngine?
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in Task { @MainActor in try? self?.engine?.start() } }
        try? engine?.start()
    }

    /// Petits crans pendant la déchirure.
    func tick() { selection.selectionChanged() }

    func tear() { play([.transient(0, 0.9, 0.8), .continuous(0.02, 0.18, 0.5, 0.3)], fallback: .heavy) }

    func flip() { play([.transient(0, 0.45, 0.6)], fallback: .light) }

    func toss() { play([.transient(0, 0.3, 0.9)], fallback: .soft) }

    func land() { play([.transient(0, 0.5, 0.5)], fallback: .medium) }

    func reveal(_ rarity: Rarity) {
        switch rarity {
        case .commune: play([.transient(0, 0.4, 0.4)], fallback: .light)
        case .rare: play([.transient(0, 0.6, 0.5), .transient(0.12, 0.7, 0.6)], fallback: .medium)
        case .holo: play([.transient(0, 0.6, 0.7), .transient(0.1, 0.7, 0.7), .transient(0.2, 0.9, 0.8)], fallback: .medium)
        case .signature: play([.transient(0, 0.9, 0.6), .continuous(0.05, 0.5, 0.6, 0.35), .transient(0.45, 1, 0.8)], fallback: .heavy)
        case .legendaire: play([.transient(0, 1, 0.4), .continuous(0.04, 0.9, 0.9, 0.2), .continuous(0.25, 0.8, 1, 0.3), .transient(0.6, 1, 1)], fallback: .heavy)
        }
    }

    enum Event {
        case transient(TimeInterval, Float, Float)                    // instant, intensité, netteté
        case continuous(TimeInterval, TimeInterval, Float, Float)     // instant, durée, intensité, netteté
    }

    private func play(_ events: [Event], fallback: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard let engine else { UIImpactFeedbackGenerator(style: fallback).impactOccurred(); return }
        let hapticEvents = events.map { e -> CHHapticEvent in
            switch e {
            case let .transient(t, i, s):
                CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: i), .init(parameterID: .hapticSharpness, value: s)], relativeTime: t)
            case let .continuous(t, d, i, s):
                CHHapticEvent(eventType: .hapticContinuous, parameters: [.init(parameterID: .hapticIntensity, value: i), .init(parameterID: .hapticSharpness, value: s)], relativeTime: t, duration: d)
            }
        }
        do { try engine.makePlayer(with: CHHapticPattern(events: hapticEvents, parameters: [])).start(atTime: CHHapticTimeImmediate) }
        catch { UIImpactFeedbackGenerator(style: fallback).impactOccurred() }
    }
}
