import Combine
import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteDeviceIDs: Set<String>

    private let defaults: UserDefaults
    private let favoritesKey = "nearble.favorite-device-ids"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedIDs = defaults.array(forKey: favoritesKey) as? [String] ?? []
        favoriteDeviceIDs = Set(savedIDs)
    }

    var favoritesCount: Int {
        favoriteDeviceIDs.count
    }

    func isFavorite(deviceID: UUID) -> Bool {
        favoriteDeviceIDs.contains(deviceID.uuidString.lowercased())
    }

    func toggle(deviceID: UUID) {
        let normalizedID = deviceID.uuidString.lowercased()

        if favoriteDeviceIDs.contains(normalizedID) {
            favoriteDeviceIDs.remove(normalizedID)
        } else {
            favoriteDeviceIDs.insert(normalizedID)
        }

        defaults.set(Array(favoriteDeviceIDs).sorted(), forKey: favoritesKey)
    }
}
