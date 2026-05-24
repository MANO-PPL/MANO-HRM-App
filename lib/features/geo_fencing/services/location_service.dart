import 'package:dio/dio.dart';
import '../../../../shared/constants/api_constants.dart';
import '../models/location_model.dart';

class LocationService {
  final Dio _dio;

  LocationService(this._dio);

  // 1. Get All Work Locations
  Future<List<WorkLocation>> getLocations() async {
    try {
      final response = await _dio.get(ApiConstants.locations);
      if (response.statusCode == 200 && response.data['ok']) {
        final List<dynamic> list = response.data['locations'];
        return list.map((j) => WorkLocation.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load locations: $e');
    }
  }

  // 2. Create Location
  Future<void> createLocation(Map<String, dynamic> data) async {
    try {
      await _dio.post(ApiConstants.locations, data: data);
    } catch (e) {
      throw Exception('Failed to create location: $e');
    }
  }

  // 3. Update Location
  Future<void> updateLocation(int id, Map<String, dynamic> updates) async {
    try {
      await _dio.put('${ApiConstants.locations}/$id', data: updates);
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }
  
  // 3.1 Delete Location
  Future<void> deleteLocation(int id) async {
    try {
      final response = await _dio.delete('${ApiConstants.locations}/$id');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && (data['ok'] == false || data['success'] == false)) {
           throw Exception(data['msg'] ?? data['message'] ?? 'Server could not delete location');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete location: $e');
    }
  }

  // 4. Assign User to Location
  Future<void> assignUser(int locationId, int userId, bool isAdding) async {
    try {
      final payload = {
        "assignments": [
          {
            "work_location_id": locationId,
            "add": isAdding ? [userId] : [],
            "remove": isAdding ? [] : [userId]
          }
        ]
      };
      await _dio.post(ApiConstants.locationAssignments, data: payload);
    } catch (e) {
        throw Exception('Failed to update assignment: $e');
    }
  }

  // 5. Get Users with Work Locations
  Future<List<Map<String, dynamic>>> getUsersWithLocations() async {
    try {
      final response = await _dio.get(ApiConstants.users, queryParameters: {'workLocation': 'true'});
      if (response.statusCode == 200 && (response.data['success'] == true || response.data['ok'] == true)) {
         final List<dynamic> list = response.data['users'];
         final usersList = List<Map<String, dynamic>>.from(list);
         usersList.sort((a, b) {
           final aName = (a['user_name'] as String? ?? '').toLowerCase();
           final bName = (b['user_name'] as String? ?? '').toLowerCase();
           return aName.compareTo(bName);
         });
         return usersList;
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  // 6. Reverse Geocode (OpenStreetMap Nominatim)
  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final dio = Dio(); 
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse', 
        queryParameters: {
          'format': 'json',
          'lat': lat,
          'lon': lng
        }
      );
      
      if (response.statusCode == 200) {
        return response.data['display_name'] ?? '';
      }
      return '';
    } catch (e) {
      print("Geocoding failed: $e");
      return '';
    }
  }
}
