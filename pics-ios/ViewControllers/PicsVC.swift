//
//  ViewController.swift
//  pics-ios
//
//  Created by Michael Skogberg on 19/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import SnapKit
import UIKit
import AWSCognitoIdentityProvider

extension PicsVC: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { (idx) in
            download(idx)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach(cancelDownload)
    }
}

class PicsVC: UICollectionViewController, UICollectionViewDelegateFlowLayout, PicsDelegate {
    let log = LoggerFactory.shared.vc(PicsVC.self)
    let PicCellIdentifier = "PicCell"
    let minItemsRemainingBeforeLoadMore = 20
    static let itemsPerLoad = 100
    
    private var pics: [Picture] = []
    var library: PicsLibrary? = nil
    var socket: PicsSocket? = nil
    let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)
    var authCancellation: AWSCancellationTokenSource? = nil
    static let preferredItemSize: Double = Devices.isIpad ? 200 : 130
    
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.isHidden = true
        view.backgroundColor = PicsColors.background
        guard let coll = collectionView else { return }
        coll.register(PicsCell.self, forCellWithReuseIdentifier: PicCellIdentifier)
        coll.delegate = self
        coll.prefetchDataSource = self
        initAndLoad()
    }
    
    func reInit() {
        authCancellation?.cancel()
        authCancellation?.dispose()
        initAndLoad()
    }
    
    private func initAndLoad() {
        log.info("Initializing picture gallery...")
        authCancellation = AWSCancellationTokenSource()
        Tokens.shared.retrieve(onToken: { (token) in
            self.onUiThread {
                self.initNav(title: "Pics", large: false)
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(PicsVC.signOutClicked(_:)))
                let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
                if isCameraAvailable {
                    self.navigationItem.rightBarButtonItems = [
                        UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(PicsVC.cameraClicked(_:))),
                        UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(PicsVC.refreshClicked(_:)))
                    ]
                }
                self.collectionView?.backgroundView = self.activityIndicator
                self.activityIndicator.startAnimating()
            }
            self.library = PicsLibrary(http: PicsHttpClient(accessToken: token))
            self.socket = PicsSocket(authValue: PicsHttpClient.authValueFor(forToken: token))
            self.socket?.openSilently()
            self.socket?.delegate = self
            self.log.info("Loading pics...")
            self.loadPics(limit: PicsVC.itemsPerLoad)
        }, cancellationToken: authCancellation?.token)
    }

    func loadPics(limit: Int) {
        let beforeCount = pics.count
        guard let library = library else {
            log.info("No library initialized, aborting.")
            activityIndicator.stopAnimating()
            return
        }
        library.load(from: pics.count, limit: limit, onError: onLoadError) { (result) in
            self.log.info("Loaded \(result.count) items, from \(beforeCount)")
            if self.pics.count == beforeCount {
                if !result.isEmpty {
                    self.pics = self.pics + result.map { p in Picture(meta: p) }
                    let rows: [Int] = Array(beforeCount..<beforeCount+result.count)
                    let indexPaths = rows.map { row in IndexPath(item: row, section: 0) }
                    self.onUiThread {
                        self.displayItems(at: indexPaths)
                    }
                } else {
                    if self.pics.isEmpty {
                        self.onUiThread {
                            self.displayText(text: "You have no pictures yet.")
                        }
                    }
                }
            }
        }
    }
    
    func displayItems(at: [IndexPath]) {
        guard let coll = self.collectionView else { return }
        self.activityIndicator.stopAnimating()
        coll.backgroundView = nil
        self.log.info("Inserting \(at.count) items.")
        coll.insertItems(at: at)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spaceBetweenItems = 10.0
        let minWidthPerItem = PicsVC.preferredItemSize
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.collectionView?.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pics.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PicCellIdentifier, for: indexPath) as! PicsCell
        let pic = pics[indexPath.row]
        if let thumb = pic.small {
            cell.imageView.image = thumb
        } else {
            cell.imageView.image = nil
            download(indexPath)
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        maybeLoadMore(atItemIndex: indexPath.row)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let pic = pics[indexPath.row]
        self.navigationController?.pushViewController(PicVC(pic: pic), animated: true)
    }
    
    func download(_ indexPath: IndexPath) {
        let pic = pics[indexPath.row]
        if pic.small == nil {
            Downloader.shared.download(url: pic.meta.small) { data in
                self.onDownloaded(data: data, indexPath: indexPath)
            }
        }
    }
    
    func cancelDownload(_ indexPath: IndexPath) {
        // We never cancel thumbnail downloads, because a prefetch download might have suppressed a non-prefetch download for which canceling is not an option
        // Meaning, if we cancel, we might end up with zero pics
//        Downloader.shared.cancelDownload(forUrl: pics[indexPath.row].meta.thumb)
    }
    
    func onDownloaded(data: Data, indexPath: IndexPath) {
        onUiThread {
            if let image = UIImage(data: data), let coll = self.collectionView {
                self.pics[indexPath.row].small = image
                if coll.indexPathsForVisibleItems.contains(indexPath) {
                    coll.reloadItems(at: [indexPath])
                } else {
                    self.log.debug("Nothing visible to update for item \(indexPath.row)")
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
        loadPics(limit: PicsVC.itemsPerLoad)
    }
    
    func onLoadError(error: AppError) {
        let message = AppError.stringify(error)
        log.error(message)
        displayText(text: message)
    }
    
    func displayText(text: String) {
        onUiThread {
            self.activityIndicator.stopAnimating()
            let feedbackLabel = PicsLabel.build(text: text, alignment: .center, numberOfLines: 0)
            feedbackLabel.textColor = .lightText
            self.collectionView?.backgroundView = feedbackLabel
            self.resetDisplay()
        }
    }
    
    @objc func cameraClicked(_ sender: UIBarButtonItem) {
        showCamera()
    }
    
    func showCamera() {
        let control = UIImagePickerController()
        control.sourceType = .camera
        control.allowsEditing = false
        control.delegate = self
        if library != nil {
            self.present(control, animated: true, completion: nil)
        } else {
            log.error("No library available, refusing to show camera")
        }
    }
    
    @objc func refreshClicked(_ sender: UIBarButtonItem) {
        let loadLimit = max(pics.count, PicsVC.itemsPerLoad)
        resetDisplay()
        self.collectionView?.backgroundView = self.activityIndicator
        self.activityIndicator.startAnimating()
        loadPics(limit: loadLimit)
    }
    
    @objc func signOutClicked(_ sender: UIBarButtonItem) {
        pool.currentUser()?.signOut()
        self.collectionView?.backgroundView = nil
        self.navigationController?.navigationBar.isHidden = true
        resetData()
        initAndLoad()
    }
    
    func resetData() {
        Tokens.shared.clearDelegates()
        library = nil
        socket?.close()
        socket = nil
        resetDisplay()
    }
    
    func resetDisplay() {
        pics = []
        collectionView?.reloadData()
    }
    
    func onPics(pics: [PicMeta]) {
        // By the time we get this notification, pics recently taken on this device are probably already displayed.
        // So we filter out already added pics to avoid duplicates.
        let newPics = pics.filter { newPic -> Bool in !self.pics.contains(where: { p -> Bool in (newPic.clientKey != nil && p.meta.clientKey == newPic.clientKey) || p.meta.key == newPic.key }) }
        log.info("Got \(pics.count) pic(s), out of which \(newPics.count) are new.")
        displayNewPics(pics: newPics.map { p in Picture(meta: p) })
    }
    
    func displayNewPics(pics: [Picture]) {
        self.onUiThread {
            let ordered: [Picture] = pics.reversed()
            self.pics = ordered + self.pics
            let indexPaths = ordered.enumerated().map({ (offset, pic) -> IndexPath in
                IndexPath(row: offset, section: 0)
            })
            self.displayItems(at: indexPaths)
        }
    }
}

extension PicsVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true) { () in
            DispatchQueue.global(qos: .background).async {
                do {
                    try self.handleMedia(info: info)
                } catch {
                    self.log.info("Failed to save picture")
                }
            }
        }
    }
    
    func handleMedia(info: [String: Any]) throws {
        guard let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            log.info("Original image is not an UIImage")
            return
        }
        guard let data = UIImageJPEGRepresentation(originalImage, 1) else {
            log.info("Taken image is not in JPEG format")
            return
        }
        guard let library = library else {
            log.info("Library not available")
            return
        }
        log.info("Saving pic to file...")
        let url = try LocalPics.shared.saveAsJpg(data: data)
        let clientKey: String = String(UUID().uuidString.prefix(5)).lowercased()
        let pic = Picture(clientKey: clientKey, url: url, image: originalImage)
        displayNewPics(pics: [pic])
        library.save(picture: data, clientKey: clientKey, onError: onSaveError) { pic in
            let idx = self.pics.index(where: { (p) -> Bool in
                p.meta.clientKey == clientKey
            })
            if let idx = idx {
                let newPic = self.pics[idx].withMeta(meta: pic)
                self.pics[idx] = newPic
                self.log.info("Saved pic '\(pic.key)'.")
            } else {
                self.log.warn("Saved pic '\(pic.key)', but it was not in the collection. This is most likely a bug.")
            }
        }
//        if let metadata = info[UIImagePickerControllerMediaMetadata] as? NSDictionary {
//            metadata.forEach({ (key, value) in
//                print("\(key) = \(value)")
//            })
//        }
    }
    
    func onSaveError(error: AppError) {
        let message = AppError.stringify(error)
        log.error("Unable to save pic: '\(message)'.")
    }
}
