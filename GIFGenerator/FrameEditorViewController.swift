//
//  FrameEditorViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/17.
//

import UIKit

class FrameEditorViewController: UIViewController {
    private var imageFrames: [UIImage]! = nil
    private let imageView = UIImageView()
    private let playPauseButton = UIButton()

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
            let newImage = image.withTintColor(.white)
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

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Edit Frame"
        self.view.backgroundColor = .systemGray
        
        self.navigationController?.navigationBar.tintColor = .systemYellow
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down.fill"), style: .plain, target: self, action: nil)
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
        
        self.playPauseButton.frame = CGRect(x: self.view.frame.width/2 - 20,
                                              y: self.imageView.frame.height + (self.navigationController?.navigationBar.frame.maxY)! + 10,
                                              width: 40,
                                              height: 40)
        self.playPauseButton.backgroundColor = .darkGray
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
