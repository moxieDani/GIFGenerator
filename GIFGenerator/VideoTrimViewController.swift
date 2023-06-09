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

extension DDThumbnailMaker {
    var fullRange: CMTimeRange {
        return CMTimeRange(start: .zero, duration: (self.videoInfo.duration != nil) ? self.videoInfo.duration : .zero)
    }
    func trimmedComposition(_ range: CMTimeRange) async -> AVAsset {
        guard CMTimeRangeEqual(fullRange, range) == false else {return self.avAsset}

        let preferredTransform = try! await self.videoInfo.videoTracks.first!.load(.preferredTransform)
        let composition = AVMutableComposition()
        try? await composition.insertTimeRange(range, of: self.avAsset, at: .zero)
        
        composition.tracks.forEach {$0.preferredTransform = preferredTransform}

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

    private let availableFrameRates = [5, 10, 15, 20, 24, 25, 30, 60]
    private var wasPlaying = false
    private var player: AVPlayer! {playerController.player}
    private var asset: AVAsset!
    private var filter: PHPickerFilter!
    private var thumbnailMaker: DDThumbnailMaker! = nil
    private var targetFrameRate: Float! {
        didSet {
            if let closest = availableFrameRates.min(by: { abs($0 - Int(round(targetFrameRate))) < abs($1 - Int(round(targetFrameRate))) }) {
                let attributedString = NSMutableAttributedString(string: "\(closest)\nFPS")
                let range = NSRange(location: attributedString.string.count - 3, length: 3)
                attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 10), range: range)
                self.frameRateButton.setAttributedTitle(attributedString, for: .normal)
            }
            self.thumbnailMaker.targetFrameRate = targetFrameRate
            updateTrimmerController()
        }
    }
    
    private let frameEditorButton = UIButton()
    private let frameRateButton = UIButton()

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
        config.filter = self.filter
        
        let pickerViewController = PHPickerViewController(configuration: config)
        pickerViewController.delegate = self
        self.present(pickerViewController, animated: true, completion: nil)
    }
    
    @objc private func showFrameEditorViewController() {
        player.pause()
        
        thumbnailMaker.intervalFrame = 1
        thumbnailMaker.thumbnailImageSize = CGSize(width: 480, height: 270)
        thumbnailMaker.targetDuration = trimmer.selectedRange
        
        let rootVC = FrameEditorViewController(thumbnailMaker)
        self.navigationController?.pushViewController(rootVC, animated: true)
    }
    
    @objc func showFrameRateDialogue() {
        // create alert controller
        let alertController = UIAlertController(title: "Choose Frame Rate", message: nil, preferredStyle: .actionSheet)
        
        // add buttons to the alert controller
        let orgFrameRate = Int(round(self.thumbnailMaker.videoInfo.frameRate))
        let maxFrameRate = (availableFrameRates.min(by: { abs($0 - orgFrameRate) < abs($1 - orgFrameRate) }))!

        for rate in availableFrameRates {
            let action = UIAlertAction(title: "\(rate) FPS", style: .default) { _ in
                self.targetFrameRate = Float(rate)
            }
            
            if maxFrameRate >= rate {
                alertController.addAction(action)
            }
        }
        
        // add cancel button to the alert controller
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        // present alert controller
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.frameEditorButton
            popoverController.sourceRect = self.frameEditorButton.bounds
        }
        present(alertController, animated: true, completion: nil)
    }

    // MARK: - Private
    private func updateLabels() {
        leadingTrimLabel.text = trimmer.selectedRange.start.displayString
        currentTimeLabel.text = trimmer.progress.displayString
        trailingTrimLabel.text = trimmer.selectedRange.end.displayString
    }

    private func updatePlayerAsset() {
        let outputRange = trimmer.trimmingState == .none ? trimmer.selectedRange : thumbnailMaker.fullRange
        Task{
            let trimmedAsset = await thumbnailMaker.trimmedComposition(outputRange)
            if trimmedAsset != player.currentItem?.asset {
                player.replaceCurrentItem(with: AVPlayerItem(asset: trimmedAsset))
            }
        }
    }
    
    private func showPlayerController() {
        // AVPlayer settings.
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
        trimmer.thumbView.updateColor(color: UIColor.darkGray)
        trimmer.minimumDuration = CMTime(seconds: 0.5, preferredTimescale: 600)
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
        trimmer.stopPanningcompletion = { [self] in
            let availableDurationSec = DeviceInfo.availableDurationSec(frameRate: targetFrameRate)
            trimmer.thumbView.updateColor(color: trimmer.selectedRange.duration.seconds <= availableDurationSec ? UIColor.systemYellow : UIColor.darkGray)
            updateFrameEditorButton()
        }

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
        updateThumbnailMaker()
        
        let availableDurationSec = min(DeviceInfo.availableDurationSec(frameRate: targetFrameRate == nil ? thumbnailMaker.videoInfo.frameRate : targetFrameRate), trimmer.selectedRange.end.seconds)
        trimmer.selectedRange = CMTimeRange(start: .zero, end: CMTime(seconds: Double(availableDurationSec), preferredTimescale: CMTimeScale(NSEC_PER_MSEC)))
        trimmer.thumbView.updateColor(color: trimmer.selectedRange.duration.seconds <= availableDurationSec ? UIColor.systemYellow : UIColor.darkGray)
        
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
    
    private func updateThumbnailMaker() {
        if thumbnailMaker == nil {
            thumbnailMaker = DDThumbnailMaker(asset)
        } else {
            thumbnailMaker.avAsset = asset
        }
    }
    
    private func showFrameEditorButton() {
        self.frameEditorButton.setTitle("Create Image Frames", for: .normal)
        self.frameEditorButton.setTitleColor(.darkGray, for: .normal)
        self.frameEditorButton.backgroundColor = .lightGray
        self.frameEditorButton.frame = CGRect(x: self.view.safeAreaInsets.left, y: view.frame.height - 100, width: self.view.frame.width, height: 100)
        self.frameEditorButton.isEnabled = false
        self.frameEditorButton.addTarget(self, action: #selector(showFrameEditorViewController), for: .touchUpInside)
        self.view.addSubview(self.frameEditorButton)
    }
    
    private func updateFrameEditorButton() {
        let availableDurationSec = DeviceInfo.availableDurationSec(frameRate: targetFrameRate == nil ? thumbnailMaker.videoInfo.frameRate : targetFrameRate)
        if trimmer.selectedRange.duration.seconds <= availableDurationSec {
            self.frameEditorButton.backgroundColor = .systemYellow
            self.frameEditorButton.setTitleColor(.black, for: .normal)
            self.frameEditorButton.isEnabled = true
        } else {
            self.frameEditorButton.setTitleColor(.darkGray, for: .normal)
            self.frameEditorButton.backgroundColor = .lightGray
            self.frameEditorButton.isEnabled = false
        }
    }
    
    private func showTargetFrameRateButton() {
        self.frameRateButton.frame = CGRect(x: (view.frame.width/2) - 25, y: self.frameEditorButton.frame.minY - 100, width: 50, height: 50)
        self.frameRateButton.backgroundColor = .systemYellow
        
        self.frameRateButton.titleLabel?.numberOfLines = 2
        self.frameRateButton.titleLabel?.lineBreakMode = .byTruncatingTail
        self.frameRateButton.titleLabel?.textAlignment = .center
        self.frameRateButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        self.frameRateButton.titleLabel?.adjustsFontSizeToFitWidth = true
        self.frameRateButton.titleLabel?.minimumScaleFactor = 0.5 // 글꼴 축소 최소 비율
        
        self.frameRateButton.layer.borderWidth = 2.0
        self.frameRateButton.layer.borderColor = UIColor.darkGray.cgColor
        self.frameRateButton.layer.cornerRadius = self.frameRateButton.frame.width / 2
        self.frameRateButton.clipsToBounds = true
        self.frameRateButton.isHidden = true
        self.frameRateButton.addTarget(self, action: #selector(showFrameRateDialogue), for: .touchUpInside)
        self.view.addSubview(self.frameRateButton)
    }
    
    private func updateTargetFrameRate(_ frameRate:Float) {
        self.targetFrameRate = frameRate
        self.frameRateButton.isHidden = false
    }
    
    private func showNormalVideoFromPHPicker(_ provider: NSItemProvider) {
        LoadingIndicator.showLoading()
        provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { (videoURL, error) in
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: [:]) { (videoURL, error) in
                DispatchQueue.main.async {
                    if let url = videoURL as? URL {
                        self.updatePlayerController(url)
                        self.updateTrimmerController()
                        self.updateFrameEditorButton()
                        self.updateTargetFrameRate(self.thumbnailMaker.videoInfo.frameRate)
                    }
                    LoadingIndicator.hideLoading()
                }
            }
        }
    }
    
    private func showLivePhotoVideoFromPHPicker(_ provider: NSItemProvider) {
        LoadingIndicator.showLoading()
        if provider.canLoadObject(ofClass: PHLivePhoto.self) {
            provider.loadObject(ofClass: PHLivePhoto.self, completionHandler: { (livePhoto, error) in
                // Get PHLivePhoto object and get PHAssetResource.
                if let livePhoto = livePhoto as? PHLivePhoto {
                    let resources = PHAssetResource.assetResources(for: livePhoto)
                    for resource in resources {
                        if resource.type == .pairedVideo {
                            // Set destination path to copy the video of live photo
                            let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let destinationURL = documentsDirectoryURL.appendingPathComponent("temp-live-photo-video.mov")
                            
                            do {
                                if FileManager.default.fileExists(atPath: destinationURL.path) {
                                    try FileManager.default.removeItem(atPath: destinationURL.path)
                                }
                            } catch {
                                print(error.localizedDescription)
                            }

                            // Copy the video of live photo to destination path.
                            let options = PHAssetResourceRequestOptions()
                            PHAssetResourceManager.default().writeData(for: resource, toFile: destinationURL, options: options) { (error) in
                                if error == nil {
                                    DispatchQueue.main.async {
                                        self.updatePlayerController(destinationURL)
                                        self.updateTrimmerController()
                                        self.updateFrameEditorButton()
                                        self.updateTargetFrameRate(self.thumbnailMaker.videoInfo.frameRate)
                                        LoadingIndicator.hideLoading()
                                    }
                                }
                            }
                        }
                    }
                }
            })
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let provider = results.first?.itemProvider else { return }
        if self.filter == .videos {
            self.showNormalVideoFromPHPicker(provider)
        } else if self.filter == .livePhotos {
            self.showLivePhotoVideoFromPHPicker(provider)
        }
    }
    
    // MARK: - override
    init(_ filter: PHPickerFilter) {
        self.filter = filter
        self.asset = AVURLAsset(url: URL(fileURLWithPath: ""), options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemGray
        self.title = "Trim Video"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(dismissSelf))
        self.navigationItem.leftBarButtonItem?.tintColor = .systemYellow
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "film.fill"), style: .plain, target: self, action: #selector(showVideoPickerView))
        self.navigationItem.rightBarButtonItem?.tintColor = .systemYellow

        self.showPlayerController()
        self.showTrimmerController()
        self.showVideoPickerView()
        self.showFrameEditorButton()
        self.showTargetFrameRateButton()
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
