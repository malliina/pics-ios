import Foundation
import MessageUI
import SwiftUI

struct PicPageView<T>: View where T: PicsVMLike {
    private let log = LoggerFactory.shared.view(PicPageView.self)
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var viewModel: T
    let startIndex: Int
    let isPrivate: Bool
    @Binding var active: PicMeta?
    
    @State var showActions = false
    @State var showShare = false
    @State var showEmail = false
    @State var showAbuseInstructions = false
    
    init(viewModel: T, startIndex: Int, isPrivate: Bool, active: Binding<PicMeta?>) {
        self.viewModel = viewModel
        self.startIndex = startIndex
        self.isPrivate = isPrivate
        self._active = active
    }
    
    var body: some View {
        PageViewRepresentable(viewModel: viewModel, startIndex: startIndex, isPrivate: isPrivate, active: $active)
            .navigationTitle(title())
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showActions.toggle()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .renderingMode(.template)
                    }
                    .confirmationDialog("Actions for this image", isPresented: $showActions, titleVisibility: .visible, presenting: active) { meta in
                        if isPrivate {
                            Button("Delete image", role: .destructive) {
                                dismiss()
                                Task {
                                    await viewModel.remove(key: meta.key)
                                }
                            }
                        }
                        Button("Copy link URL") {
                            UIPasteboard.general.string = meta.url.absoluteString
                        }
                        Button("Open in Safari") {
                            if !meta.url.isFileURL {
                                UIApplication.shared.open(meta.url)
                            } else {
                                log.warn("Refusing to open a file URL in browser.")
                            }
                        }
                        Button("Report objectionable content") {
                            if MFMailComposeViewController.canSendMail() {
                                showEmail.toggle()
                            } else {
                                showAbuseInstructions.toggle()
                            }
                        }
                        Button("Hide from this device") {
                            dismiss()
                            Task {
                                await viewModel.block(key: meta.key)
                            }
                        }
                    }
                    .sheet(isPresented: $showEmail) {
                        if let active = active {
                            MailRepresentable(meta: active, showEmail: $showEmail)
                        }
                    }
                    .alert("Report Objectionable Content", isPresented: $showAbuseInstructions, presenting: active) { meta in
                        Button("OK") {
                            showAbuseInstructions.toggle()
                        }
                    } message: { meta in
                        Text("Report objectionable content to \(MailRepresentable.abuseEmail). For reference, the image ID is: \(meta.key.key).")
                    }
                    Button {
                        showShare.toggle()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .renderingMode(.template)
                    }
                    .popover(isPresented: $showShare) {
                        if let meta = active {
                            ShareRepresentable(meta: meta, larges: viewModel.cacheLarge, isPresenting: $showShare)
                        }
                    }
                }
            }
    }
    
    func title() -> String {
        if let pic = active {
            return title(pic: pic)
        } else {
            return ""
//            return title(pic: viewModel.pics[startIndex])
        }
    }

    func title(pic: PicMeta) -> String {
        let d = Date(timeIntervalSince1970: Double(pic.added) / 1000)
        let df = DateFormatter()
        df.dateFormat = "y-MM-dd H:mm"
        return df.string(from: d)
    }
}

struct PageViewRepresentable<T>: UIViewControllerRepresentable where T: PicsVMLike {
    private let log = LoggerFactory.shared.view(PageViewRepresentable.self)
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: T
    var pics: [PicMeta] { viewModel.pics }
    let startIndex: Int
    let isPrivate: Bool
    @Binding var active: PicMeta?
    @State var transitioning = false
    var smalls: DataCache { viewModel.cacheSmall }
    var larges: DataCache { viewModel.cacheLarge }
    
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        let vc = UIHostingController(rootView: PicView(meta: pics[startIndex], isPrivate: isPrivate, smalls: smalls, larges: larges, transitioning: $transitioning))
        pager.setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        pager.delegate = context.coordinator
        pager.dataSource = context.coordinator
        let swipeRecognizer = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.onSwipeUp(_:)))
        swipeRecognizer.direction = .up
        pager.view.addGestureRecognizer(swipeRecognizer)
        active = pics[startIndex]
        return pager
    }
    
    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
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
        
        var pics: [PicMeta] { parent.pics }
        var isPrivate: Bool { parent.isPrivate }
        
        @objc func onSwipeUp(_ sender: UISwipeGestureRecognizer) {
            parent.dismiss()
        }
        
        // UIPageViewControllerDelegate
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            parent.transitioning = true
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
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
