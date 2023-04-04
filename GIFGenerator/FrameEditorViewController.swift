//
//  FrameEditorViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/17.
//

import UIKit
import ImageIO
import UniformTypeIdentifiers
import CoreMedia

class FrameEditorViewController: UIViewController {
    private var thumbnailMaker: DDThumbnailMaker! = nil
    private var imageFrames = [UIImage]()
    private let imageView = UIImageView()
    private let playPauseButton = UIButton()
    private let playModeButton = UIButton()
    private let frameRateButton = UIButton()
    private let imageFrameDelaySlider = UISlider()
    private let imageFrameDelayUpButton = UIButton()
    private let imageFrameDelayDownButton = UIButton()
    private var imageFrameDelay: Double! = 0.0
    
    private let availableFrameRates = [5, 10, 15, 20, 24, 25, 30, 60]
    private var targetFrameRate: Float! = 0 {
        didSet {
            if let closest = self.availableFrameRates.min(by: { abs($0 - Int(round(targetFrameRate))) < abs($1 - Int(round(targetFrameRate))) }) {
                let attributedString = NSMutableAttributedString(string: "\(closest)\nFPS")
                let range = NSRange(location: attributedString.string.count - 3, length: 3)
                attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 10), range: range)
                self.frameRateButton.setAttributedTitle(attributedString, for: .normal)
            }
            
            if self.thumbnailMaker != nil && self.thumbnailMaker.targetFrameRate != targetFrameRate {
                let availableDurationSec = DeviceInfo.availableDurationSec(frameRate: targetFrameRate)
                self.thumbnailMaker.targetFrameRate = targetFrameRate
                self.thumbnailMaker.targetDuration = CMTimeRange(start: self.thumbnailMaker.targetDuration.start,
                                                                 end: CMTime(seconds: availableDurationSec, preferredTimescale: CMTimeScale(NSEC_PER_MSEC)))
                self.generateGifFrameImages(thumbnailMaker: self.thumbnailMaker)
            }
        }
    }

    @objc private func showOutputGifViewController() {
        let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let gifFilePath: URL! = documentsDirectoryURL.appendingPathComponent("test.gif")
        
        // Generate GIF file
        self.generateGif(filePath: gifFilePath)
        let rootVC = OutputGifViewController(gifFilePath!)
        self.navigationController?.pushViewController(rootVC, animated: true)
    }
    
    @objc private func pressPlayPauseButton() {
        if self.imageView.layer.speed == 1.0 {
            self.updatePauseUI()
        } else {
            self.updatePlayUI(animate: false)
        }
    }
    
    @objc private func pressPlayModeButton() {
        var image: UIImage! = nil
        if self.playModeButton.tag == 0 {
            image = UIImage(systemName: "arrow.left")
            self.playModeButton.tag = 1
        } else if self.playModeButton.tag == 1 {
            image = UIImage(systemName: "arrow.left.and.right")
            self.playModeButton.tag = 2
        } else {
            image = UIImage(systemName: "arrow.right")
            self.playModeButton.tag = 0
        }
        self.playModeButton.setImage(image, for: .normal)
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
            popoverController.sourceView = self.frameRateButton
            popoverController.sourceRect = self.frameRateButton.bounds
        }
        present(alertController, animated: true, completion: nil)
    }
    
    @objc func sliderValueChanged(_ sender: UISlider) {
        self.updatePauseUI()
    }
    
    @objc func sliderTouchUp(_ sender: UISlider) {
        self.updatePlayUI(animate: true)
    }
    
    @objc func sliderValueUp(_ sender: UISlider) {
        self.imageFrameDelaySlider.value += 0.1
        self.updatePlayUI(animate:true)
    }
    
    @objc func sliderValueDown(_ sender: UISlider) {
        self.imageFrameDelaySlider.value -= 0.1
        self.updatePlayUI(animate:true)
    }
    
    init(_ thumbnailMaker: DDThumbnailMaker) {
        super.init(nibName: nil, bundle: nil)
        self.generateGifFrameImages(thumbnailMaker: thumbnailMaker)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updatePauseUI() {
        let layer = self.imageView.layer
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.timeOffset = pausedTime
        self.imageView.layer.speed = 0.0
        self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
    }
    
    private func updatePlayUI(animate:Bool) {
        let pausedTime = self.imageView.layer.timeOffset
        self.imageView.layer.speed = 1.0
        self.imageView.layer.timeOffset = 0.0
        self.imageView.layer.beginTime = 0.0
        let timeSincePause = self.imageView.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        self.imageView.layer.beginTime = timeSincePause
        self.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)

        if animate {
            self.imageView.animationDuration = TimeInterval(self.imageFrameDelaySlider.value)
            self.imageView.startAnimating()
        }
    }
    
    private func generateGifFrameImages(thumbnailMaker: DDThumbnailMaker) {
        LoadingIndicator.showLoading()
        if self.targetFrameRate == 0 {
            self.targetFrameRate = thumbnailMaker.targetFrameRate
        }
        
        var append_count = 0
        let maximumNumberOfImageFrame = DeviceInfo.getMaximumNumberOfImageFrame()
        var imageFrames = [UIImage]()
        thumbnailMaker.generate(
            imageHandler:{requestedTime, image, actualTime, result, error in
                if result == .succeeded && maximumNumberOfImageFrame > append_count {
                    imageFrames.append(UIImage(cgImage: image!))
                    append_count+=1
                }
            },
            completion: {
                self.thumbnailMaker = thumbnailMaker
                self.imageFrameDelaySlider.value = Float(imageFrames.count) / Float(thumbnailMaker.targetFrameRate)
                self.imageView.animationImages = imageFrames
                self.imageView.animationDuration = TimeInterval(self.imageFrameDelaySlider.value)
                self.imageView.startAnimating()
                self.imageFrames = imageFrames
                LoadingIndicator.hideLoading()
        })
    }
    
    private func generateGif(filePath: URL) {
        let fileProperties: CFDictionary = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]  as CFDictionary
        let frameProperties: CFDictionary = [kCGImagePropertyGIFDictionary as String: [(kCGImagePropertyGIFDelayTime as String): 1.0]] as CFDictionary
        
        do {
            if FileManager.default.fileExists(atPath: filePath.path) {
                try FileManager.default.removeItem(atPath: filePath.path)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        if let url = filePath as CFURL? {
            if let destination = CGImageDestinationCreateWithURL(url, UTType.gif.identifier as CFString, self.imageFrames.count, nil) {
                CGImageDestinationSetProperties(destination, fileProperties)
                for image in self.imageFrames {
                    autoreleasepool {
                        if let cgImage = image.cgImage {
                            CGImageDestinationAddImage(destination, cgImage, frameProperties)
                        }
                    }
                }
                if !CGImageDestinationFinalize(destination) {
                    print("Failed to finalize the image destination")
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Edit Frame"
        self.view.backgroundColor = .systemGray
        
        self.navigationController?.navigationBar.tintColor = .systemYellow
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down.fill"), style: .plain, target: self, action: #selector(showOutputGifViewController))
        self.navigationItem.rightBarButtonItem?.tintColor = .red
               
        self.imageView.frame = CGRect(x: self.view.safeAreaInsets.left,
                                      y: (self.navigationController?.navigationBar.frame.maxY)!,
                                      width: self.view.frame.width,
                                      height: self.view.frame.height * 0.5)
        self.imageView.backgroundColor = .black
        self.imageView.contentMode = .scaleAspectFit
        self.view.addSubview(self.imageView)
        
        self.playModeButton.frame = CGRect(x: self.view.frame.width/2 - 95,
                                              y: self.view.frame.height - 70,
                                              width: 50,
                                              height: 50)
        self.playModeButton.backgroundColor = .systemYellow
        self.playModeButton.tintColor = .black
        self.playModeButton.layer.cornerRadius = self.playModeButton.frame.width / 2
        self.playModeButton.layer.borderWidth = 2.0
        self.playModeButton.layer.borderColor = UIColor.darkGray.cgColor
        self.playModeButton.clipsToBounds = true
        self.playModeButton.setImage(UIImage(systemName: "arrow.right"), for: .normal)
        self.playModeButton.addTarget(self, action: #selector(pressPlayModeButton), for: .touchUpInside)
        self.view.addSubview(self.playModeButton)
        
        self.playPauseButton.frame = CGRect(x: self.view.frame.width/2 - 25,
                                              y: self.view.frame.height - 70,
                                              width: 50,
                                              height: 50)
        self.playPauseButton.backgroundColor = .systemYellow
        self.frameRateButton.titleLabel?.numberOfLines = 2
        self.playPauseButton.tintColor = .black
        self.playPauseButton.layer.cornerRadius = self.playPauseButton.frame.width / 2
        self.playPauseButton.layer.borderWidth = 2.0
        self.playPauseButton.layer.borderColor = UIColor.darkGray.cgColor
        self.playPauseButton.clipsToBounds = true
        self.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        self.playPauseButton.addTarget(self, action: #selector(pressPlayPauseButton), for: .touchUpInside)
        self.view.addSubview(self.playPauseButton)
        
        self.frameRateButton.frame = CGRect(x: self.view.frame.width/2 + 45,
                                              y: self.view.frame.height - 70,
                                              width: 50,
                                              height: 50)
        self.frameRateButton.backgroundColor = .systemYellow
        self.frameRateButton.layer.cornerRadius = 20
        self.frameRateButton.clipsToBounds = true
        self.frameRateButton.titleLabel?.lineBreakMode = .byTruncatingTail
        self.frameRateButton.titleLabel?.textAlignment = .center
        self.frameRateButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        self.frameRateButton.titleLabel?.adjustsFontSizeToFitWidth = true
        self.frameRateButton.titleLabel?.minimumScaleFactor = 0.5 // 글꼴 축소 최소 비율
        
        self.frameRateButton.layer.cornerRadius = self.frameRateButton.frame.width / 2
        self.frameRateButton.layer.borderWidth = 2.0
        self.frameRateButton.layer.borderColor = UIColor.darkGray.cgColor
        self.frameRateButton.addTarget(self, action: #selector(showFrameRateDialogue), for: .touchUpInside)
        self.view.addSubview(self.frameRateButton)
        
        self.imageFrameDelaySlider.frame = CGRect(x: 50, y: self.frameRateButton.frame.minY - 50, width: self.view.frame.width - 100, height: 30)
        self.imageFrameDelaySlider.minimumValue = 0.30
        self.imageFrameDelaySlider.maximumValue = 10.00
        self.imageFrameDelaySlider.value = self.imageFrameDelaySlider.minimumValue
        self.imageFrameDelaySlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        self.imageFrameDelaySlider.addTarget(self, action: #selector(sliderTouchUp(_:)), for: .touchUpInside)
        self.imageFrameDelaySlider.minimumTrackTintColor = .darkGray
        self.imageFrameDelaySlider.maximumTrackTintColor = .darkGray
        self.imageFrameDelaySlider.thumbTintColor = .systemYellow
        self.view.addSubview(self.imageFrameDelaySlider)
        
        self.imageFrameDelayUpButton.frame = CGRect(x: self.imageFrameDelaySlider.frame.minX - 50,
                                                    y: self.imageFrameDelaySlider.frame.minY - 10,
                                                    width: 50,
                                                    height: 50)
        self.imageFrameDelayUpButton.backgroundColor = .systemGray
        self.imageFrameDelayUpButton.tintColor = .systemYellow
        self.imageFrameDelayUpButton.setImage(UIImage(systemName: "hare.fill"), for: .normal)
        self.imageFrameDelayUpButton.addTarget(self, action: #selector(sliderValueDown(_:)), for: .touchUpInside)
        self.view.addSubview(self.imageFrameDelayUpButton)
        
        self.imageFrameDelayDownButton.frame = CGRect(x: self.imageFrameDelaySlider.frame.maxX,
                                                    y: self.imageFrameDelaySlider.frame.minY - 10,
                                                    width: 50,
                                                    height: 50)
        self.imageFrameDelayDownButton.backgroundColor = .systemGray
        self.imageFrameDelayDownButton.tintColor = .systemYellow
        self.imageFrameDelayDownButton.setImage(UIImage(systemName: "tortoise.fill"), for: .normal)
        self.imageFrameDelayDownButton.addTarget(self, action: #selector(sliderValueUp(_:)), for: .touchUpInside)
        self.view.addSubview(self.imageFrameDelayDownButton)
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
