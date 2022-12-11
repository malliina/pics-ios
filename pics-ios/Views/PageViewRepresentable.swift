import Foundation
import SwiftUI

struct PageViewRepresentable: UIViewControllerRepresentable {
    private let log = LoggerFactory.shared.view(PageViewRepresentable.self)
    @Environment(\.dismiss) private var dismiss
    let pics: [PicMeta]
    let startIndex: Int
    @Binding var active: PicMeta?
    let isPrivate: Bool
//    let delegate: PicDelegate
    let smalls: DataCache
    let larges: DataCache
    @State var transitioning = false
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        let initialPic = pics[startIndex]
        let vc = UIHostingController(rootView: PicView(meta: pics[startIndex], isPrivate: isPrivate, smalls: smalls, larges: larges, transitioning: $transitioning))
        pager.setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        pager.delegate = context.coordinator
        pager.dataSource = context.coordinator
        let swipeRecognizer = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.onSwipeUp(_:)))
        swipeRecognizer.direction = .up
        pager.view.addGestureRecognizer(swipeRecognizer)
        active = initialPic
        return pager
    }
    
    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        guard let parent = uiViewController.parent else { return }
        context.coordinator.vc = parent
        updateNavBar(vc: parent, context: context)
    }
    
    func updateNavBar(vc: UIViewController, context: Context) {
        if let p = active {
            log.info("Updating \(p.key.value)")
            let d = Date(timeIntervalSince1970: Double(p.added) / 1000)
            let df = DateFormatter()
            df.dateFormat = "y-MM-dd H:mm"
            vc.navigationItem.title = df.string(from: d)
            vc.navigationItem.rightBarButtonItems = [
                UIBarButtonItem(barButtonSystemItem: .action, target: context.coordinator, action: #selector(context.coordinator.shareClicked(_:))),
                UIBarButtonItem(barButtonSystemItem: .compose, target: context.coordinator, action: #selector(context.coordinator.actionsClicked(_:)))
            ]
        } else {
            log.info("Nothing to update.")
        }
    }
    
    typealias UIViewControllerType = UIPageViewController
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, index: startIndex)
    }
    
    class Coordinator: NSObject, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
        private let log = LoggerFactory.shared.vc(Coordinator.self)
        let parent: PageViewRepresentable
        private var index: Int
        
        init(parent: PageViewRepresentable, index: Int) {
            self.parent = parent
            self.index = index
        }
        var vc: UIViewController? = nil
        
        var pics: [PicMeta] { parent.pics }
        var isPrivate: Bool { parent.isPrivate }
        
        @objc func onSwipeUp(_ sender: UISwipeGestureRecognizer) {
            parent.dismiss()
        }
        
        @objc func shareClicked(_ button: UIBarButtonItem) {
            if index < pics.count {
                let pic = pics[index]
                let imageUrl = pic.url
                let image = shareable(pic: pic)
                if image == nil {
                    log.warn("No image available, so sharing URL \(imageUrl).")
                }
                let activities = UIActivityViewController(activityItems: [image ?? imageUrl], applicationActivities: nil)
                activities.popoverPresentationController?.barButtonItem = button
                vc?.present(activities, animated: true, completion: nil)
            } else {
                self.log.warn("No image to share.")
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
//                        self.goToPics()
                        Task {
//                            await self.delegate.remove(key: key)
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
//                    self.openReportAbuse(key: key)
                })
                content.addAction(UIAlertAction(title: "Hide from this device", style: .default) { action in
//                    self.goToPics()
                    Task {
//                        await self.delegate.block(key: key)
                    }
                })
                content.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                    
                })
                vc?.present(content, animated: true, completion: nil)
            }
        }
        
        private func shareable(pic: PicMeta) -> UIImage? {
            if let cached = parent.larges.search(key: pic.key), let image = UIImage(data: cached) {
                return image
            } else {
                return nil
            }
        }
        
        // UIPageViewControllerDelegate
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            log.info("Will transition")
            parent.transitioning = true
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            log.info("Transition \(completed)")
            if completed {
                parent.transitioning = false
                guard let hosting = pageViewController.viewControllers?.first as? UIHostingController<PicView> else {
                    log.warn("Current viewcontroller not found")
                    return
                }
                let current = hosting.rootView
                guard let newIndex = self.pics.firstIndex(where: { p in p.key == current.meta.key || (p.clientKey != nil && p.clientKey == current.meta.clientKey) }) else { return }
                index = newIndex
                parent.active = pics[index]
//                guard let parent = pageViewController.parent?.parent else { return }
//                updateNavBar(vc: parent)
            }
        }
        
        // UIPageViewControllerDataSource
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            go(to: index - 1)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            go(to: index + 1)
        }
        
        private func go(to newIndex: Int) -> UIViewController? {
            if newIndex >= 0 && newIndex < pics.count {
                return UIHostingController(rootView: PicView(meta: pics[newIndex], isPrivate: parent.isPrivate, smalls: parent.smalls, larges: parent.larges, transitioning: parent.$transitioning))
            } else {
                return nil
            }
        }
        
        func presentationCount(for pageViewController: UIPageViewController) -> Int {
            pics.count
        }
    }
}
