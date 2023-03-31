//
//  OutputGifViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/23.
//

import UIKit

class OutputGifViewController: UIViewController {
    private var gifImage: UIImage! = nil
    private let imageView = UIImageView()
    
    init(_ gifImage: UIImage) {
        super.init(nibName: nil, bundle: nil)
        self.gifImage = gifImage
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Generated GIF"
        self.view.backgroundColor = .systemGray
        
        self.navigationController?.navigationBar.tintColor = .systemYellow
               
        self.imageView.frame = CGRect(x: self.view.safeAreaInsets.left,
                                      y: (self.navigationController?.navigationBar.frame.maxY)!,
                                      width: self.view.frame.width,
                                      height: self.view.frame.height * 0.5)
        self.imageView.backgroundColor = .systemGray
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.image = self.gifImage
        self.view.addSubview(self.imageView)
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
