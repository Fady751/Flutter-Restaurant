import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class S3Service {
  static String get accessKey => dotenv.env['AWS_ACCESS_KEY_ID'] ?? '';
  static String get secretKey => dotenv.env['AWS_SECRET_ACCESS_KEY'] ?? '';
  static String get region => dotenv.env['AWS_REGION'] ?? '';
  static String get bucket => dotenv.env['AWS_S3_BUCKET'] ?? '';

  Future<bool> deleteImage(String fileName) async {
    if (accessKey.isEmpty || secretKey.isEmpty || region.isEmpty || bucket.isEmpty) {
      print('AWS credentials are missing for delete');
      return false;
    }

    final endpoint = 'https://$bucket.s3.$region.amazonaws.com';
    final url = Uri.parse('$endpoint/$fileName');

    final DateTime now = DateTime.now().toUtc();
    final String dateStamp =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final String amzDate =
        "${dateStamp}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z";

    final String method = 'DELETE';
    final String canonicalUri = '/$fileName';
    final String canonicalQueryString = '';

    final String canonicalHeaders =
        'host:$bucket.s3.$region.amazonaws.com\nx-amz-date:$amzDate\nx-amz-content-sha256:UNSIGNED-PAYLOAD\n';

    final String signedHeaders = 'host;x-amz-date;x-amz-content-sha256';
    final String payloadHash = 'UNSIGNED-PAYLOAD';

    final String canonicalRequest =
        '$method\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

    final String algorithm = 'AWS4-HMAC-SHA256';
    final String credentialScope = '$dateStamp/$region/s3/aws4_request';
    final String stringToSign =
        '$algorithm\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest))}';

    final List<int> kDate =
        Hmac(sha256, utf8.encode("AWS4$secretKey")).convert(utf8.encode(dateStamp)).bytes;
    final List<int> kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final List<int> kService = Hmac(sha256, kRegion).convert(utf8.encode("s3")).bytes;
    final List<int> kSigning =
        Hmac(sha256, kService).convert(utf8.encode("aws4_request")).bytes;

    final String signature =
        Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

    final String authorization =
        '$algorithm Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': authorization,
          'x-amz-date': amzDate,
          'x-amz-content-sha256': 'UNSIGNED-PAYLOAD',
        },
      );

      if (response.statusCode == 204) {
        print("✔ Image deleted from S3");
        return true;
      } else {
        print("❌ Failed to delete image: ${response.statusCode} → ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error deleting S3 image: $e");
      return false;
    }
  }

  Future<String?> uploadImage(Uint8List fileBytes, String fileName) async {
    if (accessKey.isEmpty || secretKey.isEmpty || region.isEmpty || bucket.isEmpty) {
      print('AWS credentials are missing');
      return null;
    }

    final endpoint = 'https://$bucket.s3.$region.amazonaws.com';
    final url = Uri.parse('$endpoint/$fileName');
    
    final DateTime now = DateTime.now().toUtc();
    final String dateStamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final String amzDate = "${dateStamp}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z";

    // 1. Canonical Request
    final String method = 'PUT';
    final String canonicalUri = '/$fileName';
    final String canonicalQueryString = '';
    // Headers must be sorted by name
    final String canonicalHeaders = 'host:$bucket.s3.$region.amazonaws.com\nx-amz-content-sha256:UNSIGNED-PAYLOAD\nx-amz-date:$amzDate\n';
    final String signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    final String payloadHash = 'UNSIGNED-PAYLOAD';
    
    final String canonicalRequest = '$method\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

    // 2. String to Sign
    final String algorithm = 'AWS4-HMAC-SHA256';
    final String credentialScope = '$dateStamp/$region/s3/aws4_request';
    final String stringToSign = '$algorithm\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest))}';

    // 3. Signing Key
    final List<int> kDate = Hmac(sha256, utf8.encode("AWS4$secretKey")).convert(utf8.encode(dateStamp)).bytes;
    final List<int> kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final List<int> kService = Hmac(sha256, kRegion).convert(utf8.encode("s3")).bytes;
    final List<int> kSigning = Hmac(sha256, kService).convert(utf8.encode("aws4_request")).bytes;

    // 4. Signature
    final String signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

    // 5. Authorization Header
    final String authorization = '$algorithm Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': authorization,
          'x-amz-date': amzDate,
          'x-amz-content-sha256': 'UNSIGNED-PAYLOAD',
          'Host': '$bucket.s3.$region.amazonaws.com',
          // Optional: Add Content-Type if known, but it must be included in signature if added. 
          // Since we didn't include it in canonical headers, we shouldn't add it here or we must add it to canonical headers.
          // However, S3 might default to application/octet-stream.
          // To be safe and simple, we omit it from signed headers and let it be.
        },
        body: fileBytes,
      );

      if (response.statusCode == 200) {
        return '$endpoint/$fileName';
      } else {
        print('Upload failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading to S3: $e');
      return null;
    }
  }
}
