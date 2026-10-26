import AVFoundation

/// A short beep-beep-beep for when a timer runs out. The tone is generated
/// in code, so there's no sound file to bundle.
@MainActor
final class Beep {
    static let shared = Beep()

    private var player: AVAudioPlayer?

    func play() {
        let session = AVAudioSession.sharedInstance()
        do {
            #if os(iOS)
            // Playback rings even with the silent switch on, and ducking
            // turns music down for the beep instead of stopping it.
            try session.setCategory(.playback, options: [.duckOthers])
            #else
            try session.setCategory(.playback, options: [.mixWithOthers])
            #endif
            try session.setActive(true)
            let player = try AVAudioPlayer(data: Self.sound)
            player.play()
            self.player = player
            // Let other audio come back up once the beep is over.
            let wait = UInt64((player.duration + 0.1) * 1_000_000_000)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: wait)
                guard let self, self.player === player else { return }
                self.player = nil
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch {
            // The haptic still fires, so a missing beep isn't worth surfacing.
        }
    }

    /// Three 0.12 s beeps at 1 kHz as a 16-bit mono WAV.
    private static let sound: Data = {
        let rate = 44_100
        let frequency = 1_000.0
        let on = Int(0.12 * Double(rate))
        let off = Int(0.08 * Double(rate))
        let fade = Int(0.005 * Double(rate))

        var samples: [Int16] = []
        for _ in 0..<3 {
            for i in 0..<on {
                // Fade the edges so the beep doesn't click.
                let envelope = min(1, Double(min(i, on - i)) / Double(fade))
                let value = sin(2 * .pi * frequency * Double(i) / Double(rate)) * envelope * 0.7
                samples.append(Int16(value * Double(Int16.max)))
            }
            samples.append(contentsOf: repeatElement(0, count: off))
        }

        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let byteCount = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1)) // PCM
        append(UInt16(1)) // mono
        append(UInt32(rate))
        append(UInt32(rate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(byteCount))
        samples.forEach { append($0) }
        return data
    }()
}
