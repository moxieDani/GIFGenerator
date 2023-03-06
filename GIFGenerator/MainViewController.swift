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
        self.present(navVC, animated:true)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        videoToGifButton.setTitle("Video -> GIF", for: .normal)
        videoToGifButton.backgroundColor = .darkGray
        videoToGifButton.setTitleColor(.lightGray, for: .normal)
        videoToGifButton.frame = CGRect(x: 20, y: 100, width: 330, height: 52)
        videoToGifButton.addTarget(self, action: #selector(showVideoPickerView), for: .touchUpInside)
        self.view.addSubview(self.videoToGifButton)
        
        livePhotoToGifButton.setTitle("LivePhoto -> GIF", for: .normal)
        livePhotoToGifButton.backgroundColor = .darkGray
        livePhotoToGifButton.setTitleColor(.lightGray, for: .normal)
        livePhotoToGifButton.frame = CGRect(x: 20, y: videoToGifButton.frame.maxY+20, width: 330, height: 52)
        livePhotoToGifButton.addTarget(self, action: #selector(showVideoPickerView), for: .touchUpInside)
        self.view.addSubview(self.livePhotoToGifButton)
    }


}

