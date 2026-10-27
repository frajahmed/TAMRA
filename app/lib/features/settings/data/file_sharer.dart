import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file to the phone's share menu (save to Files, send by mail, …).
abstract interface class FileSharer {
  /// Shares [content] as a JSON file called [fileName].
  Future<void> shareJson(String fileName, String content);
}

/// Share menu of iOS / Android through `share_plus`.
class SystemFileSharer implements FileSharer {
  /// Creates the sharer.
  const SystemFileSharer();

  @override
  Future<void> shareJson(String fileName, String content) async {
    final file = XFile.fromData(utf8.encode(content), mimeType: 'application/json', name: fileName);
    await SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: [fileName]));
  }
}

/// The share menu; widget tests replace it with a fake.
final fileSharerProvider = Provider<FileSharer>((ref) => const SystemFileSharer());
