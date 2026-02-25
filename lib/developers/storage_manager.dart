import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import 'package:zbrowser/main.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/utils/util.dart';

import '../models/window_model.dart';

class StorageManager extends StatelessWidget {
  const StorageManager({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller with tag to prevent conflicts
    final controller = Get.put(
      StorageManagerController(),
      tag: 'storage_manager',
      permanent: false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final entryItems = <Widget>[
          controller.buildCookiesExpansionTile(constraints),
          controller.buildWebLocalStorageExpansionTile(constraints),
          controller.buildWebSessionStorageExpansionTile(constraints),
        ];

        if (!Util.isWindows()) {
          entryItems.add(controller.buildHttpAuthCredentialDatabaseExpansionTile(constraints));
        }

        if (Util.isAndroid()) {
          entryItems.add(controller.buildAndroidWebStorageExpansionTile(constraints));
        } else if (Util.isIOS() || Util.isMacOS()) {
          entryItems.add(controller.buildIOSWebStorageExpansionTile(constraints));
        }

        return ListView.builder(
          itemCount: entryItems.length,
          itemBuilder: (context, index) => entryItems[index],
        );
      },
    );
  }
}

class StorageManagerController extends GetxController {
  final CookieManager cookieManager = CookieManager.instance(webViewEnvironment: webViewEnvironment);
  final WebStorageManager? webStorageManager = !Util.isWindows() ? WebStorageManager.instance() : null;
  final HttpAuthCredentialDatabase? httpAuthCredentialDatabase = !Util.isWindows() ? HttpAuthCredentialDatabase.instance() : null;

  // Refresh trigger for FutureBuilders
  final refreshTrigger = 0.obs;

  // Controllers
  late final TextEditingController newCookieNameController;
  late final TextEditingController newCookieValueController;
  late final TextEditingController newCookiePathController;
  late final TextEditingController newCookieDomainController;
  late final TextEditingController newLocalStorageKeyController;
  late final TextEditingController newLocalStorageValueController;
  late final TextEditingController newSessionStorageKeyController;
  late final TextEditingController newSessionStorageValueController;

  // Reactive states
  final newCookieIsSecure = false.obs;
  final newCookieExpiresDate = Rx<DateTime?>(null);

  // Edit tracking
  final cookieNameEdit = <bool>[].obs;
  final cookieValueEdit = <bool>[].obs;
  final localStorageKeyEdit = <bool>[].obs;
  final localStorageValueEdit = <bool>[].obs;
  final sessionStorageKeyEdit = <bool>[].obs;
  final sessionStorageValueEdit = <bool>[].obs;

  // Form keys
  late final GlobalKey<FormState> newCookieFormKey;
  late final GlobalKey<FormState> newLocalStorageItemFormKey;
  late final GlobalKey<FormState> newSessionStorageItemFormKey;

  @override
  void onInit() {
    super.onInit();
    
    // Initialize TextEditingControllers
    newCookieNameController = TextEditingController();
    newCookieValueController = TextEditingController();
    newCookiePathController = TextEditingController(text: "/");
    newCookieDomainController = TextEditingController();
    newLocalStorageKeyController = TextEditingController();
    newLocalStorageValueController = TextEditingController();
    newSessionStorageKeyController = TextEditingController();
    newSessionStorageValueController = TextEditingController();
    
    // Initialize Form Keys
    newCookieFormKey = GlobalKey<FormState>();
    newLocalStorageItemFormKey = GlobalKey<FormState>();
    newSessionStorageItemFormKey = GlobalKey<FormState>();
  }

  @override
  void onClose() {
    // Dispose all controllers
    newCookieNameController.dispose();
    newCookieValueController.dispose();
    newCookiePathController.dispose();
    newCookieDomainController.dispose();
    newLocalStorageKeyController.dispose();
    newLocalStorageValueController.dispose();
    newSessionStorageKeyController.dispose();
    newSessionStorageValueController.dispose();
    super.onClose();
  }

  WebViewModel? get currentWebViewModel {
    try {
      if (Get.isRegistered<WindowModel>()) {
        final windowModel = Get.find<WindowModel>();
        final tab = windowModel.getCurrentTab();
        return tab?.webViewModel;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  InAppWebViewController? get webViewController => currentWebViewModel?.webViewController;

  void refresh() {
    refreshTrigger.value++;
  }

  Widget buildCookiesExpansionTile(BoxConstraints constraints) {
    return Obx(() {
      // Trigger rebuild when refreshTrigger changes
      final _ = refreshTrigger.value;
      
      final webViewModel = currentWebViewModel;
      if (webViewModel?.url == null) {
        return const ExpansionTile(
          title: Text("Cookies", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          children: [Center(child: Text("No active tab"))],
        );
      }

      return FutureBuilder<List<Cookie>>(
        future: cookieManager.getCookies(url: webViewModel!.url!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ExpansionTile(
              title: Text("Cookies", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: CircularProgressIndicator())],
            );
          }
          if (snapshot.hasError) {
            return ExpansionTile(
              title: const Text("Cookies", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: Text("Error: ${snapshot.error}"))],
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const ExpansionTile(
              title: Text("Cookies", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: Text("No cookies found"))],
            );
          }

          final cookies = snapshot.data!;
          final rows = cookies.mapIndexed((index, cookie) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: constraints.maxWidth / 3,
                    child: Text(cookie.name, softWrap: true, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: constraints.maxWidth / 3,
                    child: Text(cookie.value, softWrap: true, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () async {
                      await cookieManager.deleteCookie(url: webViewModel.url!, name: cookie.name);
                      refresh();
                    },
                  ),
                ),
              ],
            );
          }).toList();

          return ExpansionTile(
            title: const Text("Cookies", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
            children: [
              SizedBox(
                width: constraints.minWidth,
                child: DataTable(
                  columnSpacing: 0.0,
                  columns: const [
                    DataColumn(label: Text("Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                    DataColumn(label: Text("Value", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                    DataColumn(label: Text("Delete", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                  ],
                  rows: rows,
                ),
              ),
              _buildAddCookieForm(webViewModel),
              _buildCookieActions(webViewModel),
            ],
          );
        },
      );
    });
  }

  Widget buildWebLocalStorageExpansionTile(BoxConstraints constraints) {
    return Obx(() {
      final _ = refreshTrigger.value;
      
      final webViewModel = currentWebViewModel;
      if (webViewModel?.webViewController == null) {
        return const ExpansionTile(
          title: Text("Local Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          children: [Center(child: Text("No active tab"))],
        );
      }

      return FutureBuilder<List<WebStorageItem>>(
        future: webViewModel!.webViewController!.webStorage.localStorage.getItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ExpansionTile(
              title: Text("Local Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: CircularProgressIndicator())],
            );
          }
          if (snapshot.hasError) {
            return ExpansionTile(
              title: const Text("Local Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: Text("Error: ${snapshot.error}"))],
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const ExpansionTile(
              title: Text("Local Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: Text("No items found"))],
            );
          }

          final items = snapshot.data!;
          final rows = items.map((item) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: constraints.maxWidth / 3,
                    child: Text(item.key ?? "", softWrap: true, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: constraints.maxWidth / 3,
                    child: Text(item.value, softWrap: true, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () async {
                      await webViewModel.webViewController!.webStorage.localStorage.removeItem(key: item.key!);
                      refresh();
                    },
                  ),
                ),
              ],
            );
          }).toList();

          return ExpansionTile(
            title: const Text("Local Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
            children: [
              SizedBox(
                width: constraints.minWidth,
                child: DataTable(
                  columnSpacing: 0.0,
                  columns: const [
                    DataColumn(label: Text("Key", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                    DataColumn(label: Text("Value", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                    DataColumn(label: Text("Delete", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                  ],
                  rows: rows,
                ),
              ),
              _buildAddNewWebStorageItem(
                formKey: newLocalStorageItemFormKey,
                keyController: newLocalStorageKeyController,
                valueController: newLocalStorageValueController,
                labelKey: "Local Item Key",
                labelValue: "Local Item Value",
                onAdd: (key, value) async {
                  await webViewModel.webViewController!.webStorage.localStorage.setItem(key: key, value: value);
                  refresh();
                },
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await webViewModel.webViewController!.webStorage.localStorage.clear();
                    refresh();
                  },
                  child: const Text("Clear items"),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  Widget buildWebSessionStorageExpansionTile(BoxConstraints constraints) {
    return Obx(() {
      final _ = refreshTrigger.value;
      
      final webViewModel = currentWebViewModel;
      if (webViewModel?.webViewController == null) {
        return const ExpansionTile(
          title: Text("Session Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          children: [Center(child: Text("No active tab"))],
        );
      }

      return FutureBuilder<List<WebStorageItem>>(
        future: webViewModel!.webViewController!.webStorage.sessionStorage.getItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ExpansionTile(
              title: Text("Session Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: CircularProgressIndicator())],
            );
          }
          if (snapshot.hasError) {
            return ExpansionTile(
              title: const Text("Session Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: Text("Error: ${snapshot.error}"))],
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const ExpansionTile(
              title: Text("Session Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              children: [Center(child: Text("No items found"))],
            );
          }

          final items = snapshot.data!;
          final rows = items.map((item) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: constraints.maxWidth / 3,
                    child: Text(item.key ?? "", softWrap: true, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: constraints.maxWidth / 3,
                    child: Text(item.value, softWrap: true, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () async {
                      await webViewModel.webViewController!.webStorage.sessionStorage.removeItem(key: item.key!);
                      refresh();
                    },
                  ),
                ),
              ],
            );
          }).toList();

          return ExpansionTile(
            title: const Text("Session Storage", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
            children: [
              SizedBox(
                width: constraints.minWidth,
                child: DataTable(
                  columnSpacing: 0.0,
                  columns: const [
                    DataColumn(label: Text("Key", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                    DataColumn(label: Text("Value", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                    DataColumn(label: Text("Delete", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                  ],
                  rows: rows,
                ),
              ),
              _buildAddNewWebStorageItem(
                formKey: newSessionStorageItemFormKey,
                keyController: newSessionStorageKeyController,
                valueController: newSessionStorageValueController,
                labelKey: "Session Item Key",
                labelValue: "Session Item Value",
                onAdd: (key, value) async {
                  await webViewModel.webViewController!.webStorage.sessionStorage.setItem(key: key, value: value);
                  refresh();
                },
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await webViewModel.webViewController!.webStorage.sessionStorage.clear();
                    refresh();
                  },
                  child: const Text("Clear items"),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  Widget buildAndroidWebStorageExpansionTile(BoxConstraints constraints) {
    final url = currentWebViewModel?.url;

    if (url == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        ListTile(
          title: const Text("Quota"),
          subtitle: FutureBuilder<int?>(
            future: webStorageManager?.getQuotaForOrigin(origin: url.origin),
            builder: (context, snapshot) => Text(snapshot.data?.toString() ?? ""),
          ),
        ),
        ListTile(
          title: const Text("Usage"),
          subtitle: FutureBuilder<int?>(
            future: webStorageManager?.getUsageForOrigin(origin: url.origin),
            builder: (context, snapshot) => Text(snapshot.data?.toString() ?? ""),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () async {
              await webStorageManager?.deleteOrigin(origin: url.origin);
              refresh();
            },
          ),
        ),
      ],
    );
  }

  Widget buildIOSWebStorageExpansionTile(BoxConstraints constraints) {
    return FutureBuilder<List<WebsiteDataRecord>>(
      future: webStorageManager?.fetchDataRecords(dataTypes: WebsiteDataType.ALL),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];

        final rows = records.map((record) {
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: constraints.maxWidth / 3,
                  child: Text(record.displayName ?? "", softWrap: true, style: const TextStyle(fontSize: 12.0)),
                ),
                onTap: () => Clipboard.setData(ClipboardData(text: record.displayName ?? '')),
              ),
              DataCell(
                SizedBox(
                  width: constraints.maxWidth / 3,
                  child: Text(record.dataTypes?.join(", ") ?? "", softWrap: true, style: const TextStyle(fontSize: 12.0)),
                ),
                onTap: () {
                  Get.dialog(
                    AlertDialog(
                      content: Text(record.dataTypes?.join(",\n") ?? ""),
                    ),
                  );
                },
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () async {
                    if (record.dataTypes != null) {
                      await webStorageManager?.removeDataFor(
                        dataTypes: record.dataTypes!,
                        dataRecords: [record],
                      );
                      refresh();
                    }
                  },
                ),
              ),
            ],
          );
        }).toList();

        return ExpansionTile(
          onExpansionChanged: (_) => Get.focusScope?.unfocus(),
          title: const Text("Web Storage iOS", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          children: [
            SizedBox(
              width: constraints.minWidth,
              child: DataTable(
                columnSpacing: 0.0,
                columns: const [
                  DataColumn(label: Text("Display Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                  DataColumn(label: Text("Data Types", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                  DataColumn(label: Text("Delete", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                ],
                rows: rows,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await webStorageManager?.removeDataModifiedSince(
                    dataTypes: WebsiteDataType.ALL,
                    date: DateTime.fromMillisecondsSinceEpoch(0),
                  );
                  refresh();
                },
                child: const Text("Clear all"),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildHttpAuthCredentialDatabaseExpansionTile(BoxConstraints constraints) {
    return FutureBuilder<List<URLProtectionSpaceHttpAuthCredentials>>(
      future: httpAuthCredentialDatabase?.getAllAuthCredentials(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final credentials = snapshot.data!;

        final tables = credentials.map((item) {
          final space = item.protectionSpace;
          final rows = item.credentials?.map((cred) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(width: constraints.maxWidth / 3, child: Text(cred.username ?? "", softWrap: true)),
                  onTap: () => Clipboard.setData(ClipboardData(text: cred.username ?? '')),
                ),
                DataCell(
                  SizedBox(width: constraints.maxWidth / 3, child: Text(cred.password ?? "", softWrap: true)),
                  onTap: () => Clipboard.setData(ClipboardData(text: cred.password ?? '')),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () async {
                      if (space != null) {
                        await httpAuthCredentialDatabase?.removeHttpAuthCredential(
                          protectionSpace: space,
                          credential: cred,
                        );
                        refresh();
                      }
                    },
                  ),
                ),
              ],
            );
          }).toList() ?? [];

          return Column(
            children: [
              const Text("Protection Space", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0)),
              const SizedBox(height: 10.0),
              Text("Protocol: ${space?.protocol ?? ""}, Host: ${space?.host ?? ""}, Port: ${space?.port ?? ""}, Realm: ${space?.realm ?? ""}"),
              SizedBox(
                width: constraints.minWidth,
                child: DataTable(
                  columnSpacing: 0.0,
                  columns: const [
                    DataColumn(label: Text("Username", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                    DataColumn(label: Text("Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                    DataColumn(label: Text("Delete", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0))),
                  ],
                  rows: rows,
                ),
              ),
            ],
          );
        }).toList();

        return ExpansionTile(
          onExpansionChanged: (_) => Get.focusScope?.unfocus(),
          title: const Text("Http Auth Credentials Database", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          children: [
            ...tables,
            TextButton(
              onPressed: () async {
                await httpAuthCredentialDatabase?.clearAllAuthCredentials();
                refresh();
              },
              child: const Text("Clear all"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddCookieForm(WebViewModel webViewModel) {
    return Form(
      key: newCookieFormKey,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: newCookieNameController,
                    decoration: const InputDecoration(labelText: "Cookie Name"),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: newCookieValueController,
                    decoration: const InputDecoration(labelText: "Cookie Value"),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: newCookieDomainController,
                    decoration: const InputDecoration(labelText: "Cookie Domain"),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: newCookiePathController,
                    decoration: const InputDecoration(labelText: "Cookie Path"),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  if (newCookieFormKey.currentState!.validate()) {
                    await cookieManager.setCookie(
                      url: webViewModel.url!,
                      name: newCookieNameController.text,
                      value: newCookieValueController.text,
                      domain: newCookieDomainController.text.isEmpty ? null : newCookieDomainController.text,
                      path: newCookiePathController.text,
                    );
                    newCookieFormKey.currentState!.reset();
                    refresh();
                  }
                },
                child: const Text("Add Cookie"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCookieActions(WebViewModel webViewModel) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () async {
              await cookieManager.deleteCookies(url: webViewModel.url!);
              refresh();
            },
            child: const Text("Clear cookies"),
          ),
        ),
        Expanded(
          child: TextButton(
            onPressed: () async {
              await cookieManager.deleteAllCookies();
              refresh();
            },
            child: const Text("Clear all"),
          ),
        ),
      ],
    );
  }

  Widget _buildAddNewWebStorageItem({
    required GlobalKey<FormState> formKey,
    required TextEditingController keyController,
    required TextEditingController valueController,
    required String labelKey,
    required String labelValue,
    required Future<void> Function(String key, String value) onAdd,
  }) {
    return Form(
      key: formKey,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: TextFormField(
                controller: keyController,
                decoration: InputDecoration(labelText: labelKey),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: TextFormField(
                controller: valueController,
                decoration: InputDecoration(labelText: labelValue),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await onAdd(keyController.text, valueController.text);
                formKey.currentState!.reset();
              }
            },
            child: const Text("Add Item"),
          ),
        ],
      ),
    );
  }
}