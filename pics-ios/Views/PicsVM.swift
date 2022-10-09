import Foundation
import AWSCognitoIdentityProvider

class User {
    static let shared = User()
    
    var picsSettings: PicsSettings { PicsSettings.shared }
    var activeUser: Username? { picsSettings.activeUser }
    var isPrivate: Bool { activeUser != nil 		}
    var currentUsernameOrAnon: Username { activeUser ?? Username.anon }
    /// if true, reload the view on prep()
    var reload: Bool = false
}

protocol PicsVMLike: ObservableObject {
    var isOnline: Bool { get }
    var pics: [PicMeta] { get }
    var hasMore: Bool { get }
    var isPrivate: Bool { get }
    var showLogin: Bool { get set }
    var showNewPass: Bool { get set }
    var loginHandler: LoginHandler { get }
    var cacheSmall: DataCache { get }
    var cacheLarge: DataCache { get }
    func prep() async
    func loadMore() async
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async
    func display(newPics: [PicMeta]) async
    func remove(key: ClientKey) async
    func block(key: ClientKey) async
    func resetData() async
    func onPublic() async
    func onPrivate(user: Username) async
    func signOut() async
    
    func connect()
    func disconnect()
}

extension PicsVM: PicsDelegate {
    func onPics(pics: [PicMeta]) async {
        let (existingPics, newPics) = pics.partition(contains)
        existingPics.forEach { meta in
            updateMeta(pic: meta)
        }
        let picsToAdd = newPics.filter { pic in
            !isBlocked(pic: pic)
        }
        log.info("Adding \(picsToAdd.count) new pics.")
        let updated = picsToAdd.reversed() + self.pics
        await savePics(newPics: updated)
    }
    
    func onPicsRemoved(keys: [ClientKey]) async {
        await removeLocally(keys: keys)
    }
    
    func onProfile(info: ProfileInfo) async {
        
    }
    
    private func updateMeta(pic: PicMeta) {
        log.info("Metadata update not supported currently for \(pic.key).")
//        if let clientKey = pic.clientKey, let idx = indexFor(clientKey) {
//          self.pics[idx] = self.pics[idx].withMeta(meta: pic)
//        } else {
//            log.info("Cannot update \(pic.key), pic not found in memory.")
//        }
    }
    
    private func indexFor(_ clientKey: ClientKey) -> Int? {
        self.pics.firstIndex(where: { (p) -> Bool in
            p.clientKey == clientKey
        })
    }
    
    private func contains(pic: PicMeta) -> Bool {
        self.pics.contains(where: { p -> Bool in (pic.clientKey != nil && p.clientKey == pic.clientKey) || p.key == pic.key })
    }
}

class PicsVM: PicsVMLike {
    private let log = LoggerFactory.shared.vc(PicsVM.self)
    
    static let itemsPerLoad = 100
    static let preferredItemSize: Double = Devices.isIpad ? 200 : 130
    
    let user = User.shared
    
    @Published private(set) var isOnline = false
    var currentUsernameOrAnon: Username { user.currentUsernameOrAnon }
    var isPrivate: Bool { user.isPrivate }
    
    @Published var pics: [PicMeta] = []
    
    @Published private(set) var hasMore = false
    private var isInitial = true
    
    @Published var showLogin = false
    @Published var showNewPass = false
    
    private var backend: Backend { Backend.shared }
    private var library: PicsLibrary { backend.library }
    private var socket: PicsSocket { backend.socket }
    private var settings: PicsSettings { PicsSettings.shared }
    private var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    private var authCancellation: AWSCancellationTokenSource? = nil

    var cognito: CognitoDelegate? = nil
    var loginHandler: LoginHandler { cognito!.handler }
    
    let userChanged: (Username?) -> Void
    
    let cacheSmall = DataCache.small()
    let cacheLarge = DataCache.large()
    
    init(userChanged: @escaping (Username?) -> Void) {
        self.userChanged = userChanged
        socket.delegate = self
        let cognitoDelegate = CognitoDelegate(onShowLogin: {
            DispatchQueue.main.async {
                self.showLogin = true
            }
        }, onShowNewPass: {
            DispatchQueue.main.async {
                self.showNewPass = true
            }
        })
        cognito = cognitoDelegate
        Tokens.shared.pool.delegate = cognitoDelegate
    }
    
    func prep() async {
        if user.reload {
            user.reload = false
            await connectAsync()
        }
    }
    
    func connect() {
        Task {
            await connectAsync()
        }
    }
    
    func connectAsync() async {
        do {
            if !isOnline {
                let offlines = settings.localPictures(for: user.currentUsernameOrAnon)
                log.info("Loaded \(offlines.count) offline pics for \(user.currentUsernameOrAnon).")
                await loadOfflinePics(offlinePics: offlines)
            }
            if isPrivate {
                let userInfo = try await Tokens.shared.retrieveUserInfoAsync(cancellationToken: nil)
                backend.updateToken(new: userInfo.token)
            } else {
                backend.updateToken(new: nil)
            }
            socket.reconnect()
            let limit = max(100, self.pics.count)
            let batch = try await library.load(from: 0, limit: limit)
            await merge(onlinePics: batch, more: batch.count == limit)
        } catch let error {
            log.error("Failed to connect. \(error)")
            await updateOnline(online: false)
        }
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    private func merge(onlinePics: [PicMeta], more: Bool) async {
        let added = onlinePics.filter { meta in
            !isBlocked(pic: meta) && !contains(pic: meta)
        }
        let removed = self.pics.filter { old in
            !onlinePics.contains { pic in
                pic.key == pic.key
            }
        }
        if !added.isEmpty || !removed.isEmpty {
            log.info("Replacing gallery with \(onlinePics.count) pics. Added \(added.count) and removed \(removed.count) pics.")
            await savePics(newPics: onlinePics, more: more)
        } else {
            await updateOnline(online: true)
            log.info("Batch of \(onlinePics.count) pics up to date.")
        }
    }
    
    private func savePics(newPics: [PicMeta], more: Bool? = nil) async {
        await saveOnlinePics(newPics: newPics, more: more)
        
        let _ = self.settings.save(pics: newPics, for: self.currentUsernameOrAnon)
    }
    
    @MainActor
    private func loadOfflinePics(offlinePics: [PicMeta]) {
        pics = offlinePics
    }
    
    @MainActor
    private func saveOnlinePics(newPics: [PicMeta], more: Bool?) {
        isOnline = true
        pics = newPics
        if let more = more {
            hasMore = more
        }
    }
    
    @MainActor
    private func updateOnline(online: Bool) {
        isOnline = online
    }
    
    func loadMore() async {
        log.info("Loading more for \(self.currentUsernameOrAnon)...")
        await loadPicsAsync(for: user.activeUser, initialOnly: false)
    }
    
    @MainActor
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async {
        if !initialOnly || isInitial {
            isInitial = false
            if initialOnly {
                pics = []
                log.info("Offline count \(self.pics.count)")
            }
            do {
                if let user = user {
                    log.info("Loading pics for \(user)...")
                    authCancellation = AWSCancellationTokenSource()
                    let userInfo = try await Tokens.shared.retrieveUserInfoAsync(cancellationToken: authCancellation)
                    try await load(with: userInfo.token)
                } else {
                    log.info("Loading anon pics...")
                    try await load(with: nil)
                }
            } catch let error {
                onLoadError(error: error)
            }
        }
    }
    
    private func onLoadError(error: Error) {
        log.error("Load error \(error)")
    }
    
    func load(with token: AWSCognitoIdentityUserSessionToken?) async throws {
        backend.updateToken(new: token)
        try await appendPics()
    }
    
    private func appendPics(limit: Int = PicsVM.itemsPerLoad) async throws {
        let beforeCount = pics.count
        let batch = try await library.load(from: beforeCount, limit: limit)
        log.info("Got batch of \(batch.count) pics from index \(beforeCount) with limit \(limit).")
        let syncedBatch: [PicMeta] = batch.map { meta in
            let key = meta.key
            guard let url = LocalPics.shared.findLocal(key: key) else {
//                log.debug("Local not found for '\(key)'.")
                return meta
            }
            log.info("Found local URL '\(url)' for '\(key)'.")
            return meta.withUrl(url: url)
        }
        await savePics(newPics: self.pics + syncedBatch, more: batch.count == limit)
    }
    
    private func isBlocked(pic: PicMeta) -> Bool {
        settings.blockedImageKeys.contains { $0 == pic.key }
    }
    
    func remove(key: ClientKey) async {
        await removeLocally(keys: [key])
        do {
            let _ = try await library.delete(key: key)
        } catch let err {
            self.log.error("Failed to delete \(key). \(err)")
        }
    }
    
    func block(key: ClientKey) async {
        settings.block(key: key)
        await removeLocally(keys: [key])
    }
    
    func display(newPics: [PicMeta]) async {
        let newPicsNewestFirst: [PicMeta] = newPics.reversed()
        let prepended = newPicsNewestFirst + self.pics
        await savePics(newPics: prepended)
    }
    
    private func removeLocally(keys: [ClientKey]) async {
        await savePics(newPics: self.pics.filter { pic in !keys.contains { key in
            pic.key == key
        }})
    }
    
    @MainActor
    func resetData() async {
        Tokens.shared.clearDelegates()
        isOnline = false
        await savePics(newPics: [])
        isInitial = true
        settings.activeUser = nil
        await self.loadPicsAsync(for: nil, initialOnly: true)
    }
    
    func onPublic() async {
        await changeUser(to: nil)
    }
    
    func onPrivate(user: Username) async {
        await changeUser(to: user)
    }
    
    private func changeUser(to user: Username?) async {
        let changed = settings.activeUser != user
        if changed {
            settings.activeUser = user
            self.user.reload = true
            // This triggers a change in AppDelegate, recreating the view, which will call loadPicsAsync, which reloads pics
            self.userChanged(user)
            log.info("Current user is \(self.user.currentUsernameOrAnon)")
        }
    }
    
    @MainActor
    func signOut() async {
        log.info("Signing out...")
        pool.currentUser()?.signOut()
        pool.clearLastKnownUser()
        await resetData()
        adjustTitleTextColor(PicsColors.uiAlmostBlack)
        loginHandler.isComplete = false
    }
    
    private func adjustTitleTextColor(_ color: UIColor) {
        log.info("Adjusting title color")
    }
}

class PreviewPicsVM: PicsVMLike {
    var isOnline: Bool = false
    var pics: [PicMeta] = []
    var hasMore: Bool = false
    var isPrivate: Bool = false
    var showLogin: Bool = false
    var showNewPass: Bool = false
    var loginHandler: LoginHandler = LoginHandler()
    var cacheSmall: DataCache = DataCache()
    var cacheLarge: DataCache = DataCache()
    func prep() async {}
    func connect() {}
    func disconnect() {}
    func loadMore() async { }
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async { }
    func resetData() { }
    func onPublic() async { }
    func onPrivate(user: Username) async { }
    func signOut() { }
    func remove(key: ClientKey) { }
    func block(key: ClientKey) { }
    func display(newPics: [PicMeta]) { }
    func reInit() { }
    func changeStyle(dark: Bool) { }
}
