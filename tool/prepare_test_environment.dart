// `dart run` executes the locked native build hooks and emits the host JIT
// asset mapping. Flutter's test runner does not emit that mapping itself.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

void main() {
  final manifest = File('.dart_tool/native_assets.yaml');
  final json = jsonDecode(
    manifest
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('#'))
        .join('\n'),
  ) as Map<String, dynamic>;
  final target = Abi.current().toString();
  final asset =
      json['native-assets']?[target]?['package:pdfium_dart/libpdfium'];
  if (asset is! List || asset.length != 2 || asset.first != 'absolute') {
    throw StateError('PDFium host native asset was not built for $target');
  }
  DynamicLibrary.open(asset[1] as String);
  stdout.writeln('Host PDFium prepared and loadable for $target.');
}
