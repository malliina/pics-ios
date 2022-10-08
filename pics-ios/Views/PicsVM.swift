import Foundation
import AWSCognitoIdentityProvider

class User {
    static let shared = User()
    
    var picsSettings: PicsSettings { PicsSettings.shared }
    var activeUser: Username? { picsSettings.activeUser }
    var isPrivate: Bool { picsSettings.activeUser != nil 		}
    var currentUsernameOrAnon: Username { activeUser ?? Username.anon }
}

protocol PicsVMLike: ObservableObject, AuthInit {
    var isOnline: Bool { get }
    var pics: [PicMeta] { get }
    var hasMore: Bool { get }
    var isPrivate: Bool { get }
    var showLogin: Bool { get set }
    var showNewPass: Bool { get set }
    var loginHandler: LoginHandler { get }
    var cacheSmall: DataCache { get }
    var cacheLarge: DataCache { get }
    func loadMore() async
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async
    func display(newPics: [PicMeta]) async
    func remove(key: ClientKey) async
    func block(key: ClientKey) async
    func resetData() async
    func onPublic()
    func onPrivate(user: Username)
    func signOut() async
    
    func connect()
    func disconnect()
}

protocol AuthInit {
    func reInit() async
    func changeStyle(dark: Bool)
}

extension PicsVM: AuthInit {
    func reInit() async {
        authCancellation?.cancel()
        authCancellation?.dispose()
        await loadPicsAsync(for: user.activeUser, initialOnly: false)
    }
    
    func changeStyle(dark: Bool) {
        
    }
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
    var currentUsernameOrAnon: Username { User.shared.activeUser ?? Username.anon }
    
    @Published var pics: [PicMeta] = []
    private(set) var isPrivate = User.shared.isPrivate
    @Published private(set) var hasMore = false
    private var isInitial = true
    
    @Published var showLogin = false
    @Published var showNewPass = false
    
    private var library: PicsLibrary { Backend.shared.library }
    private var picsSettings: PicsSettings { PicsSettings.shared }
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    private var authCancellation: AWSCancellationTokenSource? = nil

    var cognito: CognitoDelegate? = nil
    var loginHandler: LoginHandler { cognito!.handler }
    
    var socket: PicsSocket { Backend.shared.socket }
    
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
    
    func connect() {
        Task {
            await connectAsync()
        }
    }
    
    func connectAsync() async {
        do {
            if isPrivate {
                let userInfo = try await Tokens.shared.retrieveUserInfoAsync(cancellationToken: nil)
                let authValue = PicsHttpClient.authValueFor(forToken: userInfo.token)
                socket.updateAuthHeader(with: authValue)
            }
            socket.reconnect()
            let batch = try await library.load(from: 0, limit: self.pics.count)
            log.info("Loaded batch of \(batch.count), syncing...")
            await merge(onlinePics: batch)
        } catch let error {
            log.error("Failed to sync. \(error)")
        }
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    private func merge(onlinePics: [PicMeta]) async {
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
            await savePics(newPics: onlinePics)
        }
    }
    
    private func savePics(newPics: [PicMeta], more: Bool? = nil) async {
        await saveOnlinePics(newPics: newPics, more: more)
        
        let _ = self.picsSettings.save(pics: newPics, for: self.currentUsernameOrAnon)
    }
    
    @MainActor
    private func saveOnlinePics(newPics: [PicMeta], more: Bool?) {
        isOnline = true
        pics = newPics
        if let more = more {
            hasMore = more
        }
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
        Backend.shared.updateToken(new: token)
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
        return PicsSettings.shared.blockedImageKeys.contains { $0 == pic.key }
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
        PicsSettings.shared.block(key: key)
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
        isPrivate = false
        await self.loadPicsAsync(for: nil, initialOnly: true)
    }
    
    func onPublic() {
        changeUser(to: nil)
        
    }
    
    func onPrivate(user: Username) {
        changeUser(to: user)
    }
    
    private func changeUser(to user: Username?) {
        let changed = picsSettings.activeUser != user
        if changed {
            picsSettings.activeUser = user
            // This triggers a change in AppDelegate, recreating the view
            self.userChanged(user)
            log.info("Current user is \(self.user.currentUsernameOrAnon)")
        }
    }
    
    @MainActor
    func signOut() async {
        log.info("Signing out...")
        pool.currentUser()?.signOut()
        pool.clearLastKnownUser()
        picsSettings.activeUser = nil
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
    func connect() {}
    func disconnect() {}
    func loadMore() async { }
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async { }
    func resetData() { }
    func onPublic() { }
    func onPrivate(user: Username) { }
    func signOut() { }
    func remove(key: ClientKey) { }
    func block(key: ClientKey) { }
    func display(newPics: [PicMeta]) { }
    func reInit() { }
    func changeStyle(dark: Bool) { }
}
