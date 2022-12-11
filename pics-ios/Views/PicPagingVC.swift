import Foundation
import UIKit
import SnapKit
import MessageUI
import SwiftUI

protocol PicDelegate {
    func remove(key: ClientKey) async
    func block(key: ClientKey) async
}

struct PicPagingView: UIViewControllerRepresentable {
    private let log = LoggerFactory.shared.vc(PicPagingView.self)
    typealias UIViewControllerType = PicPagingVC
    
    let pics: [PicMeta]
    let startIndex: Int
    let isPrivate: Bool
    let delegate: PicDelegate
    let smalls: DataCache
    let larges: DataCache
    
    var titleTextColor: UIColor { isPrivate ? PicsColors.uiAlmostLight : PicsColors.uiAlmostBlack }
    
    func makeUIViewController(context: Context) -> PicPagingVC {
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: titleTextColor]
        return PicPagingVC(pics: pics, startIndex: startIndex, isPrivate: isPrivate, delegate: delegate, smalls: smalls, larges: larges)
    }
    
    func updateUIViewController(_ uiViewController: PicPagingVC, context: Context) {
        guard let parent = uiViewController.parent else { return }
        uiViewController.updateNavBar(vc: parent)
    }
}

struct ShareRepresentable2: UIViewControllerRepresentable {
    private let log = LoggerFactory.shared.view(ShareRepresentable2.self)
    let meta: PicMeta
    let larges: DataCache
    @Binding var isPresenting: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresenting {
            let image = context.coordinator.shareable(pic: meta)
            let imageUrl = meta.url
            if image == nil {
                log.warn("No image available, so sharing URL \(imageUrl).")
            }
            let activities = UIActivityViewController(activityItems: [image ?? imageUrl], applicationActivities: nil)
            activities.popoverPresentationController?.sourceView = UIView()
            activities.completionWithItemsHandler = { _, _, _, _ in
                isPresenting = false
            }
            uiViewController.present(activities, animated: true)
        }
    }
    
    typealias UIViewControllerType = UIViewController
    
    class Coordinator {
        let parent: ShareRepresentable2
        
        init(parent: ShareRepresentable2) {
            self.parent = parent
        }
        
        func shareable(pic: PicMeta) -> UIImage? {
            if let cached = parent.larges.search(key: pic.key), let image = UIImage(data: cached) {
                return image
            } else {
                return nil
            }
        }
    }
    
}

//struct ShareRepresentable: UIViewControllerRepresentable {
//    private let log = LoggerFactory.shared.view(ShareRepresentable.self)
//    let meta: PicMeta
//    let larges: DataCache
//    @Binding var isPresenting: Bool
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(parent: self)
//    }
//
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        let image = context.coordinator.shareable(pic: meta)
//        let imageUrl = meta.url
//        if image == nil {
//            log.warn("No image available, so sharing URL \(imageUrl).")
//        }
//        return UIActivityViewController(activityItems: [image ?? imageUrl], applicationActivities: nil)
//    }
//
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
//
//    }
//
//    typealias UIViewControllerType = UIActivityViewController
//
//    class Coordinator {
//        let parent: ShareRepresentable
//
//        init(parent: ShareRepresentable) {
//            self.parent = parent
//        }
//
//        func shareable(pic: PicMeta) -> UIImage? {
//            if let cached = parent.larges.search(key: pic.key), let image = UIImage(data: cached) {
//                return image
//            } else {
//                return nil
//            }
//        }
//    }
//
//}

/// Swipe horizontally to show the next/previous image in the gallery.
/// Uses a UIPageViewController for paging.
class PicPagingVC: BaseVC {
    private let log = LoggerFactory.shared.vc(PicPagingVC.self)
    
    let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    
    let abuseEmail = "info@skogberglabs.com"
    let pics: [PicMeta]
    private var index: Int
    var idx: Int { index }
    let isPrivate: Bool
    let delegate: PicDelegate
    let smalls: DataCache
    let larges: DataCache
    var titleTextColor: Color { isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    
    init(pics: [PicMeta], startIndex: Int, isPrivate: Bool, delegate: PicDelegate, smalls: DataCache, larges: DataCache) {
        self.pics = pics
        self.index = startIndex
        self.isPrivate = isPrivate
        self.delegate = delegate
        self.smalls = smalls
        self.larges = larges
        super.init(nibName: nil, bundle: nil)
        self.edgesForExtendedLayout = []
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        updateNavBar(vc: self)
        navigationController?.setNavigationBarHidden(true, animated: true)
        let vc = UIHostingController(rootView: PicView(meta: pics[index], isPrivate: isPrivate, smalls: smalls, larges: larges, transitioning: .constant(false)))
        pager.setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        pager.dataSource = self
        pager.delegate = self
        addChild(pager)
        pager.didMove(toParent: self)
        view.addSubview(pager.view)
        pager.view.snp.makeConstraints { (make) in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
        // goes back on swipe up
        let swipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(onSwipeUp(_:)))
        swipeRecognizer.direction = .up
        view.addGestureRecognizer(swipeRecognizer)
    }
    
    @objc func onSwipeUp(_ sender: UISwipeGestureRecognizer) {
        navigationController?.popViewController(animated: true)
    }
    
    func updateNavBar(vc: UIViewController) {
        let p = pics[index]
        let d = Date(timeIntervalSince1970: Double(p.added) / 1000)
        let df = DateFormatter()
        df.dateFormat = "y-MM-dd H:mm"
        vc.navigationItem.title = df.string(from: d)
        vc.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareClicked(_:))),
            UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(actionsClicked(_:)))
        ]
    }
    
    @objc func shareClicked(_ button: UIBarButtonItem) {
        if index < pics.count {
            let pic = pics[index]
            let imageUrl = pic.url
            let image = shareable(pic: pic)
            if image == nil {
                log.warn("No image available, so sharing URL \(imageUrl).")
            }
            let vc = UIActivityViewController(activityItems: [image ?? imageUrl], applicationActivities: nil)
            vc.popoverPresentationController?.barButtonItem = button
            self.present(vc, animated: true, completion: nil)
        } else {
            self.log.warn("No image to share.")
        }
    }
    
    private func shareable(pic: PicMeta) -> UIImage? {
        if let cached = larges.search(key: pic.key), let image = UIImage(data: cached) {
            return image
        } else {
            return nil
        }
    }
    
    @objc func actionsClicked(_ button: UIBarButtonItem) {
        if index < pics.count {
            let meta = pics[index]
            let key = meta.key
            let content = UIAlertController(title: "Actions for this image", message: nil, preferredStyle: .actionSheet)
            content.popoverPresentationController?.barButtonItem = button
            if isPrivate {
                content.addAction(UIAlertAction(title: "Delete image", style: .destructive) { action in
                    self.goToPics()
                    Task {
                        await self.delegate.remove(key: key)
                    }
                })
            }
            content.addAction(UIAlertAction(title: "Copy link URL", style: .default) { action in
                UIPasteboard.general.string = meta.url.absoluteString
            })
            content.addAction(UIAlertAction(title: "Open in Safari", style: .default) { action in
                if !meta.url.isFileURL {
                    UIApplication.shared.open(meta.url)
                } else {
                    self.log.warn("Refusing to open a file URL in browser.")
                }
            })
            content.addAction(UIAlertAction(title: "Report objectionable content", style: .default) { action in
                self.openReportAbuse(key: key)
            })
            content.addAction(UIAlertAction(title: "Hide from this device", style: .default) { action in
                self.goToPics()
                Task {
                    await self.delegate.block(key: key)
                }
            })
            content.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                
            })
            present(content, animated: true, completion: nil)
        }
    }
    
    @objc func onRemoveClicked(_ sender: UIBarButtonItem) {
        goToPics()
        if index < pics.count {
            Task {
                await delegate.remove(key: pics[index].key)
            }
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
            guard let hosting = pageViewController.viewControllers?.first as? UIHostingController<PicView> else {
                log.warn("Current viewcontroller not found")
                return
            }
            let current = hosting.rootView
            guard let newIndex = self.pics.firstIndex(where: { p in p.key == current.meta.key || (p.clientKey != nil && p.clientKey == current.meta.clientKey) }) else { return }
            index = newIndex
            guard let parent = pageViewController.parent?.parent else { return }
            updateNavBar(vc: parent)
        }
    }
}

extension PicPagingVC: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        go(to: index - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        go(to: index + 1)
    }
    
    private func go(to newIndex: Int) -> UIViewController? {
        if newIndex >= 0 && newIndex < pics.count {
            return UIHostingController(rootView: PicView(meta: pics[newIndex], isPrivate: isPrivate, smalls: smalls, larges: larges, transitioning: .constant(false)))
        } else {
            return nil
        }
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        pics.count
    }
}
