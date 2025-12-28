import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Modèle pour la réponse Cloudinary
class CloudinaryUploadResponse {
  final String secureUrl;
  final String publicId;
  final int width;
  final int height;
  final String format;
  final int fileSize;

  CloudinaryUploadResponse({
    required this.secureUrl,
    required this.publicId,
    required this.width,
    required this.height,
    required this.format,
    required this.fileSize,
  });

  factory CloudinaryUploadResponse.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResponse(
      secureUrl: json['secure_url'] as String? ?? '',
      publicId: json['public_id'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      format: json['format'] as String? ?? 'jpg',
      fileSize: json['bytes'] as int? ?? 0,
    );
  }

  /// Génère une URL optimisée avec transformations
  String getOptimizedUrl({
    int? width,
    int? height,
    String quality = 'auto',
    String fetch = 'auto',
  }) {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'dfw0pwwdr';
    final baseUrl =
        'https://res.cloudinary.com/$cloudName/image/upload/f_$fetch,q_$quality';

    String transformations = '';
    if (width != null || height != null) {
      if (width != null && height != null) {
        transformations = 'c_fill,w_$width,h_$height';
      } else if (width != null) {
        transformations = 'w_$width';
      } else {
        transformations = 'h_$height';
      }
    }

    return transformations.isNotEmpty
        ? '$baseUrl/$transformations/$publicId.$format'
        : '$baseUrl/$publicId.$format';
  }
}

/// Service pour gérer les uploads vers Cloudinary
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  // Récupérer les valeurs depuis les variables d'environnement
  String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'dfw0pwwdr';
  String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'hermine_unsigned_images';
  String get _uploadUrl => 'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  /// Upload une image vers Cloudinary
  Future<CloudinaryUploadResponse?> uploadImage(
    File imageFile, {
    bool optimize = true,
  }) async {
    try {
      print('📤 Upload vers Cloudinary: ${imageFile.path}');

      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      // Ajouter le fichier
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      // Ajouter les paramètres
      request.fields['upload_preset'] = _uploadPreset;

      // Ajouter les tags pour organiser
      request.fields['tags'] = 'hermin,post';

      // Ajouter les métadonnées
      request.fields['context'] = jsonEncode({
        'app': 'hermin',
        'type': 'post',
      });

      // Envoyer
      final streamResponse = await request.send();
      final response = await http.Response.fromStream(streamResponse);

      print('📨 Réponse Cloudinary: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ Erreur upload: ${response.body}');
        return null;
      }

      // Parser la réponse
      final jsonResp = jsonDecode(response.body) as Map<String, dynamic>;
      final uploadResponse = CloudinaryUploadResponse.fromJson(jsonResp);

      print('✅ Upload réussi: ${uploadResponse.secureUrl}');

      return uploadResponse;
    } catch (e) {
      print('❌ Exception upload: $e');
      return null;
    }
  }

  /// Upload plusieurs images
  Future<List<CloudinaryUploadResponse>> uploadMultipleImages(
    List<File> imageFiles, {
    bool optimize = true,
  }) async {
    final results = <CloudinaryUploadResponse>[];

    for (final file in imageFiles) {
      final response = await uploadImage(file, optimize: optimize);
      if (response != null) {
        results.add(response);
      }
    }

    return results;
  }

  /// Supprime une image de Cloudinary (nécessite auth)
  Future<bool> deleteImage(String publicId) async {
    try {
      print('🗑️  Suppression image: $publicId');
      // Nota: La suppression en non signé n'est pas possible
      // Tu devras passer par une Cloud Function Firebase
      return false;
    } catch (e) {
      print('❌ Erreur suppression: $e');
      return false;
    }
  }

  /// Vérifie si l'URL est valide
  Future<bool> isImageUrlValid(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur vérification URL: $e');
      return false;
    }
  }

  /// Génère une URL optimisée à partir d'une URL Cloudinary
  static String optimizeUrl(
    String cloudinaryUrl, {
    int? width,
    int? height,
    String quality = 'auto',
  }) {
    if (!cloudinaryUrl.contains('cloudinary.com')) {
      return cloudinaryUrl;
    }

    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'dfw0pwwdr';
    final baseUrl =
        'https://res.cloudinary.com/$cloudName/image/upload/f_auto,q_$quality';

    String transformations = '';
    if (width != null || height != null) {
      if (width != null && height != null) {
        transformations = 'c_fill,w_$width,h_$height';
      } else if (width != null) {
        transformations = 'w_$width';
      } else {
        transformations = 'h_$height';
      }
    }

    // Extraire le public ID
    final pathParts = cloudinaryUrl.split('/');
    final publicIdWithExt = pathParts.last;

    return transformations.isNotEmpty
        ? '$baseUrl/$transformations/$publicIdWithExt'
        : '$baseUrl/$publicIdWithExt';
  }
}
