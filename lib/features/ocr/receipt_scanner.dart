import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Wraps ML Kit on-device text recognition.
/// Processes an image file and returns the raw recognized text.
class ReceiptScanner {
  ReceiptScanner._();

  /// Scans [imageFile] and returns the full concatenated text.
  /// Throws if recognition fails.
  static Future<String> scanImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      await recognizer.close();
    }
  }

  /// Scans and returns individual text blocks with bounding-box metadata.
  /// Useful for more sophisticated layout parsing.
  static Future<RecognizedText> scanImageDetailed(File imageFile) async {
    final inputImage  = InputImage.fromFile(imageFile);
    final recognizer  = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      return await recognizer.processImage(inputImage);
    } finally {
      await recognizer.close();
    }
  }
}
