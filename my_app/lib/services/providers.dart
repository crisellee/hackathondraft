import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bulk_upload_service.dart';
import 'concern_service.dart';
import '../models/concern.dart';

final userRoleProvider = StateProvider<String?>((ref) => null);
final userIdProvider = StateProvider<String?>((ref) => null);
final bulkUploadServiceProvider = Provider((ref) => BulkUploadService());

// Dark Mode Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// Shared Real-time Stream for all concerns
final allConcernsProvider = StreamProvider<List<Concern>>((ref) {
  final service = ref.watch(concernServiceProvider);
  return service.getConcerns();
});
