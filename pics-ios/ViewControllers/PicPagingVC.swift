//
//  PagingPicVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//
import Foundation
import UIKit
import SnapKit
import MessageUI
import SwiftUI

struct PicPagingView: UIViewControllerRepresentable {
    private let log = LoggerFactory.shared.vc(PicPagingView.self)
    typealias UIViewControllerType = PicPagingVC
    
    let pics: [Picture]
    let startIndex: Int
    let isPrivate: Bool
    let delegate: PicDelegate
    
    var titleTextColor: UIColor { isPrivate ? PicsColors.uiAlmostLight : PicsColors.uiAlmostBlack }
    
    func makeUIViewController(context: Context) -> PicPagingVC {
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: titleTextColor]
        return PicPagingVC(pics: pics, startIndex: startIndex, isPrivate: isPrivate, delegate: delegate)
    }
    
    func updateUIViewController(_ uiViewController: PicPagingVC, context: Context) {
        guard let parent = uiViewController.parent else { return }
        uiViewController.updateNavBar(vc: parent)
    }
}

/// Swipe horizontally to show the next/previous image in the gallery.
/// Uses a UIPageViewController for paging.
class PicPagingVC: BaseVC {
    private let log = LoggerFactory.shared.vc(PicPagingVC.self)
    
    let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    
    let abuseEmail = "info@skogberglabs.com"
    let pics: [Picture]
    private var index: Int
    var idx: Int { index }
    let isPrivate: Bool
    let delegate: PicDelegate
    var titleTextColor: Color { isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    
    init(pics: [Picture], startIndex: Int, isPrivate: Bool, delegate: PicDelegate) {
        self.pics = pics
        self.index = startIndex
        self.isPrivate = isPrivate
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        self.edgesForExtendedLayout = []
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        updateNavBar(vc: self)
        navigationController?.setNavigationBarHidden(true, animated: true)
        let vc = PicVC(pic: pics[index], navHiddenInitially: true, isPrivate: isPrivate)
        pager.setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        pager.dataSource = self
        pager.delegate = self
        addChild(pager)
        pager.didMove(toParent: self)
        view.addSubview(pager.view)
        pager.view.snp.makeConstraints { (make) in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
    }
    
    func updateNavBar(vc: UIViewController) {
        vc.navigationItem.title = "Pic"
        vc.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareClicked(_:))),
            UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(actionsClicked(_:)))
        ]
        log.info("Updated nav bar with idx \(index)")
    }
    
    @objc func shareClicked(_ button: UIBarButtonItem) {
        if index < pics.count {
            let image = pics[index].meta.url
            let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            vc.popoverPresentationController?.barButtonItem = button
            self.present(vc, animated: true, completion: nil)
        } else {
            self.log.warn("No image to share.")
        }
    }
    
    @objc func actionsClicked(_ button: UIBarButtonItem) {
        if index < pics.count {
            let pic = pics[index]
            let meta = pic.meta
            let key = meta.key
            let content = UIAlertController(title: "Actions for this image", message: nil, preferredStyle: .actionSheet)
            content.popoverPresentationController?.barButtonItem = button
            if isPrivate {
                content.addAction(UIAlertAction(title: "Delete image", style: .destructive) { action in
                    self.goToPics()
                    self.delegate.remove(key: key)
                })
            }
            content.addAction(UIAlertAction(title: "Copy link URL", style: .default) { action in
                UIPasteboard.general.string = meta.url.absoluteString
            })
            content.addAction(UIAlertAction(title: "Open in Safari", style: .default) { action in
                if !meta.url.isFileURL {
                    UIApplication.shared.open(meta.url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                } else {
                    self.log.warn("Refusing to open a file URL in browser.")
                }
            })
            content.addAction(UIAlertAction(title: "Report objectionable content", style: .default) { action in
                self.openReportAbuse(key: key)
            })
            content.addAction(UIAlertAction(title: "Hide from this device", style: .default) { action in
                self.goToPics()
                self.delegate.block(key: key)
            })
            content.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                
            })
            present(content, animated: true, completion: nil)
        }
    }
    
    @objc func onRemoveClicked(_ sender: UIBarButtonItem) {
        goToPics()
        if index < pics.count {
            delegate.remove(key: pics[index].meta.key)
        }
    }
    
    func goToPics() {
        navigationController?.popViewController(animated: true)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
}

extension PicPagingVC: MFMailComposeViewControllerDelegate {
    func openReportAbuse(key: ClientKey) {
        if MFMailComposeViewController.canSendMail() {
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = self
            
            // Configure the fields of the interface.
            composeVC.setToRecipients([abuseEmail])
            composeVC.setSubject("Objectionable content report")
            composeVC.setMessageBody("Objectionable content. Content ID: \(key.key)", isHTML: false)
            
            // Present the view controller modally.
            self.present(composeVC, animated: true, completion: nil)
        } else {
            showReportAbuseInstructions(key: key)
        }
    }
    
    func showReportAbuseInstructions(key: ClientKey) {
        let a = UIAlertController(title: "Reporting Objectionable Content", message: "Report objectionable content to \(abuseEmail). For reference, the image ID is: \(key.key).", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { action in a.dismiss(animated: true, completion: nil) } )
        present(a, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

extension PicPagingVC: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            guard let current = pageViewController.viewControllers?.first as? PicVC else { return }
            guard let newIndex = self.pics.firstIndex(where: { p in p.meta.key == current.pic.meta.key || (p.meta.clientKey != nil && p.meta.clientKey == current.pic.meta.clientKey) }) else { return }
            index = newIndex
            log.info("New index \(newIndex)")
            guard let parent = pageViewController.parent?.parent else { return }
            updateNavBar(vc: parent)
        }
    }
}

extension PicPagingVC: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        return go(to: index - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        return go(to: index + 1)
    }
    
    func go(to newIndex: Int) -> UIViewController? {
        if newIndex >= 0 && newIndex < pics.count {
//            index = newIndex
            return PicVC(pic: pics[newIndex], navHiddenInitially: navigationController?.isNavigationBarHidden ?? true, isPrivate: isPrivate)
        } else {
            return nil
        }
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pics.count
    }
    
    // If uncommented, shows the paging indicator (dots highlighting the current index)
    // This is only an annoyance in this app, IMO, so it remains commented
//    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
//        return index
//    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
