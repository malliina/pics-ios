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

/// Swipe horizontally to show the next/previous image in the gallery.
/// Uses a UIPageViewController for the paging.
class PicPagingVC: BaseVC {
    private let log = LoggerFactory.shared.vc(PicPagingVC.self)
    
    let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    
    let pics: [Picture]
    private var index: Int
    
    init(pics: [Picture], startIndex: Int) {
        self.pics = pics
        self.index = startIndex
        super.init(nibName: nil, bundle: nil)
        self.edgesForExtendedLayout = []
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        navigationController?.setNavigationBarHidden(true, animated: true)
        pager.setViewControllers([PicVC(pic: pics[index], navHiddenInitially: true)], direction: .forward, animated: false, completion: nil)
        pager.dataSource = self
        pager.delegate = self
        addChildViewController(pager)
        pager.didMove(toParentViewController: self)
        view.addSubview(pager.view)
        pager.view.snp.makeConstraints { (make) in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
    }
}

extension PicPagingVC: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            guard let current = pageViewController.viewControllers?.first as? PicVC else { return }
            guard let newIndex = self.pics.index(where: { p in p.meta.key == current.pic.meta.key || (p.meta.clientKey != nil && p.meta.clientKey == current.pic.meta.clientKey) }) else { return }
            index = newIndex
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
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pics.count
    }
    
    // If uncommented, shows the paging indicator (dots highlighting the current index)
    // This is only an annoyance in this app, IMO, so it remains commented
//    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
//        return index
//    }
    
    func go(to newIndex: Int) -> UIViewController? {
        if newIndex >= 0 && newIndex < pics.count { return PicVC(pic: pics[newIndex], navHiddenInitially: navigationController?.isNavigationBarHidden ?? true) } else { return nil }
    }
}
