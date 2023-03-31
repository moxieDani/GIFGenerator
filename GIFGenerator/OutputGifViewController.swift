//
//  OutputGifViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/23.
//

import UIKit

extension UIImage {
    func resized(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? self
    }
}

class OutputGifViewController: UIViewController {
    private var gifPath: URL! = nil
    private let imageView = UIImageView()
    private let shareButton = UIButton()
    
    @objc func shareFile() {
      // 액티비티 뷰 컨트롤러 만들기
      let activityViewController = UIActivityViewController(activityItems: [self.gifPath!], applicationActivities: nil)

      // 액티비티 뷰 컨트롤러 표시하기
      present(activityViewController, animated: true, completion: nil)
    }
    
    private func showShareButton() {
        let originalImage = UIImage(systemName: "square.and.arrow.up")?.withRenderingMode(.alwaysOriginal)
        let resizedImage = originalImage?.resized(to: CGSize(width: 30, height: 30))
        
        self.shareButton.setImage(resizedImage, for: .normal)
        self.shareButton.backgroundColor = .systemYellow
        self.shareButton.frame = CGRect(x: self.view.safeAreaInsets.left, y: view.frame.height - 70, width: self.view.frame.width, height: 70)
        self.shareButton.addTarget(self, action: #selector(shareFile), for: .touchUpInside)
        self.view.addSubview(self.shareButton)
    }
    
    init(_ gifPath: URL) {
        super.init(nibName: nil, bundle: nil)
        self.gifPath = gifPath
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Result"
        self.view.backgroundColor = .systemGray
        
        self.navigationController?.navigationBar.tintColor = .systemYellow
        
        showShareButton()
        
        self.imageView.frame = CGRect(x: self.view.safeAreaInsets.left,
                                      y: (self.navigationController?.navigationBar.frame.maxY)!,
                                      width: self.view.frame.width,
                                      height: self.shareButton.frame.minY - (self.navigationController?.navigationBar.frame.maxY)! - 10)
        self.imageView.backgroundColor = .systemGray
        self.imageView.contentMode = .scaleAspectFit
        
        self.view.addSubview(self.imageView)
        
        // Get file data of GIF file
        if let gifSource = CGImageSourceCreateWithURL(self.gifPath as CFURL, nil) {
            // Get frames of GIF image
            let frameCount = CGImageSourceGetCount(gifSource)
            var frames = [UIImage]()

            for i in 0..<frameCount {
                guard let cgImage = CGImageSourceCreateImageAtIndex(gifSource, i, nil) else {
                    continue
                }

                let uiImage = UIImage(cgImage: cgImage)
                frames.append(uiImage)
            }

            self.imageView.image = UIImage.animatedImage(with: frames, duration: TimeInterval(frameCount) / 10.0)
        }
        
        showShareButton()
        
        
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
