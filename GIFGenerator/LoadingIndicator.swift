//
//  LoadingIndicator.swift
//  PHPickerExample
//
//  Created by Daniel on 2023/03/13.
//

import UIKit


class LoadingIndicator {
    static func showLoading() {
        DispatchQueue.main.async {
            // 최상단에 있는 window 객체 획득
            guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }

            guard let firstWindow = firstScene.windows.last else {
                return
            }

            let loadingIndicatorView: UIActivityIndicatorView
            if let existedView = firstWindow.subviews.first(where: { $0 is UIActivityIndicatorView } ) as? UIActivityIndicatorView {
                loadingIndicatorView = existedView
            } else {
                loadingIndicatorView = UIActivityIndicatorView(style: .large)
                /// 다른 UI가 눌리지 않도록 indicatorView의 크기를 full로 할당
                loadingIndicatorView.frame = firstWindow.frame
                loadingIndicatorView.color = .white
                firstWindow.addSubview(loadingIndicatorView)
            }

            loadingIndicatorView.startAnimating()
        }
    }

    static func hideLoading() {
        DispatchQueue.main.async {
            guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }

            guard let firstWindow = firstScene.windows.last else {
                return
            }

            firstWindow.subviews.filter({ $0 is UIActivityIndicatorView }).forEach { $0.removeFromSuperview() }
        }
    }
}
