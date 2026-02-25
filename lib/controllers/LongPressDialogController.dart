import 'package:get/get.dart';

class LongPressDialogController extends GetxController {
  final _isLinkPreviewReady = false.obs;
  bool get isLinkPreviewReady => _isLinkPreviewReady.value;

  void setLinkPreviewReady(bool value) {
    _isLinkPreviewReady.value = value;
  }
}
