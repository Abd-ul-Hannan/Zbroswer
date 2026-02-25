import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_saver/file_saver.dart';

import 'package:zbrowser/models/webview_model.dart';

class CertificateInfoPopup extends StatelessWidget {
  const CertificateInfoPopup({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Simplified controller registration
    final controller = Get.put(CertificateInfoController(), tag: 'cert_info');

    return Obx(() {
      if (controller.isLoading.value) {
        return Center(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(2.5)),
            ),
            padding: const EdgeInsets.all(25.0),
            width: 100.0,
            height: 100.0,
            child: const CircularProgressIndicator(strokeWidth: 4.0),
          ),
        );
      }

      if (controller.topMainCertificate.value == null) {
        return const SizedBox.shrink();
      }

      return controller.buildCertificatesInfoAlertDialog(context);
    });
  }
}

class CertificateInfoController extends GetxController {
  // ✅ FIXED: Late initialization for WebViewModel
  late final WebViewModel webViewModel;

  final otherCertificates = <X509Certificate>[].obs;
  final topMainCertificate = Rx<X509Certificate?>(null);
  final selectedCertificate = Rx<X509Certificate?>(null);
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    // ✅ FIXED: Proper WebViewModel initialization
    try {
      webViewModel = Get.find<WebViewModel>();
    } catch (e) {
      log("WebViewModel not found, creating new instance");
      webViewModel = Get.put(WebViewModel());
    }
    _loadCertificateData();
  }

  // ✅ FIXED: Proper cleanup
  @override
  void onClose() {
    otherCertificates.clear();
    topMainCertificate.value = null;
    selectedCertificate.value = null;
    super.onClose();
  }

  Future<void> _loadCertificateData() async {
    isLoading.value = true;
    try {
      final sslCert = await webViewModel.webViewController?.getCertificate();
      if (sslCert?.x509Certificate != null) {
        topMainCertificate.value = sslCert!.x509Certificate;
        selectedCertificate.value = topMainCertificate.value;

        await _getOtherCertificatesFromTopMain(
          otherCertificates, 
          topMainCertificate.value!
        );
      }
    } catch (e) {
      log("Certificate load error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _getOtherCertificatesFromTopMain(
    List<X509Certificate> list, 
    X509Certificate cert
  ) async {
    var authorityInfoAccess = cert.authorityInfoAccess;
    if (authorityInfoAccess != null && authorityInfoAccess.infoAccess != null) {
      for (var access in authorityInfoAccess.infoAccess!) {
        await _downloadAndAddCert(access.location, list);
      }
    }

    var cRLDistributionPoints = cert.cRLDistributionPoints;
    if (cRLDistributionPoints != null && cRLDistributionPoints.crls != null) {
      for (var url in cRLDistributionPoints.crls!) {
        await _downloadAndAddCert(url, list);
      }
    }
  }

  Future<void> _downloadAndAddCert(String url, List<X509Certificate> list) async {
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      final data = Uint8List.fromList(await response.first);
      final newCert = X509Certificate.fromData(data: data);
      list.add(newCert);
      await _getOtherCertificatesFromTopMain(list, newCert);
    } catch (e) {
      log("Download failed: $url - $e");
    }
  }

  Widget buildCertificatesInfoAlertDialog(BuildContext context) {
    var url = webViewModel.url;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.all(Radius.circular(5.0)),
                ),
                padding: const EdgeInsets.all(5.0),
                child: const Icon(Icons.lock, color: Colors.white, size: 20.0),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        url?.host ?? "",
                        style: const TextStyle(
                          fontSize: 16.0, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 15.0),
                      Text(
                        "Flutter Browser has verified that ${topMainCertificate.value?.issuer(dn: ASN1DistinguishedNames.COMMON_NAME)} has emitted the web site certificate.",
                        softWrap: true,
                        style: const TextStyle(fontSize: 12.0),
                      ),
                      const SizedBox(height: 15.0),
                      RichText(
                        text: TextSpan(
                          text: "Certificate info",
                          style: const TextStyle(
                            color: Colors.blue, 
                            fontSize: 12.0
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _showCertificateViewer(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCertificateViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        // ✅ FIXED: GetBuilder instead of multiple Obx for better performance
        return GetBuilder<CertificateInfoController>(
          tag: 'cert_info',
          builder: (ctrl) {
            final allCerts = [
              ctrl.topMainCertificate.value!, 
              ...ctrl.otherCertificates
            ];
            
            return AlertDialog(
              content: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width / 2
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Certificate Viewer",
                      style: TextStyle(
                        fontSize: 24.0, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 15.0),
                    // ✅ FIXED: Single Obx for dropdown
                    Obx(() {
                      final dropdownItems = <DropdownMenuItem<X509Certificate>>[];
                      
                      for (var cert in allCerts) {
                        final name = _findCommonName(
                          x509certificate: cert, 
                          isSubject: true
                        ) ?? _findOrganizationName(
                          x509certificate: cert, 
                          isSubject: true
                        ) ?? "Unknown Certificate";
                        
                        dropdownItems.add(
                          DropdownMenuItem(
                            value: cert, 
                            child: Text(name)
                          )
                        );
                      }

                      if (ctrl.selectedCertificate.value == null && 
                          allCerts.isNotEmpty) {
                        ctrl.selectedCertificate.value = allCerts.first;
                      }

                      return DropdownButton<X509Certificate>(
                        isExpanded: true,
                        value: ctrl.selectedCertificate.value,
                        onChanged: (v) {
                          ctrl.selectedCertificate.value = v;
                          ctrl.update(); // ✅ Trigger GetBuilder update
                        },
                        items: dropdownItems,
                      );
                    }),
                    const SizedBox(height: 15.0),
                    // ✅ FIXED: Direct value check instead of nested Obx
                    if (ctrl.selectedCertificate.value != null)
                      Flexible(
                        child: SingleChildScrollView(
                          child: _buildCertificateInfo(
                            ctrl.selectedCertificate.value!
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCertificateInfo(X509Certificate cert) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._buildIssuedToSection(cert),
        ..._buildIssuedBySection(cert),
        ..._buildValidityPeriodSection(cert),
        ..._buildPublicKeySection(cert),
        ..._buildFingerprintSection(cert),
        ..._buildExtensionSection(cert),
      ],
    );
  }

  // ✅ Rest of the methods remain the same
  String? _findCountryName({
    required X509Certificate x509certificate, 
    required bool isSubject
  }) {
    try {
      return (isSubject
        ? x509certificate.subject(dn: ASN1DistinguishedNames.COUNTRY_NAME)
        : x509certificate.issuer(dn: ASN1DistinguishedNames.COUNTRY_NAME)) ??
        x509certificate.block1?.findOid(oid: OID.countryName)?.parent?.sub?.last.value;
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  String? _findStateOrProvinceName({
    required X509Certificate x509certificate, 
    required bool isSubject
  }) {
    try {
      return (isSubject
        ? x509certificate.subject(dn: ASN1DistinguishedNames.STATE_OR_PROVINCE_NAME)
        : x509certificate.issuer(dn: ASN1DistinguishedNames.STATE_OR_PROVINCE_NAME)) ??
        x509certificate.block1?.findOid(oid: OID.stateOrProvinceName)?.parent?.sub?.last.value;
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  String? _findCommonName({
    required X509Certificate x509certificate, 
    required bool isSubject
  }) {
    try {
      return (isSubject
        ? x509certificate.subject(dn: ASN1DistinguishedNames.COMMON_NAME)
        : x509certificate.issuer(dn: ASN1DistinguishedNames.COMMON_NAME)) ??
        x509certificate.block1?.findOid(oid: OID.commonName)?.parent?.sub?.last.value;
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  String? _findOrganizationName({
    required X509Certificate x509certificate, 
    required bool isSubject
  }) {
    try {
      return (isSubject
        ? x509certificate.subject(dn: ASN1DistinguishedNames.ORGANIZATION_NAME)
        : x509certificate.issuer(dn: ASN1DistinguishedNames.ORGANIZATION_NAME)) ??
        x509certificate.block1?.findOid(oid: OID.organizationName)?.parent?.sub?.last.value;
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  String? _findOrganizationUnitName({
    required X509Certificate x509certificate, 
    required bool isSubject
  }) {
    try {
      return (isSubject
        ? x509certificate.subject(dn: ASN1DistinguishedNames.ORGANIZATIONAL_UNIT_NAME)
        : x509certificate.issuer(dn: ASN1DistinguishedNames.ORGANIZATIONAL_UNIT_NAME)) ??
        x509certificate.block1?.findOid(oid: OID.organizationalUnitName)?.parent?.sub?.last.value;
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  List<Widget> _buildIssuedToSection(X509Certificate x509certificate) {
    var subjectCountryName = _findCountryName(
      x509certificate: x509certificate, 
      isSubject: true
    ) ?? "<Not Part Of Certificate>";
    
    var subjectStateOrProvinceName = _findStateOrProvinceName(
      x509certificate: x509certificate, 
      isSubject: true
    ) ?? "<Not Part Of Certificate>";
    
    var subjectCN = _findCommonName(
      x509certificate: x509certificate, 
      isSubject: true
    ) ?? "<Not Part Of Certificate>";
    
    var subjectO = _findOrganizationName(
      x509certificate: x509certificate, 
      isSubject: true
    ) ?? "<Not Part Of Certificate>";
    
    var subjectU = _findOrganizationUnitName(
      x509certificate: x509certificate, 
      isSubject: true
    ) ?? "<Not Part Of Certificate>";

    return [
      const Text(
        "ISSUED TO", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      const SizedBox(height: 5.0),
      const Text(
        "Common Name (CN)", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(subjectCN, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Organization (O)", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(subjectO, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Organizational Unit (U)", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(subjectU, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Country", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(subjectCountryName, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "State/Province", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(subjectStateOrProvinceName, style: const TextStyle(fontSize: 14.0)),
    ];
  }

  List<Widget> _buildIssuedBySection(X509Certificate x509certificate) {
    var issuerCountryName = _findCountryName(
      x509certificate: x509certificate, 
      isSubject: false
    ) ?? "<Not Part Of Certificate>";
    
    var issuerStateOrProvinceName = _findStateOrProvinceName(
      x509certificate: x509certificate, 
      isSubject: false
    ) ?? "<Not Part Of Certificate>";
    
    var issuerCN = _findCommonName(
      x509certificate: x509certificate, 
      isSubject: false
    ) ?? "<Not Part Of Certificate>";
    
    var issuerO = _findOrganizationName(
      x509certificate: x509certificate, 
      isSubject: false
    ) ?? "<Not Part Of Certificate>";
    
    var issuerU = _findOrganizationUnitName(
      x509certificate: x509certificate, 
      isSubject: false
    ) ?? "<Not Part Of Certificate>";
    
    var serialNumber = x509certificate.serialNumber
      ?.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(":") ?? "<Not Part Of Certificate>";
    
    var version = x509certificate.version?.toString() ?? 
      "<Not Part Of Certificate>";
    
    var sigAlgName = x509certificate.sigAlgName ?? 
      "<Not Part Of Certificate>";

    return [
      const SizedBox(height: 15.0),
      const Text(
        "ISSUED BY", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      const SizedBox(height: 5.0),
      const Text(
        "Common Name (CN)", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(issuerCN, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Organization (O)", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(issuerO, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Organizational Unit (U)", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(issuerU, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Country", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(issuerCountryName, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "State/Province", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(issuerStateOrProvinceName, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Serial Number", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(serialNumber, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Version", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(version, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Signature Algorithm", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(sigAlgName, style: const TextStyle(fontSize: 14.0)),
    ];
  }

  List<Widget> _buildValidityPeriodSection(X509Certificate x509certificate) {
    var issuedOnDate = x509certificate.notBefore != null 
      ? DateFormat("dd MMM yyyy HH:mm:ss").format(x509certificate.notBefore!) 
      : "<Not Part Of Certificate>";
    
    var expiresOnDate = x509certificate.notAfter != null 
      ? DateFormat("dd MMM yyyy HH:mm:ss").format(x509certificate.notAfter!) 
      : "<Not Part Of Certificate>";

    return [
      const SizedBox(height: 15.0),
      const Text(
        "VALIDITY PERIOD", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      const SizedBox(height: 5.0),
      const Text(
        "Issued on date", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(issuedOnDate, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Expires on date", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(expiresOnDate, style: const TextStyle(fontSize: 14.0)),
    ];
  }

  List<Widget> _buildPublicKeySection(X509Certificate x509certificate) {
    var publicKey = x509certificate.publicKey;
    var publicKeyAlg = "<Not Part Of Certificate>";
    var publicKeyAlgParams = "<Not Part Of Certificate>";
    
    if (publicKey != null) {
      if (publicKey.algOid != null) {
        publicKeyAlg = "${OID.fromValue(publicKey.algOid)!.name()} ( ${publicKey.algOid} )";
      }
      if (publicKey.algParams != null) {
        publicKeyAlgParams = "${OID.fromValue(publicKey.algParams)!.name()} ( ${publicKey.algParams} )";
      }
    }

    return [
      const SizedBox(height: 15.0),
      const Text(
        "PUBLIC KEY", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      const SizedBox(height: 5.0),
      const Text(
        "Algorithm", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(publicKeyAlg, style: const TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "Parameters", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      Text(publicKeyAlgParams, style: const TextStyle(fontSize: 14.0)),
    ];
  }

  List<Widget> _buildFingerprintSection(X509Certificate x509certificate) {
    return [
      const SizedBox(height: 15.0),
      const Text(
        "FINGERPRINTS", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      const SizedBox(height: 5.0),
      const Text(
        "SHA-256", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      const Text("<Not Available>", style: TextStyle(fontSize: 14.0)),
      const SizedBox(height: 5.0),
      const Text(
        "SHA-1", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      const Text("<Not Available>", style: TextStyle(fontSize: 14.0)),
    ];
  }

  List<Widget> _buildExtensionSection(X509Certificate x509certificate) {
    List<Widget> widgets = [
      const SizedBox(height: 15.0),
      const Text(
        "EXTENSIONS", 
        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
      ),
      const SizedBox(height: 5.0),
    ];

    try {
      // Subject Alternative Names
      var subjectAltNamesExt = x509certificate.subjectAlternativeNames;
      if (subjectAltNamesExt != null && subjectAltNamesExt.isNotEmpty) {
        widgets.addAll([
          const Text(
            "Subject Alternative Names", 
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
          ),
          Text(subjectAltNamesExt.join(", "), style: const TextStyle(fontSize: 14.0)),
          const SizedBox(height: 5.0),
        ]);
      }

      // Key Usage
      var keyUsageExt = x509certificate.keyUsage;
      if (keyUsageExt != null && keyUsageExt.isNotEmpty) {
        widgets.addAll([
          const Text(
            "Key Usage", 
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
          ),
          Text(keyUsageExt.join(", "), style: const TextStyle(fontSize: 14.0)),
          const SizedBox(height: 5.0),
        ]);
      }

      // Extended Key Usage
      var extKeyUsageExt = x509certificate.extendedKeyUsage;
      if (extKeyUsageExt != null && extKeyUsageExt.isNotEmpty) {
        widgets.addAll([
          const Text(
            "Extended Key Usage", 
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
          ),
          Text(extKeyUsageExt.join(", "), style: const TextStyle(fontSize: 14.0)),
          const SizedBox(height: 5.0),
        ]);
      }

      // Basic Constraints
      var basicConstraintsExt = x509certificate.basicConstraints;
      if (basicConstraintsExt != null) {
        widgets.addAll([
          const Text(
            "Basic Constraints", 
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)
          ),
          Text("CA: ${basicConstraintsExt.isCA}, Path Length: ${basicConstraintsExt.pathLenConstraint ?? 'None'}", 
               style: const TextStyle(fontSize: 14.0)),
          const SizedBox(height: 5.0),
        ]);
      }
    } catch (e) {
      log("Extension parsing error: $e");
      widgets.add(const Text("Extension information not available", 
                           style: TextStyle(fontSize: 14.0)));
    }

    return widgets;
  }
}