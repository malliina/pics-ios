//
//  ViewController.swift
//  pics-ios
//
//  Created by Michael Skogberg on 19/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import SnapKit
import UIKit

extension ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach(download)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach(cancelDownload)
    }
}

class ViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    let log = LoggerFactory.shared.vc("ViewController")
    let PicCellIdentifier = "PicCell"
    let minItemsRemainingBeforeLoadMore = 20
    let itemsPerLoad = 100
    
    private var pics: [Picture] = []
    let library = PicsLibrary(http: PicsHttpClient(baseURL: URL(string: "http://todo")!, authValue: "todo"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        // Do any additional setup after loading the view, typically from a nib.
        collectionView!.register(PicCell.self, forCellWithReuseIdentifier: PicCellIdentifier)
        collectionView!.delegate = self
        collectionView!.prefetchDataSource = self
        loadPics(first: true)
    }
    
    func loadPics(first: Bool) {
        let beforeCount = pics.count
        library.load(from: pics.count, limit: itemsPerLoad) { (result) in
            self.log.info("Loaded \(result.count) items, from \(beforeCount)")
            if self.pics.count == beforeCount {
                self.pics = self.pics + result.map { p in Picture(meta: p) }
                if !result.isEmpty {
                    let rows: [Int] = Array(beforeCount..<beforeCount+result.count)
                    let indexPaths = rows.map { row in IndexPath(item: row, section: 0) }
                    self.onUiThread {
                        self.collectionView!.insertItems(at: indexPaths)
                    }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spaceBetweenItems = 10.0
        let minWidthPerItem = 130.0
        let totalWidth = Double(view.frame.width)
        // for n items in a row, we have n-1 spaces between them, therefore
        // nx + (n-1)s = w
        // where n = items per row, x = width per item, s = space between items, w = width of frame
        // solves for n with a given minimum x, then solves for x given n
        let itemsPerRow = floor((totalWidth + spaceBetweenItems) / (minWidthPerItem + spaceBetweenItems))
        let widthPerItem = (totalWidth - (itemsPerRow - 1.0) * spaceBetweenItems) / itemsPerRow
        // log.info("Got width \(widthPerItem) for \(indexPath.row) with total width \(view.frame.width)")
        // aspect is 4/3 for all thumbnails
        return CGSize(width: widthPerItem, height: widthPerItem * 3.0 / 4.0)
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        self.collectionView?.reloadData()
    }
    
    func onUiThread(_ f: @escaping () -> Void) {
        DispatchQueue.main.async(execute: f)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pics.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PicCellIdentifier, for: indexPath) as! PicCell
        let pic = pics[indexPath.row]
        if let thumb = pic.thumb {
            cell.imageView.image = thumb
        } else {
            cell.imageView.image = nil
            download(indexPath)
        }
//        let data = try! Data(contentsOf: pic.meta.thumb)
//        cell.imageView.image = UIImage(data: data)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        maybeLoadMore(atItemIndex: indexPath.row)
    }
    
    func download(_ indexPath: IndexPath) {
        let pic = pics[indexPath.row]
        Downloader.shared.download(url: pic.meta.thumb) { data in
            self.onDownloaded(data: data, indexPath: indexPath)
        }
    }
    
    func cancelDownload(_ indexPath: IndexPath) {
        Downloader.shared.cancelDownload(forUrl: pics[indexPath.row].meta.thumb)
    }
    
    func onDownloaded(data: Data, indexPath: IndexPath) {
        onUiThread {
            if let image = UIImage(data: data) {
                self.pics[indexPath.row].thumb = image
                if self.collectionView?.indexPathsForVisibleItems.contains(indexPath) ?? false {
                    self.collectionView?.reloadItems(at: [indexPath])
                }
            }
        }
    }
    
    func maybeLoadMore(atItemIndex: Int) {
        let trackCount = pics.count
        if atItemIndex + minItemsRemainingBeforeLoadMore == trackCount {
            loadMore(atItemIndex)
        }
    }
    
    func loadMore(_ atItemIndex: Int) {
        loadPics(first: false)
    }
}
