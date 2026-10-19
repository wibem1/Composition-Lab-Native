import Foundation

/// Mac persistence adapter. Keys are owned by SessionSecrets, never this cache.
@MainActor
final class NativeModelCatalogStore {
    private var catalogs: [String: [CatalogModel]] = [:]
    private let cacheKey = "CompositionLab.v4.modelCatalogs"
    init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let saved = try? JSONDecoder().decode([String: [CatalogModel]].self, from: data) { catalogs = saved }
    }
    func models(for provider: Provider) -> [CatalogModel] { catalogs[provider.rawValue] ?? [] }
    func accept(_ models: [CatalogModel], for provider: Provider) {
        guard !models.isEmpty else { return }
        catalogs[provider.rawValue] = models
        if let data = try? JSONEncoder().encode(catalogs) { UserDefaults.standard.set(data, forKey: cacheKey) }
    }
}
