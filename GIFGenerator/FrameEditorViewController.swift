//
//  FrameEditorViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/17.
//

import UIKit

class FrameEditorViewController: UIViewController {
    var imageFrames: [UIImage]! = nil
    let imageView = UIImageView()

    init(_ imageFrames: [UIImage]) {
        self.imageFrames = imageFrames
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        self.imageView.backgroundColor = .systemGray
        self.imageView.contentMode = .scaleAspectFit
        self.view.addSubview(imageView)
        self.imageView.animationImages = self.imageFrames
        self.imageView.animationDuration = 2.0
        self.imageView.startAnimating()
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
