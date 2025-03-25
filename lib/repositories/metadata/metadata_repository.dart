import 'package:boxify/app_core.dart';
import 'package:boxify/repositories/metadata/base_metadata_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Import connectivity package

// Define custom exceptions for clarity
class NoConnectionException implements Exception {
  final String message;
  NoConnectionException(this.message);
}

class DataFetchException implements Exception {
  final String message;
  DataFetchException(this.message);
}

class CacheException implements Exception {
  final String message;
  CacheException(this.message);
}

class MetaDataRepository extends BaseMetaDataRepository {
  MetaDataRepository({
    FirebaseFirestore? firebaseFirestore,
    required this.cacheHelper, // Inject CacheHelper
  }) : _firebaseFirestore = firebaseFirestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firebaseFirestore;
  final CacheHelper cacheHelper; // For caching data locally
  static const String KEY_SERVER_TIMESTAMPS = 'server_timestamps';

  @override
  Future<Map<String, DateTime>> getLastUpdatedTimestamps() async {
    // Check connectivity status
    if (ConnectivityManager.instance.currentStatus == ConnectivityResult.none) {
      // Offline, try to get cached data
      final cachedTimestamps = await cacheHelper.getServerTimestamps();
      if (cachedTimestamps != null && cachedTimestamps.isNotEmpty) {
        return cachedTimestamps;
      } else {
        throw NoConnectionException(
            'No internet connection and no cached data available.');
      }
    } else {
      // Online, proceed to fetch from Firestore
      try {
        Map<String, DateTime> serverTimestamps = {};

        List<String> collections = [
          Paths.purchases,
          Paths.bundles,
          Paths.tracks,
          Paths.playlists,
          Paths.ratings,
          Paths.users,
        ];

        for (String collection in collections) {
          DateTime lastUpdated = await getCollectionLastUpdatedTimestamp(
            collection,
          );
          serverTimestamps[collection] = lastUpdated;
        }

        // Cache the fetched timestamps locally
        await cacheHelper.saveServerTimestamps(serverTimestamps);

        return serverTimestamps;
      } catch (e) {
        // Handle exceptions and try to return cached data
        logger.e('Error fetching server timestamps: $e');

        final cachedTimestamps = await cacheHelper.getServerTimestamps();
        if (cachedTimestamps != null && cachedTimestamps.isNotEmpty) {
          return cachedTimestamps;
        } else {
          throw DataFetchException(
              'Failed to fetch server timestamps and no cached data available.');
        }
      }
    }
  }

  Future<DateTime> getCollectionLastUpdatedTimestamp(
      String collectionName) async {
    try {
      // Fetch metadata document for the specified collection
      DocumentSnapshot metadataDoc = await _firebaseFirestore
          .collection('metadata')
          .doc(collectionName)
          .get();

      if (metadataDoc.exists && metadataDoc.data() != null) {
        // Access 'last_updated' field
        Map<String, dynamic> data = metadataDoc.data() as Map<String, dynamic>;
        Timestamp lastUpdatedTimestamp = data['last_updated'] as Timestamp;

        // Convert Timestamp to DateTime
        return lastUpdatedTimestamp.toDate();
      } else {
        logger.e(
            'Metadata document for the "$collectionName" collection does not exist or has no data.');
        // Return a default DateTime or handle as per your application's needs
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    } catch (e) {
      // Handle errors (e.g., network issues, permission problems)
      logger.e('Error fetching last updated timestamp for $collectionName: $e');
      // Rethrow the exception to be handled in getLastUpdatedTimestamps
      throw e;
    }
  }
}


// class MetaDataRepository extends BaseMetaDataRepository {
//   MetaDataRepository({FirebaseFirestore? firebaseFirestore})
//       : _firebaseFirestore = firebaseFirestore ?? FirebaseFirestore.instance;
//   final FirebaseFirestore _firebaseFirestore;

//   // Map representation of server timestamps
//   // Assuming this is fetching from some store e.g., Firestore, HTTP API etc.
//   @override
//   Future<Map<String, DateTime>> getLastUpdatedTimestamps() async {
//     // Create a map to hold the timestamps
//     Map<String, DateTime> serverTimestamps = {};

//     // Assuming you will have a function to get the last timestamp from each collection
//     // You should replace 'getCollectionLastUpdatedTimestamp' with your actual function
//     // that retrieves the timestamp from the server.
//     List<String> collections = [
//       Paths.purchases,
//       Paths.bundles,
//       Paths.tracks,
//       Paths.playlists,
//       Paths.ratings,
//       Paths.users,
//     ];
//     for (String collection in collections) {
//       DateTime lastUpdated = await getCollectionLastUpdatedTimestamp(
//         collection,
//       );
//       serverTimestamps[collection] = lastUpdated;
//     }
//     return serverTimestamps;
//   }

//   Future<DateTime> getCollectionLastUpdatedTimestamp(
//       String collectionName) async {
//     final FirebaseFirestore firestore = FirebaseFirestore.instance;
//     try {
//       // nothing happens with purchases, bundles, could be tracks?
//       // Get the metadata document for the specified collection
//       DocumentSnapshot metadataDoc =
//           await firestore.collection('metadata').doc(collectionName).get();

//       if (metadataDoc.exists && metadataDoc.data() != null) {
//         // Cast the data to Map format and access 'last_updated'
//         Map<String, dynamic> data = metadataDoc.data() as Map<String, dynamic>;
//         Timestamp lastUpdatedTimestamp = data['last_updated'] as Timestamp;
//         // Convert the Timestamp to a DateTime object
//         return lastUpdatedTimestamp.toDate();
//       } else {
//         logger.e(
//             'Metadata document for the "$collectionName" collection does not exist or no data.');
//         return DateTime.fromMillisecondsSinceEpoch(0);
//       }
//     } catch (e) {
//       // Handle errors (e.g., network issues, permission problems)
//       logger.e('Error fetching last updated timestamp: $e');
//       // Return a fixed date in the past or handle this scenario appropriately in your application
//       return DateTime.fromMillisecondsSinceEpoch(0);
//     }
//   }
// }
