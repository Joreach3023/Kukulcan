import Foundation
import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    enum Track: String {
        case home
        case collection
        case combat
    }

    var fadeOutDuration: TimeInterval = 0.35
    var fadeInDuration: TimeInterval = 0.45
    var defaultVolume: Float = 0.25

    private var player: AVAudioPlayer?
    private var currentTrackName: String?
    private var pendingTrackName: String?
    private var pendingStartWorkItem: DispatchWorkItem?

    private init() {}

    func play(_ track: Track, volume: Float? = nil) {
        transitionToMusic(named: track.rawValue, volume: volume)
    }

    func transitionToMusic(named trackName: String,
                           fadeOutDuration: TimeInterval? = nil,
                           fadeInDuration: TimeInterval? = nil,
                           volume: Float? = nil) {
        let outDuration = max(0, fadeOutDuration ?? self.fadeOutDuration)
        let inDuration = max(0, fadeInDuration ?? self.fadeInDuration)
        let targetVolume = max(0, min(1, volume ?? defaultVolume))

        // Évite de relancer la même piste déjà en cours
        if currentTrackName == trackName, player?.isPlaying == true {
            pendingTrackName = nil
            pendingStartWorkItem?.cancel()
            pendingStartWorkItem = nil
            return
        }

        pendingTrackName = trackName
        pendingStartWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pendingTrackName == trackName else { return }
            self.startTrack(named: trackName, targetVolume: targetVolume, fadeInDuration: inDuration)
        }
        pendingStartWorkItem = workItem

        guard let player else {
            DispatchQueue.main.async(execute: workItem)
            return
        }

        if outDuration > 0 {
            player.setVolume(0, fadeDuration: outDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + outDuration) { [weak self] in
                guard let self else { return }
                guard self.pendingTrackName == trackName else { return }
                player.stop()
                self.player = nil
                self.currentTrackName = nil
                workItem.perform()
            }
        } else {
            player.stop()
            self.player = nil
            self.currentTrackName = nil
            DispatchQueue.main.async(execute: workItem)
        }
    }

    func stop() {
        pendingTrackName = nil
        pendingStartWorkItem?.cancel()
        pendingStartWorkItem = nil
        player?.stop()
        player = nil
        currentTrackName = nil
    }

    private func startTrack(named trackName: String,
                            targetVolume: Float,
                            fadeInDuration: TimeInterval) {
        guard let url = Bundle.main.url(forResource: trackName, withExtension: "mp3") else {
            print("Missing sound file: \(trackName).mp3")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 0
            newPlayer.prepareToPlay()
            newPlayer.play()

            player = newPlayer
            currentTrackName = trackName
            pendingTrackName = nil

            if fadeInDuration > 0 {
                newPlayer.setVolume(targetVolume, fadeDuration: fadeInDuration)
            } else {
                newPlayer.volume = targetVolume
            }
        } catch {
            print("Audio playback failed: \(error)")
        }
    }
}
