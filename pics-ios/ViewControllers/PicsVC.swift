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
import MessageUI

protocol PicsRenderer {
    func reconnectAndSync()
}

protocol PicDelegate {
    func remove(key: String)
    func block(key: String)
}

extension PicsVC: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let row = indexPath.row
            if pics.count > row {
                let pic = pics[indexPath.row]
                if pic.small == nil {
//                    log.info("Prefetching \(pic.meta.key)")
                    self.download(indexPath, pic: pic)
                }
            }
        }
    }
}

class PicsVC: UICollectionViewController, UICollectionViewDelegateFlowLayout, PicsDelegate, PicsRenderer {
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
    var barStyle: UIBarStyle { return isPrivate ? .black : .default }
    var textColor: UIColor { return isPrivate ? .lightText : .darkText }
    
    init() {
        let flow = UICollectionViewFlowLayout()
        flow.itemSize = CGSize(width: PicsVC.preferredItemSize, height: PicsVC.preferredItemSize)
        super.init(collectionViewLayout: flow)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backgroundColor
        guard let coll = collectionView else { return }
        coll.register(PicsCell.self, forCellWithReuseIdentifier: PicCellIdentifier)
        coll.delegate = self
        coll.prefetchDataSource = self
        self.initNav(title: "Pics", large: false)
        initStyle()
        self.navigationItem.leftBarButtonItems = [
            UIBarButtonItem(image: #imageLiteral(resourceName: "ProfileIcon"), style: .plain, target: self, action: #selector(profileClicked(_:))),
            UIBarButtonItem(image: #imageLiteral(resourceName: "HelpIcon"), style: .plain, target: self, action: #selector(helpClicked(_:)))
        ]
        let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        if isCameraAvailable {
            self.navigationItem.rightBarButtonItems = [
                UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(cameraClicked(_:))),
            ]
        }
        self.socket.delegate = self
        LifeCycle.shared.renderer = self
        initAndLoad(forceSignIn: false)
    }
    
    @objc func helpClicked(_ button: UIBarButtonItem) {
        let helpVC = HelpVC(isPrivate: isPrivate)
        let dest = UINavigationController(rootViewController: helpVC)
        dest.modalPresentationStyle = .formSheet
        dest.navigationBar.barStyle = barStyle
        dest.navigationBar.prefersLargeTitles = true
        present(dest, animated: true, completion: nil)
    }
    
    @objc func profileClicked(_ button: UIBarButtonItem) {
        let content = ProfilePopover(user: currentUser?.username, isPrivate: isPrivate, delegate: self)
        content.modalPresentationStyle = .popover
        if let popover = content.popoverPresentationController {
            popover.barButtonItem = button
            popover.delegate = content
        }
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
            let _ = Tokens.shared.retrieve(cancellationToken: authCancellation).subscribe { (event) in
                guard !event.isCompleted else { return }
                if let token = event.element {
                    self.load(with: token)
                    if let user = self.currentUser?.username {
                        self.library.syncOffline(for: user)
                    }
                }
                if let error = event.error {
                    self.onLoadError(error: error)
                }
            }
        } else {
            // anonymous
            load(with: nil)
        }
    }
    
    private func load(with token: AWSCognitoIdentityUserSessionToken?) {
        Backend.shared.updateToken(new: token)
        self.socket.openSilently()
        self.syncPics()
        onUiThread {
            self.updateStyle()
        }
    }

    // Called on first load
    func syncPics() {
        let syncLimit = max(loadedPics.count, PicsVC.itemsPerLoad)
        withLoading(from: 0, limit: syncLimit, f: self.merge)
    }
    
    // Called when more pics are needed (while scrolling down)
    func appendPics(limit: Int) {
        let beforeCount = loadedPics.count
        let wasOffline = !isOnline
        withLoading(from: beforeCount, limit: limit) { (filtered) in
            if self.loadedPics.count == beforeCount {
                if !filtered.isEmpty {
                    self.pics = self.loadedPics + filtered.map { p in Picture(meta: p) }
                    let rows: [Int] = Array(beforeCount..<beforeCount+filtered.count)
                    if wasOffline {
                        self.log.info("Replacing offline pics with fresh pics.")
                        self.isOnline = true
                        self.collectionView?.reloadData()
                        self.renderNoItemsIfEmpty()
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
    
    private func withLoading(from: Int, limit: Int, f: @escaping ([PicMeta]) -> Void) {
        networkActivity(visible: true)
        let _ = library.load(from: from, limit: limit).subscribe { (event) in
            guard !event.isCompleted else { return }
            if let result = event.element {
                self.mightHaveMore = result.count >= limit
                self.onUiThread {
                    self.renderNetworkActivity(visible: false)
                    let filtered = result.filter { pic in !self.isBlocked(pic: pic) }
                    f(filtered)
                }
            }
            if let error = event.error {
                self.onLoadError(error: error)
            }
        }
    }
    
    func networkActivity(visible: Bool) {
        onUiThread {
            self.renderNetworkActivity(visible: visible)
        }
    }
    
    func renderNetworkActivity(visible: Bool) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = visible
    }
    
    func isBlocked(pic: PicMeta) -> Bool {
        return PicsSettings.shared.blockedImageKeys.contains { $0 == pic.key }
    }
    
    func displayNoItemsIfEmpty() {
        onUiThread {
            self.renderNoItemsIfEmpty()
        }
    }
    
    func renderNoItemsIfEmpty() {
        if self.pics.isEmpty {
            self.displayText(text: "You have no pictures yet.")
        } else {
            self.collectionView?.backgroundView = nil
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
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pics.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PicCellIdentifier, for: indexPath) as! PicsCell
        cell.backgroundColor = cellBackgroundColor
        let pic = pics[indexPath.row]
        if let thumb = pic.small {
            cell.imageView.image = thumb
        } else {
            cell.imageView.image = nil
//            log.info("Fetching \(pic.meta.key)")
            self.download(indexPath, pic: pic)
        }
        return cell
    }
    
    func cached(key: String) -> UIImage? {
        guard let data = LocalPics.shared.readSmall(key: key) else { return nil }
        return UIImage(data: data)
    }
    
    func loadCached(key: String, onData: @escaping (Data?) -> Void) {
        onBackgroundThread {
            let file = LocalPics.shared.readSmall(key: key)
            onData(file)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        maybeLoadMore(atItemIndex: indexPath.row)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let dest = PicPagingVC(pics: self.pics, startIndex: indexPath.row, isPrivate: isPrivate, delegate: self)
        self.navigationController?.pushViewController(dest, animated: true)
    }
    
    private func download(_ indexPath: IndexPath, pic: Picture) {
        if pic.small == nil {
            let key = pic.meta.key
            onBackgroundThread {
                if let data = LocalPics.shared.readSmall(key: key) {
                    self.updateSmall(data: data, indexPath: indexPath, pic: pic)
                } else {
                    Downloader.shared.download(url: pic.meta.small) { data in
                        self.onDownloaded(key: key, data: data, indexPath: indexPath, pic: pic)
                    }
                }
            }
        }
    }
    
    private func updateSmall(data: Data, indexPath: IndexPath, pic: Picture) {
        onUiThread {
            if let image = UIImage(data: data), let coll = self.collectionView, self.pics.count > indexPath.row {
                pic.small = image
                coll.reloadItems(at: [indexPath])
            } else {
                self.log.info("Unable to update downloaded pic count \(self.pics.count) \(self.isOnline) row \(indexPath.row) \(self.pics.count > indexPath.row)")
            }
        }
    }
    
    private func onDownloaded(key: String, data: Data, indexPath: IndexPath, pic: Picture) {
        let _ = LocalPics.shared.saveSmall(data: data, key: key)
        updateSmall(data: data, indexPath: indexPath, pic: pic)
    }
    
    func maybeLoadMore(atItemIndex: Int) {
        let trackCount = pics.count
        if mightHaveMore && isOnline && atItemIndex + minItemsRemainingBeforeLoadMore == trackCount {
            loadMore(atItemIndex)
        }
    }
    
    func loadMore(_ atItemIndex: Int) {
        appendPics(limit: PicsVC.itemsPerLoad)
    }
    
    func onLoadError(error: Error) {
        self.networkActivity(visible: false)
        if let error = error as? AppError {
            let message = error.describe
            log.error(message)
            // app no longer supported
            if case .responseFailure(let err) = error, err.code == 406 {
                onUiThread {
                    self.navigationController?.navigationBar.isHidden = true
                    self.displayText(text: message)
                }
            } else {
                if pics.isEmpty {
                    log.info("Failed and empty, displaying text")
                    displayText(text: message)
                } else {
                    log.error("Failed and nonempty, noop.")
                }
            }
        } else {
            log.error("Unknown error \(error)")
        }
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
    
    @objc func changeUserClicked(_ sender: UIBarButtonItem) {
        signOutOrReloadUser()
    }
    
    func signOutOrReloadUser() {
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
    
    private func resetDisplay() {
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
        displayNewPics(pics: newPics.filter { !isBlocked(pic: $0) }.map { p in Picture(meta: p) })
    }
    
    private func updateMeta(pic: PicMeta) {
        if let clientKey = pic.clientKey, let idx = self.indexFor(clientKey) {
            self.pics[idx] = self.pics[idx].withMeta(meta: pic)
        } else {
            log.info("Cannot update \(pic.key), pic not found in memory.")
        }
    }
    
    private func indexFor(_ clientKey: String) -> Int? {
        return self.pics.index(where: { (p) -> Bool in
            p.meta.clientKey == clientKey
        })
    }
    
    private func contains(pic: PicMeta) -> Bool {
        return self.pics.contains(where: { p -> Bool in (pic.clientKey != nil && p.meta.clientKey == pic.clientKey) || p.meta.key == pic.key })
    }
    
    func onPicsRemoved(keys: [String]) {
        removePicsLocally(keys: keys)
    }
    
    private func removePicsLocally(keys: [String]) {
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
            let old = self.pics
            self.log.info("Got gallery with \(gallery.count) pics, had \(old.count)")
            self.isOnline = true
            let syncedPics = gallery.map { p -> Picture in
                let merged = Picture(meta: p)
                if let oldPic = old.first(where: { $0.meta.key == p.key }) {
                    merged.url = oldPic.url
                    merged.small = oldPic.small
                    merged.medium = oldPic.medium
                    merged.large = oldPic.large
                }
                return merged
            }
            self.pics = syncedPics
            
            // Indices of pics in syncedPics which are not in old
            let inserts = syncedPics.distinctIndices(other: old) { (elem, other) -> Bool in elem.meta.key == other.meta.key }
                .map { (idx) -> IndexPath in IndexPath(row: idx, section: 0) }
            // Indices of pics in old which are not in gallery (before any modifications)
            let removes = old.distinctIndices(other: syncedPics) { (elem, other) -> Bool in elem.meta.key == other.meta.key }
                .map { (idx) -> IndexPath in IndexPath(row: idx, section: 0) }
            if !inserts.isEmpty || !removes.isEmpty {
                guard let coll = self.collectionView else { return }
                coll.performBatchUpdates({
                    coll.insertItems(at: inserts)
                    coll.deleteItems(at: removes)
                }, completion: nil)
            }
            self.renderNoItemsIfEmpty()
        }
    }
}

extension PicsVC: PicDelegate {
    func remove(key: String) {
        removePicsLocally(keys: [key])
        let _ = library.delete(key: key).subscribe { (event) in
            guard !event.isCompleted else { return }
            if let response = event.element {
                self.log.info("Deletion completed with status \(response.statusCode).")
            } else if let error = event.error {
                if let error = error as? AppError {
                    self.onRemoveError(error)
                } else {
                    self.log.error("Delete error. \(error)")
                }
            } else {
                // completed
            }
        }
    }
    
    func block(key: String) {
        PicsSettings.shared.block(key: key)
        removePicsLocally(keys: [key])
    }
    
    func onRemoveError(_ error: AppError) {
        log.error("Failed to remove pic.")
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
        signOutOrReloadUser()
    }
}

extension PicsVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func showCamera() {
        let control = UIImagePickerController()
        control.sourceType = .camera
        control.allowsEditing = false
        control.delegate = self
        self.present(control, animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        // Local variable inserted by Swift 4.2 migrator.
//        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        picker.dismiss(animated: true) { () in
            self.onBackgroundThread {
                do {
                    try self.handleMedia(info: info)
                } catch {
                    self.log.info("Failed to save picture")
                }
            }
        }
    }
    
    func handleMedia(info: [String: Any]) throws {
        log.info("Pic taken, processing...")
        guard let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            log.error("Original image is not an UIImage")
            return
        }
        let clientKey = Picture.randomKey()
        let pic = Picture(image: originalImage, clientKey: clientKey)
        displayNewPics(pics: [pic])
        guard let data = UIImageJPEGRepresentation(originalImage, 1) else {
            log.error("Taken image is not in JPEG format")
            return
        }
        
        log.info("Saving pic to file, in total \(data.count) bytes...")
        let url = try LocalPics.shared.saveAsJpg(data: data)
        onUiThread {
            if let idx = self.indexFor(clientKey) {
                self.pics[idx] = self.pics[idx].withUrl(url: url)
            }
        }
        if isPrivate {
            // This should return the last logged in user, even if we're currently offline
            if let user = currentUser?.username {
                // Copy file to folder
                // On new token, check folder
                // Upload oldest first from folder using token
                let _ = try LocalPics.shared.saveUserPic(data: data, owner: user)
                let _ = Tokens.shared.retrieve(cancellationToken: nil).subscribe { (event) in
                    guard !event.isCompleted else { return }
                    if let token = event.element {
                        Backend.shared.updateToken(new: token)
                        if let user = self.currentUser?.username {
                            self.library.syncOffline(for: user)
                        }
                    }
                    if let error = event.error {
                        self.log.error("Unable to sync pic. No network? \(error)")
                    }
                }
            } else {
                log.warn("Unknown username of private user. Cannot save picture.")
                presentAlert(title: "Error", message: "Failed to save picture. Try again later.", buttonText: "OK")
            }
        } else {
            library.uploadPic(picture: url, clientKey: clientKey)
        }
    }
    
    func onSaveError(error: AppError) {
        let message = AppError.stringify(error)
        log.error("Unable to save pic: '\(message)'.")
    }
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let hexDigits = Array((options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef").utf16)
        var chars: [unichar] = []
        chars.reserveCapacity(2 * count)
        for byte in self {
            chars.append(hexDigits[Int(byte / 16)])
            chars.append(hexDigits[Int(byte % 16)])
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}
