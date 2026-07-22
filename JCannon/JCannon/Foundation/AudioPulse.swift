//
//  AudioPulse.swift
//  JCannon
//
//  Synthesised sound. No audio files ship with the app — every cue is generated
//  as a short PCM buffer at launch and played through an AVAudioEngine graph.
//

import AVFoundation

/// Named short cues referenced by gameplay code. Kept as an enum so callers never
/// pass raw strings.
enum SoundCue {
    case launch
    case hitWood
    case hitStone
    case explosion
    case combo
    case bossHit
    case victory
    case defeat
    case uiTap
}

/// Generates and plays procedural sound effects. All buffers are pre-rendered
/// once; playback just re-triggers a per-cue player node.
final class AudioPulse {

    static let shared = AudioPulse()

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [PlayerBox] = []
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var enabled = true

    private final class PlayerBox {
        let node = AVAudioPlayerNode()
        var busy = false
    }

    private init() {}

    // MARK: - Lifecycle

    func boot() {
        configureSession()
        // A small pool of player nodes lets overlapping cues play simultaneously.
        for _ in 0..<8 {
            let box = PlayerBox()
            engine.attach(box.node)
            engine.connect(box.node, to: engine.mainMixerNode, format: format)
            players.append(box)
        }
        prerender()
        do {
            try engine.start()
        } catch {
            enabled = false
        }
    }

    func setEnabled(_ on: Bool) {
        enabled = on
    }

    // MARK: - Playback

    func play(_ cue: SoundCue) {
        guard enabled, engine.isRunning, let buffer = buffers[key(for: cue)] else { return }
        guard let box = players.first(where: { !$0.busy }) ?? players.first else { return }
        box.busy = true
        box.node.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak box] in
            box?.busy = false
        }
        box.node.play()
    }

    // MARK: - Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    // MARK: - Synthesis

    private func prerender() {
        buffers[key(for: .launch)]    = renderLaunch()
        buffers[key(for: .hitWood)]   = renderThud(base: 220, decay: 14, noise: 0.35, duration: 0.18)
        buffers[key(for: .hitStone)]  = renderThud(base: 90, decay: 9, noise: 0.6, duration: 0.28)
        buffers[key(for: .explosion)] = renderExplosion()
        buffers[key(for: .combo)]     = renderArpeggio(notes: [523, 659, 784], step: 0.06)
        buffers[key(for: .bossHit)]   = renderThud(base: 70, decay: 6, noise: 0.5, duration: 0.4)
        buffers[key(for: .victory)]   = renderArpeggio(notes: [523, 659, 784, 1046], step: 0.11)
        buffers[key(for: .defeat)]    = renderArpeggio(notes: [392, 330, 262], step: 0.14)
        buffers[key(for: .uiTap)]     = renderBlip(freq: 880, duration: 0.05)
    }

    private func key(for cue: SoundCue) -> String {
        switch cue {
        case .launch: return "launch"
        case .hitWood: return "hitWood"
        case .hitStone: return "hitStone"
        case .explosion: return "explosion"
        case .combo: return "combo"
        case .bossHit: return "bossHit"
        case .victory: return "victory"
        case .defeat: return "defeat"
        case .uiTap: return "uiTap"
        }
    }

    private func makeBuffer(duration: Float, _ fill: (_ i: Int, _ t: Float, _ sr: Float) -> Float) -> AVAudioPCMBuffer {
        let sr = Float(format.sampleRate)
        let frames = AVAudioFrameCount(duration * sr)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let ptr = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Float(i) / sr
            ptr[i] = fill(i, t, sr) * 0.6
        }
        return buffer
    }

    private func renderLaunch() -> AVAudioPCMBuffer {
        // Descending "whoosh": pitch sweeps down, amplitude decays.
        return makeBuffer(duration: 0.22) { _, t, _ in
            let env = expf(-t * 10)
            let sweep = 700 - t * 1600
            return sinf(2 * .pi * max(sweep, 60) * t) * env
        }
    }

    private func renderThud(base: Float, decay: Float, noise: Float, duration: Float) -> AVAudioPCMBuffer {
        var rng = SeededRandom(seed: UInt64(base) &+ 7)
        return makeBuffer(duration: duration) { _, t, _ in
            let env = expf(-t * decay)
            let tone = sinf(2 * .pi * base * t)
            let n = rng.float(in: -1...1) * noise
            return (tone * (1 - noise) + n) * env
        }
    }

    private func renderExplosion() -> AVAudioPCMBuffer {
        var rng = SeededRandom(seed: 1337)
        return makeBuffer(duration: 0.45) { _, t, _ in
            let env = expf(-t * 6)
            let rumble = sinf(2 * .pi * (60 - t * 40) * t)
            let n = rng.float(in: -1...1)
            return (n * 0.7 + rumble * 0.3) * env
        }
    }

    private func renderArpeggio(notes: [Float], step: Float) -> AVAudioPCMBuffer {
        let total = step * Float(notes.count)
        return makeBuffer(duration: total + 0.15) { _, t, _ in
            let idx = min(Int(t / step), notes.count - 1)
            let local = t - Float(idx) * step
            let env = expf(-local * 8)
            return sinf(2 * .pi * notes[idx] * t) * env
        }
    }

    private func renderBlip(freq: Float, duration: Float) -> AVAudioPCMBuffer {
        return makeBuffer(duration: duration) { _, t, _ in
            let env = expf(-t * 30)
            return sinf(2 * .pi * freq * t) * env
        }
    }
}
