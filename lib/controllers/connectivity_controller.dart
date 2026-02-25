import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityController extends GetxController {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  final RxBool isConnected = true.obs;
  final RxBool isChecking = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      isConnected.value = false;
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    isConnected.value = !results.contains(ConnectivityResult.none) && results.isNotEmpty;
  }

  Future<void> checkConnectivity() async {
    isChecking.value = true;
    await _initConnectivity();
    await Future.delayed(const Duration(milliseconds: 500));
    isChecking.value = false;
  }
}