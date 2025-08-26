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

    func play(_ track: Track) {
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "wav") else {
            print("Missing sound file: \(track.rawValue).wav")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
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
