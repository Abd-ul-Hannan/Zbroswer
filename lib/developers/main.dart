import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:zbrowser/developers/javascript_console.dart';
import 'package:zbrowser/developers/network_info.dart';
import 'package:zbrowser/developers/storage_manager.dart';
import 'package:zbrowser/app_bar/custom_app_bar_wrapper.dart';

class DevelopersPage extends StatelessWidget {
  const DevelopersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Clean up all developer tool controllers when leaving the page
          // This prevents memory leaks. Guard deletions in case controllers
          // were not registered to avoid GetX throws.
          if (Get.isRegistered<JavaScriptConsoleController>()) {
            Get.delete<JavaScriptConsoleController>(force: true);
          }
          if (Get.isRegistered<StorageManagerController>()) {
            Get.delete<StorageManagerController>(force: true);
          }
          // Add more if you create controllers for NetworkInfo in the future
        }
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: CustomAppBarWrapper(
            appBar: AppBar(
              bottom: TabBar(
                // Safer way to unfocus using GetX
                onTap: (_) => FocusScope.of(context).unfocus(),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.code),
                    text: "JavaScript Console",
                  ),
                  Tab(
                    icon: Icon(Icons.network_check),
                    text: "Network Info",
                  ),
                  Tab(
                    icon: Icon(Icons.storage),
                    text: "Storage Manager",
                  ),
                ],
              ),
              title: const Text('Developers'),
            ),
          ),
          body: const TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: [
              JavaScriptConsole(),
              NetworkInfo(),
              StorageManager(),
            ],
          ),
        ),
      ),
    );
  }
}