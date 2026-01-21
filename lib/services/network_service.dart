import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((event) {
      _isConnected = event != ConnectivityResult.none;
      return _isConnected;
    });
  }

  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;
    return _isConnected;
  }
}
