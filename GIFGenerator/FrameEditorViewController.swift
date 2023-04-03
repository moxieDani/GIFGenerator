//
//  FrameEditorViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/17.
//

import UIKit
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

class FrameEditorViewController: UIViewController {
    private var imageFrames: [UIImage]! = nil
    private let imageView = UIImageView()
    private let playPauseButton = UIButton()

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
            let layer = self.imageView.layer
            let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
            layer.speed = 0.0
            layer.timeOffset = pausedTime
        } else {
            let pausedTime = self.imageView.layer.timeOffset
            self.imageView.layer.speed = 1.0
            self.imageView.layer.timeOffset = 0.0
            self.imageView.layer.beginTime = 0.0
            let timeSincePause = self.imageView.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
            self.imageView.layer.beginTime = timeSincePause
        }
        self.playPauseButton.setImage(self.getPlayPauseImage(), for: .normal)
    }
    
    init(_ imageFrames: [UIImage]) {
        super.init(nibName: nil, bundle: nil)
        self.imageFrames = imageFrames
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getPlayPauseImage() -> UIImage {
        var ret: UIImage! = nil
        
        if let image = UIImage(systemName: imageView.layer.speed == 1.0 ? "pause.fill" : "play.fill") {
            let newImage = image.withTintColor(.black)
            let newWidth = newImage.size.width
            let newHeight = newImage.size.height
            let newSize = CGSize(width: newWidth, height: newHeight)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            newImage.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
            ret = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
        
        return ret
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
        self.imageView.animationImages = self.imageFrames
        self.imageView.animationDuration = TimeInterval(self.imageFrames.count) / 10.0
        self.imageView.startAnimating()
        
        self.playPauseButton.frame = CGRect(x: self.view.frame.width/2 - 80,
                                              y: self.view.frame.height - 60,
                                              width: 40,
                                              height: 40)
        self.playPauseButton.backgroundColor = .systemYellow
        self.playPauseButton.layer.cornerRadius = 20
        self.playPauseButton.clipsToBounds = true
        self.playPauseButton.setImage(self.getPlayPauseImage(), for: .normal)
        self.playPauseButton.addTarget(self, action: #selector(pressPlayPauseButton), for: .touchUpInside)
        self.view.addSubview(self.playPauseButton)
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
