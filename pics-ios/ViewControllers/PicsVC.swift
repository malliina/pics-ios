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

protocol PicsRenderer {
    func reconnectAndSync()
}

protocol PicDelegate {
    func removePic(key: String)
}

class PicsVC: UICollectionViewController, UICollectionViewDelegateFlowLayout, PicsDelegate, PicDelegate, PicsRenderer {
    static let preferredItemSize: Double = Devices.isIpad ? 200 : 130
    static let itemsPerLoad = 100
    
    let log = LoggerFactory.shared.vc(PicsVC.self)
    let PicCellIdentifier = "PicCell"
    let minItemsRemainingBeforeLoadMore = 20
    
    private var mightHaveMore: Bool = true
    private var isOnline = false
    private var offlinePics: [Picture] {
        get { return PicsSettings.shared.localPics }
        set (newPics) { PicsSettings.shared.localPics = newPics }
    }
    
    private var loadedPics: [Picture] = []
    private var pics: [Picture] {
        get { return isOnline ? loadedPics : offlinePics }
        set (newPics) {
            offlinePics = newPics
            if isOnline {
                loadedPics = newPics
            }
        }
    }
    
    var library: PicsLibrary { return Backend.shared.library }
    var socket: PicsSocket { return Backend.shared.socket }
    let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)
    var authCancellation: AWSCancellationTokenSource? = nil
    
    var currentUser: AWSCognitoIdentityUser? { return Tokens.shared.pool.currentUser() }
    var isPrivate: Bool {
        get { return isSignedIn && PicsSettings.shared.isPrivate }
        set(newValue) { PicsSettings.shared.isPrivate = newValue }
    }
    var isSignedIn: Bool { return currentUser?.isSignedIn ?? false }
    var backgroundColor: UIColor { return isPrivate ? PicsColors.background : PicsColors.lightBackground }
    var cellBackgroundColor: UIColor { return isPrivate ? PicsColors.almostBlack : PicsColors.almostLight }
    var barStyle: UIBarStyle { return isPrivate ? UIBarStyle.black : UIBarStyle.default }
    var textColor: UIColor { return isPrivate ? .lightText : .darkText}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backgroundColor
        guard let coll = collectionView else { return }
        coll.register(PicsCell.self, forCellWithReuseIdentifier: PicCellIdentifier)
        coll.delegate = self
        self.initNav(title: "Pics", large: false)
        initStyle()
        let profileIcon = #imageLiteral(resourceName: "ProfileIcon")
        self.navigationItem.leftBarButtonItems = [
            UIBarButtonItem(image: profileIcon, style: UIBarButtonItemStyle.plain, target: self, action: #selector(PicsVC.profileClicked(_:))),
//            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(PicsVC.demoClicked(_:)))
        ]
        let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        if isCameraAvailable {
            self.navigationItem.rightBarButtonItems = [
                UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(PicsVC.cameraClicked(_:))),
//                UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(PicsVC.refreshClicked(_:)))
            ]
        }
        self.socket.delegate = self
        LifeCycle.shared.renderer = self
        initAndLoad(forceSignIn: false)
    }
    
    @objc func demoClicked(_ button: UIBarButtonItem) {
        merge(gallery: PicMeta.randoms())
    }
    
    @objc func profileClicked(_ button: UIBarButtonItem) {
        let content = ProfilePopover(user: currentUser?.username, isPrivate: isPrivate, delegate: self)
        content.modalPresentationStyle = .popover
        guard let popover = content.popoverPresentationController else { return }
        popover.barButtonItem = button
        popover.delegate = content
//        let nav = UINavigationController(rootViewController: content)
//        nav.navigationItem.title = "Select gallery"
//        nav.navigationItem.rightBarButtonItems = [
//            UIBarButtonItem(barButtonSystemItem: .done, target: content, action: #selector(ProfilePopover.dismissSelf(_:)))
//        ]
        self.present(content, animated: true, completion: nil)
    }
    
    func reInit() {
        authCancellation?.cancel()
        authCancellation?.dispose()
        initAndLoad(forceSignIn: isPrivate)
    }
    
    private func initAndLoad(forceSignIn: Bool) {
        log.info("Initializing picture gallery with \(offlinePics.count) offline pics.")
        updateUI(needsToken: isPrivate && (isSignedIn || forceSignIn))
    }
    
    func reconnectAndSync() {
        updateUI(needsToken: isPrivate)
    }
    
    private func updateUI(needsToken: Bool) {
        mightHaveMore = true
        if needsToken {
            authCancellation = AWSCancellationTokenSource()
            Tokens.shared.retrieve(onToken: { (token) in
                self.load(with: token)
            }, onError: onLoadError, cancellationToken: authCancellation?.token)
        } else {
            // anonymous
            load(with: nil)
        }
    }
    
    private func load(with token: AWSCognitoIdentityUserSessionToken?) {
        Backend.shared.updateToken(new: token)
        self.socket.openSilently()
//        self.log.info("Loading pics...")
        self.syncPics()
        onUiThread {
            self.updateStyle()
        }
    }

    func syncPics() {
        networkActivity(visible: true)
        let syncLimit = max(loadedPics.count, PicsVC.itemsPerLoad)
        library.load(from: 0, limit: syncLimit, onError: onLoadError) { (result) in
            self.mightHaveMore = result.count >= syncLimit
            self.networkActivity(visible: false)
            self.onUiThread {
                self.merge(gallery: result)
            }
        }
    }
    
    func networkActivity(visible: Bool) {
        onUiThread {
            UIApplication.shared.isNetworkActivityIndicatorVisible = visible
        }
    }
    
    
    
    func loadPics(limit: Int) {
        let beforeCount = loadedPics.count
        let wasOffline = !isOnline
        networkActivity(visible: true)
        library.load(from: loadedPics.count, limit: limit, onError: onLoadError) { (result) in
            self.mightHaveMore = result.count >= limit
            self.onUiThread {
                self.networkActivity(visible: false)
                self.log.info("Loaded \(result.count) items, from \(beforeCount)")
                if self.loadedPics.count == beforeCount {
                    if !result.isEmpty {
                        self.pics = self.loadedPics + result.map { p in Picture(meta: p) }
                        let rows: [Int] = Array(beforeCount..<beforeCount+result.count)
                        
                        if wasOffline {
                            self.log.info("Replacing offline pics with fresh pics.")
                            self.isOnline = true
                            self.collectionView?.reloadData()
                            self.displayNoItemsIfEmpty()
                        } else {
                            let indexPaths = rows.map { row in IndexPath(item: row, section: 0) }
                            self.displayItems(at: indexPaths)
                        }
                    } else {
                        self.displayNoItemsIfEmpty()
                    }
                } else {
                    self.log.warn("Count mismatch")
                    self.displayNoItemsIfEmpty()
                }
            }
        }
    }
    
    func displayNoItemsIfEmpty() {
        if pics.isEmpty {
            onUiThread {
                self.displayText(text: "You have no pictures yet.")
            }
        }
    }
    
    func displayItems(at: [IndexPath]) {
        self.collectionView?.insertItems(at: at)
    }
    
    func updateStyle() {
        changeStyle(dark: isPrivate)
    }
    
    func changeStyle(dark: Bool) {
        UIView.animate(withDuration: 0.5) { () -> Void in
            self.initStyle()
            self.navigationController?.navigationBar.isHidden = false
        }
    }
    
    func initStyle() {
        self.view.backgroundColor = backgroundColor
        self.collectionView?.backgroundColor = backgroundColor
        self.navigationController?.navigationBar.barStyle = barStyle
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
        if let thumb = pic.small ?? cached(key: pic.meta.key) {
            cell.imageView.image = thumb
        } else {
            cell.imageView.image = nil
            download(indexPath)
        }
        cell.backgroundColor = cellBackgroundColor
        return cell
    }
    
    func cached(key: String) -> UIImage? {
        guard let data = LocalPics.shared.readSmall(key: key) else { return nil }
        return UIImage(data: data)
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        maybeLoadMore(atItemIndex: indexPath.row)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let dest = PicPagingVC(pics: self.pics, startIndex: indexPath.row, isPrivate: isPrivate, delegate: self)
        self.navigationController?.pushViewController(dest, animated: true)
    }
    
    private func download(_ indexPath: IndexPath) {
        let pic = pics[indexPath.row]
        if pic.small == nil {
            let key = pic.meta.key
            if let local = LocalPics.shared.readSmall(key: key) {
                updateSmall(data: local, indexPath: indexPath)
            } else {
                Downloader.shared.download(url: pic.meta.small) { data in
                    self.onDownloaded(key: key, data: data, indexPath: indexPath)
                }
            }
        }
    }
    
    private func onDownloaded(key: String, data: Data, indexPath: IndexPath) {
        let _ = LocalPics.shared.saveSmall(data: data, key: key)
        updateSmall(data: data, indexPath: indexPath)
    }
    
    private func updateSmall(data: Data, indexPath: IndexPath) {
        onUiThread {
            if let image = UIImage(data: data), let coll = self.collectionView, self.pics.count > indexPath.row {
                self.pics[indexPath.row].small = image
//                self.log.info("Reloading \(indexPath.row)")
                coll.reloadItems(at: [indexPath])
            } else {
                self.log.info("Unable to update downloaded pic count \(self.pics.count) \(self.isOnline) row \(indexPath.row) \(self.pics.count > indexPath.row)")
            }
        }
    }
    
    func maybeLoadMore(atItemIndex: Int) {
        let trackCount = pics.count
        if mightHaveMore && isOnline && atItemIndex + minItemsRemainingBeforeLoadMore == trackCount {
            loadMore(atItemIndex)
        }
    }
    
    func loadMore(_ atItemIndex: Int) {
        loadPics(limit: PicsVC.itemsPerLoad)
    }
    
    func onLoadError(error: AppError) {
        let message = AppError.stringify(error)
        // app no longer supported
        if case .responseFailure(let err) = error, err.code == 406 {
            onUiThread {
                self.navigationController?.navigationBar.isHidden = true
            }
        }
        log.error(message)
        if pics.isEmpty {
            log.info("Failed and empty, displaying text")
            displayText(text: message)
        } else {
            log.error("Failed and nonempty, noop.")
        }
        self.networkActivity(visible: false)
    }
    
    func displayText(text: String) {
        onUiThread {
            let feedbackLabel = PicsLabel.build(text: text, alignment: .center, numberOfLines: 0)
            feedbackLabel.textColor = self.textColor
            feedbackLabel.backgroundColor = self.backgroundColor
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
        self.present(control, animated: true, completion: nil)
    }
    
    @objc func refreshClicked(_ sender: UIBarButtonItem) {
        let loadLimit = max(pics.count, PicsVC.itemsPerLoad)
        resetDisplay()
        loadPics(limit: loadLimit)
    }
    
    @objc func changeUserClicked(_ sender: UIBarButtonItem) {
        signOutAndReload()
    }
    
    func signOutAndReload() {
        let wasSignedIn = isSignedIn
        pool.currentUser()?.signOut()
        pool.clearLastKnownUser()
        self.collectionView?.backgroundView = nil
        self.navigationController?.navigationBar.isHidden = true
        resetData()
        initAndLoad(forceSignIn: !wasSignedIn)
    }
    
    func resetData() {
        offlinePics = []
        loadedPics = []
        Tokens.shared.clearDelegates()
        socket.close()
        isOnline = false
        resetDisplay()
    }
    
    func resetDisplay() {
        self.pics = []
        collectionView?.reloadData()
    }
    
    func onPics(pics: [PicMeta]) {
        // By the time we get this notification, pics recently taken on this device are probably already displayed.
        // So we filter out already added pics to avoid duplicates.
        let (existingPics, newPics) = pics.partition(contains)
        onUiThread {
            existingPics.forEach(self.updateMeta)
        }
        log.info("Got \(pics.count) pic(s), out of which \(newPics.count) are new.")
        displayNewPics(pics: newPics.map { p in Picture(meta: p) })
    }
    
    func updateMeta(pic: PicMeta) {
        if let clientKey = pic.clientKey, let idx = self.indexFor(clientKey) {
            self.pics[idx] = self.pics[idx].withMeta(meta: pic)
        } else {
            log.info("Cannot update \(pic.key), pic not found in memory.")
        }
    }
    
    func indexFor(_ clientKey: String) -> Int? {
        return self.pics.index(where: { (p) -> Bool in
            p.meta.clientKey == clientKey
        })
    }
    
    func contains(pic: PicMeta) -> Bool {
        return self.pics.contains(where: { p -> Bool in (pic.clientKey != nil && p.meta.clientKey == pic.clientKey) || p.meta.key == pic.key })
    }
    
    func onPicsRemoved(keys: [String]) {
        removePicsLocally(keys: keys)
    }
    
    func removePic(key: String) {
        removePicsLocally(keys: [key])
        library.delete(key: key, onError: onRemoveError) { (response) in
            
        }
    }
    
    func onRemoveError(_ error: AppError) {
        log.error("Failed to remove pic.")
    }
    
    func removePicsLocally(keys: [String]) {
        onUiThread {
            let removables = self.pics.enumerated()
                .filter { (offset, pic) -> Bool in keys.contains(pic.meta.key)}
                .map { IndexPath(row: $0.offset, section: 0) }
            self.pics = self.pics.filter { !keys.contains($0.meta.key) }
            self.collectionView?.deleteItems(at: removables)
            self.displayNoItemsIfEmpty()
        }
    }
    
    func onProfile(info: ProfileInfo) {
        
    }
    
    func displayNewPics(pics: [Picture]) {
        onUiThread {
            let ordered: [Picture] = pics.reversed()
            self.pics = ordered + self.pics
            let indexPaths = ordered.enumerated().map({ (offset, pic) -> IndexPath in
                IndexPath(row: offset, section: 0)
            })
            self.displayItems(at: indexPaths)
        }
    }
    
    func merge(gallery: [PicMeta]) {
        onUiThread {
            self.log.info("Got gallery with \(gallery.count) pics")
            self.isOnline = true
            let old = self.pics
            self.pics = gallery.map { p in Picture(meta: p) }
            let newEntries = gallery.enumerated().filter({ (offset, elem) -> Bool in
                !old.contains(where: { $0.meta.key == elem.key })
            }).map({ (pair) -> IndexPath in
                let (index, _) = pair
                return IndexPath(row: index, section: 0)
            })
            // Probably buggy and crashes the app
            guard let coll = self.collectionView else { return }
            coll.performBatchUpdates({
                let renderedItems = self.collectionView?.numberOfItems(inSection: 0) ?? 0
                let (updates, inserts) = newEntries.partition { $0.row < renderedItems }
                coll.reloadItems(at: updates)
                coll.insertItems(at: inserts)
                let tail = old.count - gallery.count
                if tail > 0 {
                    self.log.info("Removing tail of \(tail) items")
                    let removed = (gallery.count..<(gallery.count + tail)).filter { $0 < renderedItems }.map { IndexPath(row: $0, section: 0) }
                    coll.deleteItems(at: removed)
                }
            }, completion: nil)
            
        }
    }
}

extension PicsVC: ProfileDelegate {
    func onPublic() {
        isPrivate = false
        updateUI(needsToken: false)
    }
    
    func onPrivate() {
        isPrivate = true
        updateUI(needsToken: true)
    }
    
    func onLogout() {
        signOutAndReload()
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
            log.error("Original image is not an UIImage")
            return
        }
        let pic = Picture(image: originalImage)
        displayNewPics(pics: [pic])
        guard let data = UIImageJPEGRepresentation(originalImage, 1) else {
            log.error("Taken image is not in JPEG format")
            return
        }
        log.info("Saving pic to file...")
        let url = try LocalPics.shared.saveAsJpg(data: data)
        let clientKey = pic.meta.clientKey ?? ""
        if let idx = indexFor(clientKey) {
            self.pics[idx] = self.pics[idx].withUrl(url: url)
        }
        library.saveURL(picture: url, clientKey: clientKey, onError: onSaveError) { pic in
            self.log.info("Uploaded pic \(clientKey).")
        }
    }
    
    func onSaveError(error: AppError) {
        let message = AppError.stringify(error)
        log.error("Unable to save pic: '\(message)'.")
    }
}
