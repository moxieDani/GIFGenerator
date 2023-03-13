//
//  MainViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/01.
//

import UIKit

class MainViewController: UIViewController {
    
    private let videoToGifButton = UIButton()
    private let livePhotoToGifButton = UIButton()
    
    @objc func showVideoPickerView()
    {
        let rootVC = VideoTrimViewController(.videos)
        let navVC = UINavigationController(rootViewController: rootVC)
        navVC.modalPresentationStyle = .fullScreen
        navVC.modalTransitionStyle = .crossDissolve
        self.present(navVC, animated:true)
    }
    
    @objc func showLivePhotoPickerView()
    {
        let rootVC = VideoTrimViewController(.livePhotos)
        let navVC = UINavigationController(rootViewController: rootVC)
        navVC.modalPresentationStyle = .fullScreen
        navVC.modalTransitionStyle = .crossDissolve
        self.present(navVC, animated:true)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        self.videoToGifButton.setTitle("Video -> GIF", for: .normal)
        self.videoToGifButton.backgroundColor = .orange
        self.videoToGifButton.layer.cornerRadius = 15
        self.videoToGifButton.layer.shadowColor = UIColor.gray.cgColor
        self.videoToGifButton.layer.shadowOpacity = 1.0
        self.videoToGifButton.layer.shadowOffset = CGSize.zero
        self.videoToGifButton.layer.shadowRadius = 6
        self.videoToGifButton.frame = CGRect(x: 20,
                                        y: self.view.safeAreaInsets.top + 100,
                                    width: self.view.frame.width - 40,
                                   height: 52)
        self.videoToGifButton.addTarget(self, action: #selector(showVideoPickerView), for: .touchUpInside)
        self.view.addSubview(self.videoToGifButton)
        
        self.livePhotoToGifButton.setTitle("LivePhoto -> GIF", for: .normal)
        self.livePhotoToGifButton.backgroundColor = .systemPink
        self.livePhotoToGifButton.layer.cornerRadius = 15
        self.livePhotoToGifButton.layer.shadowColor = UIColor.gray.cgColor
        self.livePhotoToGifButton.layer.shadowOpacity = 1.0
        self.livePhotoToGifButton.layer.shadowOffset = CGSize.zero
        self.livePhotoToGifButton.layer.shadowRadius = 6
        self.livePhotoToGifButton.frame = CGRect(x: 20, y: self.videoToGifButton.frame.maxY+20, width: self.view.frame.width - 40, height: 52)
        self.livePhotoToGifButton.addTarget(self, action: #selector(showLivePhotoPickerView), for: .touchUpInside)
        self.view.addSubview(self.livePhotoToGifButton)
    }


}

