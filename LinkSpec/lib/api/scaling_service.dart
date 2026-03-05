import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

/// ScalingService: Client-side interface for the server-side auto-scaling policy.
/// 
/// This version avoids any DB/Supabase dependency and communicates directly 
/// with the API server to evaluate scaling needs.
class ScalingService {
  // Use the API URL from environment or configuration
  static const String serverUrl = 'https://api.linkspec.com/api/scaling-service';

  /// evaluateScaling: Sends traffic metrics to the server for threshold evaluation.
  /// The server handles all recursive logic and logging internally.
  static Future<Map<String, dynamic>> evaluateScaling({
    required int currentTraffic,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'currentTraffic': currentTraffic}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'SCALE_OUT') {
          developer.log(
            'Infrastructure scaling triggered: ${data['newCapacity']} units.',
            name: 'API.Scaling',
          );
        }
        
        return data;
      } else {
        developer.log(
          'Scaling Server Error: ${response.statusCode}',
          level: 1000,
          name: 'API.Scaling',
        );
        return {'status': 'ERROR', 'error': 'Server returned ${response.statusCode}'};
      }
    } catch (e) {
      developer.log(
        'Scaling Request Failed: $e',
        level: 1000,
        name: 'API.Scaling',
      );
      return {'status': 'FAILURE', 'error': e.toString()};
    }
  }
}
