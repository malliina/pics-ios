//
//  ViewController.swift
//  pics-ios
//
//  Created by Michael Skogberg on 19/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import SnapKit
import UIKit

class ViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    let PicCell = "PicCell"
    let minItemsRemainingBeforeLoadMore = 20
    let itemsPerLoad = 100
    
    private var pics: [String] = []
    let library = PicsLibrary()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        // Do any additional setup after loading the view, typically from a nib.
        collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: PicCell)
        collectionView!.delegate = self
        // collectionView!.prefetchDataSource = self
        loadPics(first: true)
    }
    
    func loadPics(first: Bool) {
        let beforeCount = pics.count
        library.load(from: pics.count, limit: itemsPerLoad) { (result) in
            print("loaded \(result.count) items, from \(beforeCount)")
            if pics.count == beforeCount {
                self.pics = self.pics + result
                if !result.isEmpty && !first {
                    let rows: [Int] = Array(beforeCount..<beforeCount+result.count)
                    let indexPaths = rows.map { row in IndexPath(item: row, section: 0) }
                    onUiThread {
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
        // nx + (n-1)s = w
        // where n = items per row, x = width per item, s = space between items, w = width of frame
        // solves for n with a given minimum x, then solves for x given n
        let itemsPerRow = floor((totalWidth + spaceBetweenItems) / (minWidthPerItem + spaceBetweenItems))
        let widthPerItem = (totalWidth - (itemsPerRow - 1.0) * spaceBetweenItems) / itemsPerRow
        // print("Using \(itemsPerRow) items per row with min \(minWidthPerItemAndSpace) and frame \(view.frame.width)")
        return CGSize(width: widthPerItem, height: widthPerItem)
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PicCell, for: indexPath)
        cell.backgroundColor = UIColor.magenta
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        maybeLoadMore(atItemIndex: indexPath.row)
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
