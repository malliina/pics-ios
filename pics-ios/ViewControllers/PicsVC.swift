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
import Photos
import SwiftUI

protocol PicsRenderer {
    func reconnectAndSync()
}

protocol PicDelegate {
    func remove(key: ClientKey)
    func block(key: ClientKey)
}

extension PicsVC: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let row = indexPath.row
            if pics.count > row {
                let pic = pics[indexPath.row]
                if pic.small == nil {
                    self.download(indexPath, pic: pic)
                }
            }
        }
    }
}

class PicsVC: UICollectionViewController, UICollectionViewDelegateFlowLayout, PicsDelegate, PicsRenderer, CLLocationManagerDelegate {
    static let preferredItemSize: Double = Devices.isIpad ? 200 : 130
    static let itemsPerLoad = 100
    
    let log = LoggerFactory.shared.vc(PicsVC.self)
    let PicCellIdentifier = "PicCell"
    let minItemsRemainingBeforeLoadMore = 20
    
    private var mightHaveMore: Bool = true
    private var isOnline = false
    private var picsSettings: PicsSettings { PicsSettings.shared }
    
    private var offlinePics: [Picture] = []
    private var onlinePics: [Picture] = []
    private var pics: [Picture] {
        get { isOnline ? onlinePics : offlinePics }
        set (newPics) {
            let _ = picsSettings.save(pics: newPics, for: currentUsernameOrAnon)
            if isOnline {
                onlinePics = newPics
            } else {
                offlinePics = newPics
            }
        }
    }
    
    var library: PicsLibrary { Backend.shared.library }
    var socket: PicsSocket { Backend.shared.socket }
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    var authCancellation: AWSCancellationTokenSource? = nil
    
    var currentUser: AWSCognitoIdentityUser? { Tokens.shared.pool.currentUser() }
    var activeUser: Username? { picsSettings.activeUser }
    var isPrivate: Bool { picsSettings.activeUser != nil }
    var currentUsernameOrAnon: Username { activeUser ?? Username.anon }

    var backgroundColor: UIColor { isPrivate ? PicsColors.background : PicsColors.lightBackground }
    var cellBackgroundColor: UIColor { isPrivate ? PicsColors.almostBlack : PicsColors.almostLight }
    var titleTextColor: UIColor { isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    var textColor: UIColor { isPrivate ? .lightText : .darkText }
    
    var locs: CLLocationManager? = nil
    
    init() {
        let flow = UICollectionViewFlowLayout()
        flow.itemSize = CGSize(width: PicsVC.preferredItemSize, height: PicsVC.preferredItemSize)
        super.init(collectionViewLayout: flow)
        offlinePics = picsSettings.localPictures(for: currentUsernameOrAnon)
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
        loadPics(for: activeUser)
        locationServices()
    }
    
    func locationServices() {
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        log.info("Loc svc \(status) not determined = \(status == .notDetermined)")
        // Must assign to variable otherwise nothing works
        locs = manager
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        //manager.startUpdatingLocation()
        log.info("Loc svc started")
        //let _ = CLLocationManager.requestWhenInUseAuthorization(manager)
        
        // let photoStatus = PHPhotoLibrary.authorizationStatus()

        //if photoStatus == .notDetermined  {
        //    PHPhotoLibrary.requestAuthorization( { authStatus in
        //        self.log.info("Status \(authStatus)")
        //    })
        //}
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        log.info("Changed auth")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        log.info("Locations updated")
    }
    
//    @objc func helpClicked(_ button: UIBarButtonItem) {
//        guard let navController = self.navigationController else { return }
//        let dest = UIHostingController(rootView: PicsView(viewModel: PicsVM()))
//        navController.pushViewController(dest, animated: true)
//    }
    
    @objc func helpClicked(_ button: UIBarButtonItem) {
        let helpVC = UIHostingController(rootView: HelpView(isPrivate: isPrivate))
        let dest = UINavigationController(rootViewController: helpVC)
        dest.modalPresentationStyle = .formSheet
        // dest.navigationBar.barStyle = barStyle
        dest.navigationBar.prefersLargeTitles = true
        present(dest, animated: true, completion: nil)
    }
    
    @objc func profileClicked(_ button: UIBarButtonItem) {
        let content = ProfilePopover(user: activeUser, delegate: self)
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
        loadPics(for: activeUser)
    }
    
    func reconnectAndSync() {
        if let user = activeUser {
            loadPrivatePics(for: user)
        } else {
            loadAnonymousPics()
        }
    }
    
    private func loadPics(for user: Username?) {
        if let user = user {
            loadPrivatePics(for: user)
        } else {
            loadAnonymousPics()
        }
    }
    
    private func loadPrivatePics(for user: Username) {
        mightHaveMore = true
        authCancellation = AWSCancellationTokenSource()
        let _ = Tokens.shared.retrieveUserInfo(cancellationToken: authCancellation).subscribe { event in
            switch event {
            case .success(let userInfo):
                self.load(with: userInfo.token)
                self.library.syncOffline(for: userInfo.username)
            case .failure(let error):
                self.onLoadError(error: error)
            }
        }
    }
    
    private func loadAnonymousPics() {
        mightHaveMore = true
        load(with: nil)
    }
    
    private func load(with token: AWSCognitoIdentityUserSessionToken?) {
        Backend.shared.updateToken(new: token)
        self.socket.connect()
        self.syncPics()
        onUiThread {
            self.updateStyle()
        }
    }

    // Called on first load
    func syncPics() {
        let syncLimit = max(onlinePics.count, PicsVC.itemsPerLoad)
        withLoading(from: 0, limit: syncLimit, f: self.merge)
    }
    
    // Called when more pics are needed (while scrolling down)
    func appendPics(limit: Int) {
        let beforeCount = onlinePics.count
        let wasOffline = !isOnline
        log.info("Loading from \(beforeCount) with limit \(limit)")
        withLoading(from: beforeCount, limit: limit) { (filtered) in
            self.log.info("Got \(filtered.count) pics from \(beforeCount) with limit \(limit).")
            if self.onlinePics.count == beforeCount {
                if !filtered.isEmpty {
                    self.pics = self.onlinePics + filtered.map { p in Picture(meta: p) }
                    let rows: [Int] = Array(beforeCount..<beforeCount+filtered.count)
                    if wasOffline {
                        self.log.info("Replacing offline pics with fresh pics.")
                        self.isOnline = true
                        self.collectionView?.reloadData()
                        self.renderMessageIfEmpty()
                    } else {
                        let indexPaths = rows.map { row in IndexPath(item: row, section: 0) }
                        self.displayItems(at: indexPaths)
                    }
                } else {
                    self.displayNoItemsIfEmpty()
                }
            } else {
                self.log.warn("Count mismatch. Before \(beforeCount) now \(self.onlinePics.count).")
                self.displayNoItemsIfEmpty()
            }
        }
    }
    
    private func withLoading(from: Int, limit: Int, f: @escaping ([PicMeta]) -> Void) {
        networkActivity(visible: true)
        let _ = library.load(from: from, limit: limit).subscribe { (event) in
            switch event {
            case .success(let result):
                self.mightHaveMore = result.count >= limit
                self.onUiThread {
                    self.renderNetworkActivity(visible: false)
                    let filtered = result.filter { pic in !self.isBlocked(pic: pic) }
                    f(filtered)
                }
            case .failure(let error):
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
            self.renderMessageIfEmpty()
        }
    }
    
    func renderMessageIfEmpty(message: String? = nil) {
        if self.pics.isEmpty {
            self.displayText(text: message ?? "You have no pictures yet.")
        } else {
            self.collectionView?.backgroundView = nil
        }
    }
    
    func displayItems(at: [IndexPath]) { self.collectionView?.insertItems(at: at) }
    
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
        view.backgroundColor = backgroundColor
        collectionView?.backgroundColor = backgroundColor
        // navigationController?.navigationBar.barStyle = barStyle
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: titleTextColor]
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return PicsCell.sizeForItem(minWidthPerItem: PicsVC.preferredItemSize, totalWidth: Double(view.frame.width)).sizePerItem
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
//        if pic.meta.small.isFileURL {
//            log.info("File \(pic.meta.small) exists \(pic.meta.small.exists)")
//        }
        if let thumb = pic.small {
            cell.imageView.image = thumb
        } else {
            cell.imageView.image = nil
            self.download(indexPath, pic: pic)
        }
        return cell
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
                    self.log.info("Updating locally \(indexPath.row)")
                    self.updateSmall(data: data, indexPath: indexPath, pic: pic)
                } else {
                    self.log.info("Downloading \(indexPath.row)")
                    Downloader.shared.download(url: pic.meta.small) { data in
                        self.onDownloaded(key: key, data: data, indexPath: indexPath, pic: pic)
                    }
                }
            }
        }
    }
    
    private func updateSmall(data: Data, indexPath: IndexPath, pic: Picture) {
        onUiThread {
            if let image = UIImage(data: data) {
                if let coll = self.collectionView, self.pics.count > indexPath.row {
//                    pic.small = image
                    coll.reloadItems(at: [indexPath])
                } else {
                    self.log.info("Unable to update downloaded pic. count \(self.pics.count) \(self.isOnline) row \(indexPath.row) \(self.pics.count > indexPath.row)")
                }
            } else {
                self.log.info("Unable to update downloaded pic. Element \(indexPath.row) is not an image.")
            }
        }
    }
    
    private func onDownloaded(key: ClientKey, data: Data, indexPath: IndexPath, pic: Picture) {
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
            let errorMessage = error.localizedDescription
            log.error("Error \(errorMessage)")
            let message = errorMessage == AppError.noInternetMessage ? "No pictures to show. \(AppError.noInternetMessage)" : "An error occurred. Try again later."
            onUiThread {
                self.renderMessageIfEmpty(message: message)
            }
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
    
    func signOut() {
        pool.currentUser()?.signOut()
        pool.clearLastKnownUser()
        picsSettings.activeUser = nil
        self.collectionView?.backgroundView = nil
        self.navigationController?.navigationBar.isHidden = true
        resetData()
        loadPics(for: activeUser)
    }
    
    func resetData() {
        offlinePics = []
        onlinePics = []
        Tokens.shared.clearDelegates()
        socket.disconnect()
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
        display(newPics: newPics.filter { !isBlocked(pic: $0) }.map { p in Picture(meta: p) })
    }
    
    private func updateMeta(pic: PicMeta) {
        if let clientKey = pic.clientKey, let idx = self.indexFor(clientKey) {
//            self.pics[idx] = self.pics[idx].withMeta(meta: pic)
        } else {
            log.info("Cannot update \(pic.key), pic not found in memory.")
        }
    }
    
    private func indexFor(_ clientKey: ClientKey) -> Int? {
        self.pics.firstIndex(where: { (p) -> Bool in
            p.meta.clientKey == clientKey
        })
    }
    
    private func contains(pic: PicMeta) -> Bool {
        self.pics.contains(where: { p -> Bool in (pic.clientKey != nil && p.meta.clientKey == pic.clientKey) || p.meta.key == pic.key })
    }
    
    func onPicsRemoved(keys: [ClientKey]) {
        removePicsLocally(keys: keys)
    }
    
    private func removePicsLocally(keys: [ClientKey]) {
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
    
    func display(newPics: [Picture]) {
        onUiThread {
            let newPicsNewestFirst: [Picture] = newPics.reversed()
            self.pics = newPicsNewestFirst + self.pics
            let indexPaths = newPicsNewestFirst.enumerated().map { (offset, pic) -> IndexPath in
                IndexPath(row: offset, section: 0)
            }
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
//                    merged.url = oldPic.url
//                    merged.small = oldPic.small
//                    merged.medium = oldPic.medium
//                    merged.large = oldPic.large
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
            self.renderMessageIfEmpty()
        }
    }
}

extension PicsVC: PicDelegate {
    func remove(key: ClientKey) {
        removePicsLocally(keys: [key])
        let _ = library.delete(key: key).subscribe { (event) in
            switch event {
            case .success(let response):
                self.log.info("Deletion completed with status \(response.statusCode).")
            case .failure(let error):
                if let error = error as? AppError {
                    self.onRemoveError(error)
                } else {
                    self.log.error("Delete error. \(error)")
                }
            }
        }
    }
    
    func block(key: ClientKey) {
        PicsSettings.shared.block(key: key)
        removePicsLocally(keys: [key])
    }
    
    func onRemoveError(_ error: AppError) {
        log.error("Failed to remove pic.")
    }
}

extension PicsVC: ProfileDelegate {
    func onPublic() {
        picsSettings.activeUser = nil
        onUiThread {
            self.offlinePics = self.picsSettings.localPictures(for: Username.anon)
            self.collectionView?.reloadData()
        }
        loadAnonymousPics()
        log.info("Current user is \(currentUsernameOrAnon)")
    }
    
    func onPrivate(user: Username) {
        picsSettings.activeUser = user
        onUiThread {
            self.offlinePics = self.picsSettings.localPictures(for: user)
            self.updateStyle()
            self.collectionView?.reloadData()
        }
        loadPrivatePics(for: user)
    }
    
    func onLogout() {
        signOut()
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) { () in
            self.onBackgroundThread {
                do {
                    try self.handleMedia(info: info)
                } catch let err {
                    self.log.info("Failed to save picture. \(err)")
                }
            }
        }
    }
    
    func handleMedia(info: [UIImagePickerController.InfoKey: Any]) throws {
        log.info("Pic taken, processing...")
        guard let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            log.error("Original image is not an UIImage")
            return
        }
        // let what = info[.phAsset]
        if let pha = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset {
            let loc = pha.location
            if let coordinate = loc?.coordinate {
                log.info("Latitude \(coordinate.latitude) longitude \(coordinate.longitude).")
            } else {
                log.info("Got PHAsset, but no coordinate.")
            }
        } else {
            log.info("No PHAsset")
        }
        
        
        let clientKey = ClientKey.random()
        let pic = Picture(image: originalImage, clientKey: clientKey)
        guard let data = originalImage.jpegData(compressionQuality: 1) else {
            log.error("Taken image is not in JPEG format")
            return
        }
        log.info("Saving pic to file, in total \(data.count) bytes...")
        UIImageWriteToSavedPhotosAlbum(originalImage, nil, nil, nil)
        if let user = activeUser {
            log.info("Staging then uploading image taken by \(user)...")
            // Copies the picture to a staging folder
            let _ = try LocalPics.shared.saveUserPic(data: data, owner: user, key: clientKey)
            // Attempts to obtain a token and upload the pic
            let _ = Backend.shared.library.syncPicsForLatestUser()
        } else {
            // Anonymous upload
            let url = try LocalPics.shared.saveAsJpg(data: data, key: clientKey)
            library.uploadPic(picture: url, clientKey: clientKey)
        }
        display(newPics: [pic])
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

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
