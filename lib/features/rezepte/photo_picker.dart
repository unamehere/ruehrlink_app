import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Größte Fotodatei, die die Brücke annimmt (`PUT /api/v1/media`).
const maxPhotoBytes = 1024 * 1024;

/// Foto ist auch verkleinert noch zu groß.
class PhotoTooBigException implements Exception {
  const PhotoTooBigException();
}

/// Foto aus Kamera oder Galerie holen und als WebP verkleinern (kurze Seite höchstens ca. 1600 px).
/// `null`, wenn abgebrochen. Fehler beim Umwandeln → Exception.
Future<Uint8List?> pickRecipePhoto({required bool camera}) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  // Erst normal, dann kleiner und stärker komprimiert, falls es noch nicht passt.
  for (final (size, quality) in const [(1600, 80), (1200, 65), (900, 50)]) {
    final webp = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: size,
      minHeight: size,
      quality: quality,
      format: CompressFormat.webp,
    );
    if (webp == null) throw Exception('compress');
    if (webp.length <= maxPhotoBytes) return webp;
  }
  throw const PhotoTooBigException();
}
