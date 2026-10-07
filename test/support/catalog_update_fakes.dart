import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:indifit/data/catalog/catalog_update_service.dart';

/// A fake HTTP server for the food database update service (CAT-7).
///
/// [routes] maps a full URL to a handler; anything else is a 404. Every
/// request that reaches the adapter is recorded, so a test can prove that
/// nothing was sent at all.
class FakeCatalogServer implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions options)> routes = {};
  final List<RequestOptions> requests = [];

  List<String> get urls => [for (final r in requests) r.uri.toString()];

  void manifest(Map<String, Object?> json, {String? etag}) {
    routes[kTestManifestUrl] = (options) {
      if (etag != null && options.headers['If-None-Match'] == etag) {
        return ResponseBody.fromBytes(const [], 304);
      }
      return ResponseBody.fromString(
        jsonEncode(json),
        200,
        headers: {
          if (etag != null) 'etag': [etag],
          'content-type': ['application/json'],
        },
      );
    };
  }

  void file(String url, List<int> bytes) {
    routes[url] = (_) => ResponseBody.fromBytes(Uint8List.fromList(bytes), 200);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes[options.uri.toString()];
    if (handler == null) return ResponseBody.fromString('not found', 404);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

const kTestManifestUrl = 'https://catalog.test/catalog/v1/manifest.json';
const kTestPackBase = 'https://catalog.test/catalog/v1/';

class FakeCatalogNetwork implements CatalogNetworkProbe {
  CatalogNetwork value;
  FakeCatalogNetwork([this.value = CatalogNetwork.wifi]);

  @override
  Future<CatalogNetwork> current() async => value;
}

/// A gzip pack and the manifest entry that publishes it.
class TestPackFile {
  final List<int> bytes;
  final Map<String, Object?> entry;

  TestPackFile(this.bytes, this.entry);

  String get sha256 => entry['sha256']! as String;
  String get url => '$kTestPackBase${entry['url']}';
}

TestPackFile encodeTestPack(Map<String, Object?> pack, String fileName) {
  final bytes = gzip.encode(utf8.encode(jsonEncode(pack)));
  return TestPackFile(bytes, {
    'version': pack['version'],
    if (pack['base'] != null) 'base': pack['base'],
    'kind': pack['kind'],
    'url': 'packs/$fileName',
    'sha256': crypto.sha256.convert(bytes).toString(),
    'bytes': bytes.length,
  });
}

Map<String, Object?> testManifest(
  int latest,
  List<TestPackFile> packs, {
  int minAppBuild = 1,
}) => {
  'format': 1,
  'latest': latest,
  'min_app_build': minAppBuild,
  'packs': [for (final pack in packs) pack.entry],
};
