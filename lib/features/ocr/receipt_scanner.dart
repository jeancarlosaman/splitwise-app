import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'receipt_parser.dart';

class ReceiptScanner {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Opens camera (or gallery), runs OCR, returns parsed receipt.
  Future<ParsedReceipt?> scanFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null) return null;
    return _process(File(picked.path));
  }

  Future<ParsedReceipt?> scanFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return null;
    return _process(File(picked.path));
  }

  Future<ParsedReceipt> _process(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);
    return ReceiptParser.parse(recognized.text);
  }

  void dispose() => _recognizer.close();
}
