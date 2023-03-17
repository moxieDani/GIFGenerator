//
//  FrameEditorViewController.swift
//  GIFGenerator
//
//  Created by Daniel on 2023/03/17.
//

import UIKit

class FrameEditorViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Edit Frame"
        self.view.backgroundColor = .systemGray
        
        self.navigationController?.navigationBar.tintColor = .systemYellow
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down.fill"), style: .plain, target: self, action: nil)
        self.navigationItem.rightBarButtonItem?.tintColor = .red
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
