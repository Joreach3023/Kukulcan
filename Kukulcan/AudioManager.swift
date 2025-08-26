import Foundation
import AVFoundation

final class AudioManager {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?

    enum Track: String {
        case home
        case collection
        case combat
    }

    func play(_ track: Track, volume: Float = 0.25) {
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "mp3") else {
            print("Missing sound file: \(track.rawValue).mp3")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = volume
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Audio playback failed: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
