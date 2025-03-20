import 'package:boxify/app_core.dart';

/// Stores and manages the list of bundles available in the app,
/// and stores which bundles the user has purchased.
class BundleManager {
  // Singleton instance (for static access across the app)
  static final BundleManager _instance = BundleManager._internal();
  factory BundleManager() => _instance;
  BundleManager._internal();

  final Map<String, Bundle> _bundles = {};

  // List of owned bundle IDs
  final List<String> _ownedBundleIds = [];

  // Public accessor for bundles
  Map<String, Bundle> get bundles => Map.unmodifiable(_bundles);

  // List of all bundles
  List<Bundle> get bundlesList => _bundles.values.toList();

  // Update bundle list with new data. Will clear the existing data.
  Future<void> updateBundles(List<Bundle> bundles) async {
    _bundles.clear();
    for (var bundle in bundles) {
      if (bundle.id != null) {
        _bundles[bundle.id!] = bundle;
      }
    }
  }

  // Get bundle by ID
  Bundle? getBundle(String? id) {
    if (_bundles.containsKey(id)) {
      return _bundles[id];
    }
    return null;
  }

  // Is the bundle owned by the user?
  bool isOwned(String? id) {
    if (id == null) return false;
    return _ownedBundleIds.contains(id);
  }

  // Set owned bundle IDs
  void setOwnedBundleIds(List<String> ids) {
    logger.i('setOwnedBundleIds: $ids');
    _ownedBundleIds.clear();
    _ownedBundleIds.addAll(ids);
  }
}
