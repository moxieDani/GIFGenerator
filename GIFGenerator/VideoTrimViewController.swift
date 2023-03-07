//
//  VideoTrimViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/15.
//

import UIKit
import AVKit
import PhotosUI

extension CMTime {
    var displayString: String {
        let offset = TimeInterval(seconds)
        let numberOfNanosecondsFloat = (offset - TimeInterval(Int(offset))) * 1000.0
        let nanoseconds = Int(numberOfNanosecondsFloat)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return String(format: "%@.%03d", formatter.string(from: offset) ?? "00:00", nanoseconds)
    }
}

extension AVAsset {
    var fullRange: CMTimeRange {
        return CMTimeRange(start: .zero, duration: duration)
    }
    func trimmedComposition(_ range: CMTimeRange) -> AVAsset {
        guard CMTimeRangeEqual(fullRange, range) == false else {return self}

        let composition = AVMutableComposition()
        try? composition.insertTimeRange(range, of: self, at: .zero)

        if let videoTrack = tracks(withMediaType: .video).first {
            composition.tracks.forEach {$0.preferredTransform = videoTrack.preferredTransform}
        }
        return composition
    }
}

class VideoTrimViewController: UIViewController, PHPickerViewControllerDelegate {

    let playerController = AVPlayerViewController()
    var trimmer: VideoTrimmer!
    var timingStackView: UIStackView!
    var leadingTrimLabel: UILabel!
    var currentTimeLabel: UILabel!
    var trailingTrimLabel: UILabel!

    private var wasPlaying = false
    private var player: AVPlayer! {playerController.player}
    private var asset: AVAsset!
    private var filter: PHPickerFilter!

    // MARK: - Input
    @objc private func didBeginTrimming(_ sender: VideoTrimmer) {
        updateLabels()

        wasPlaying = (player.timeControlStatus != .paused)
        player.pause()

        updatePlayerAsset()
    }

    @objc private func didEndTrimming(_ sender: VideoTrimmer) {
        updateLabels()

        if wasPlaying == true {
            player.play()
        }

        updatePlayerAsset()
    }

    @objc private func selectedRangeDidChanged(_ sender: VideoTrimmer) {
        updateLabels()
    }

    @objc private func didBeginScrubbing(_ sender: VideoTrimmer) {
        updateLabels()

        wasPlaying = (player.timeControlStatus != .paused)
        player.pause()
    }

    @objc private func didEndScrubbing(_ sender: VideoTrimmer) {
        updateLabels()

        if wasPlaying == true {
            player.play()
        }
    }

    @objc private func progressDidChanged(_ sender: VideoTrimmer) {
        updateLabels()

        let time = CMTimeSubtract(trimmer.progress, trimmer.selectedRange.start)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func showVideoPickerView() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        config.filter = .videos
        
        let pickerViewController = PHPickerViewController(configuration: config)
        pickerViewController.delegate = self
        self.present(pickerViewController, animated: true, completion: nil)
    }

    // MARK: - Private
    private func updateLabels() {
        leadingTrimLabel.text = trimmer.selectedRange.start.displayString
        currentTimeLabel.text = trimmer.progress.displayString
        trailingTrimLabel.text = trimmer.selectedRange.end.displayString
    }

    private func updatePlayerAsset() {
        let outputRange = trimmer.trimmingState == .none ? trimmer.selectedRange : asset.fullRange
        let trimmedAsset = asset.trimmedComposition(outputRange)
        if trimmedAsset != player.currentItem?.asset {
            player.replaceCurrentItem(with: AVPlayerItem(asset: trimmedAsset))
        }
    }
    
    private func showPlayerController(_ url: URL) {
        // AVPlayer & Asset settings.
        asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

        playerController.player = AVPlayer()
        addChild(playerController)
        view.addSubview(playerController.view)
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerController.view.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 1080 / 1920)
        ])
    }
    
    private func updatePlayerController(_ url: URL) {
        asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        playerController.player = AVPlayer(url: url)
    }
    
    private func showTrimmerController() {
        // THIS IS WHERE WE SETUP THE VIDEOTRIMMER:
        trimmer = VideoTrimmer()
        trimmer.minimumDuration = CMTime(seconds: 1, preferredTimescale: 600)
        trimmer.addTarget(self, action: #selector(didBeginTrimming(_:)), for: VideoTrimmer.didBeginTrimming)
        trimmer.addTarget(self, action: #selector(didEndTrimming(_:)), for: VideoTrimmer.didEndTrimming)
        trimmer.addTarget(self, action: #selector(selectedRangeDidChanged(_:)), for: VideoTrimmer.selectedRangeChanged)
        trimmer.addTarget(self, action: #selector(didBeginScrubbing(_:)), for: VideoTrimmer.didBeginScrubbing)
        trimmer.addTarget(self, action: #selector(didEndScrubbing(_:)), for: VideoTrimmer.didEndScrubbing)
        trimmer.addTarget(self, action: #selector(progressDidChanged(_:)), for: VideoTrimmer.progressChanged)
        view.addSubview(trimmer)
        trimmer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trimmer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            trimmer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            trimmer.topAnchor.constraint(equalTo: playerController.view.bottomAnchor, constant: 16),
            trimmer.heightAnchor.constraint(equalToConstant: 50),
        ])

        leadingTrimLabel = UILabel()
        leadingTrimLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        leadingTrimLabel.textAlignment = .left

        currentTimeLabel = UILabel()
        currentTimeLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        currentTimeLabel.textAlignment = .center

        trailingTrimLabel = UILabel()
        trailingTrimLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        trailingTrimLabel.textAlignment = .right

        timingStackView = UIStackView(arrangedSubviews: [leadingTrimLabel, currentTimeLabel, trailingTrimLabel])
        timingStackView.axis = .horizontal
        timingStackView.alignment = .fill
        timingStackView.distribution = .fillEqually
        timingStackView.spacing = UIStackView.spacingUseSystem
        view.addSubview(timingStackView)
        timingStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timingStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            timingStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            timingStackView.topAnchor.constraint(equalTo: trimmer.bottomAnchor, constant: 8),
        ])

        trimmer.asset = asset
        updatePlayerAsset()

        player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self = self else {return}
            // when we're not trimming, the players starting point is actual later than the trimmer,
            // (because the vidoe has been trimmed), so we need to account for that.
            // When we're trimming, we always show the full video
            let finalTime = self.trimmer.trimmingState == .none ? CMTimeAdd(time, self.trimmer.selectedRange.start) : time
            self.trimmer.progress = finalTime
        }

        updateLabels()
    }
    
    private func updateTrimmerController() {
        trimmer.asset = asset
        updatePlayerAsset()

        player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self = self else {return}
            // when we're not trimming, the players starting point is actual later than the trimmer,
            // (because the vidoe has been trimmed), so we need to account for that.
            // When we're trimming, we always show the full video
            let finalTime = self.trimmer.trimmingState == .none ? CMTimeAdd(time, self.trimmer.selectedRange.start) : time
            self.trimmer.progress = finalTime
        }

        updateLabels()
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let provider = results.first?.itemProvider else { return }
        if self.filter == .videos {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { (videoURL, error) in
                provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: [:]) { (videoURL, error) in
                    DispatchQueue.main.async {
                        if let url = videoURL as? URL {
                            print(url)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - override
    init(_ filter: PHPickerFilter) {
        self.filter = filter
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        
        self.title = "Trim Video"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(dismissSelf))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Pick", style: .plain, target: self, action: #selector(showVideoPickerView))

        showVideoPickerView()

        self.showPlayerController(URL(fileURLWithPath: ""))
        self.showTrimmerController()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
