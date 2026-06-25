import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;

import '../core/theme/app_theme.dart';
import '../models/pending_upload.dart';
import '../repositories/local/pending_upload_repository.dart';
import '../services/upload_queue_service.dart';

class PendingUploadsScreen extends StatelessWidget {
  const PendingUploadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = PendingUploadRepository.instance;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الرفوعات المعلّقة'),
          actions: [
            IconButton(
              tooltip: 'إعادة المحاولة للكل',
              onPressed: () async {
                await UploadQueueService.instance.retryAllNow();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم بدء إعادة المحاولة لكل الصور'),
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ValueListenableBuilder<Box<PendingUpload>>(
          valueListenable: repository.listenable,
          builder: (context, _, __) {
            final uploads = repository.getAll();
            if (uploads.isEmpty) {
              return const Center(
                child: Text('لا توجد صور معلّقة حالياً'),
              );
            }

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  child: Text(
                    'المهام المعلقة: ${uploads.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: uploads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final upload = uploads[index];
                      return _UploadCard(upload: upload);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final PendingUpload upload;

  const _UploadCard({required this.upload});

  @override
  Widget build(BuildContext context) {
    final status = _statusText(upload.status);
    final statusColor = _statusColor(upload.status);
    final canRetryNow = upload.status != PendingUploadStatus.uploading;

    final formatter = intl.DateFormat('dd/MM/yyyy HH:mm', 'ar');
    final updatedAtText = formatter.format(upload.updatedAt.toLocal());
    final nextAttemptText = formatter.format(upload.nextAttemptAt.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UploadThumbnail(path: upload.localFilePath),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upload.patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الخطوة ${upload.stepNumber}: ${upload.stepTitle}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (upload.status == PendingUploadStatus.uploading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: upload.progress <= 0 ? null : upload.progress,
                    minHeight: 6,
                  ),
                ],
                if (upload.lastError != null && upload.lastError!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    upload.lastError!,
                    style: const TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'آخر تحديث: $updatedAtText',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'المحاولة القادمة: $nextAttemptText',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                StreamBuilder<DateTime>(
                  stream: Stream.periodic(
                    const Duration(seconds: 1),
                    (_) => DateTime.now(),
                  ),
                  initialData: DateTime.now(),
                  builder: (context, snapshot) {
                    final now = snapshot.data ?? DateTime.now();
                    final remaining = upload.nextAttemptAt.toLocal().difference(now);
                    return Text(
                      'الوقت المتبقي للمحاولة القادمة: ${_formatRemaining(remaining)}',
                      style: TextStyle(
                        color: remaining.inSeconds <= 0
                            ? AppTheme.successGreen
                            : Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'إعادة المحاولة الآن',
            onPressed: canRetryNow
                ? () async {
                    await UploadQueueService.instance.retryNow(upload.id);
                  }
                : null,
            icon: const Icon(Icons.replay_rounded),
          ),
        ],
      ),
    );
  }

  String _statusText(PendingUploadStatus status) {
    switch (status) {
      case PendingUploadStatus.uploading:
        return 'جاري الرفع';
      case PendingUploadStatus.pending:
        return 'بانتظار الرفع';
    }
  }

  Color _statusColor(PendingUploadStatus status) {
    switch (status) {
      case PendingUploadStatus.uploading:
        return AppTheme.primaryBlue;
      case PendingUploadStatus.pending:
        return const Color(0xFFF59E0B);
    }
  }

  String _formatRemaining(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'جاهزة الآن';
    }
    if (duration.inMinutes >= 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      if (seconds == 0) {
        return '$minutes دقيقة';
      }
      return '$minutes دقيقة و $seconds ثانية';
    }
    return '${duration.inSeconds} ثانية';
  }
}

class _UploadThumbnail extends StatelessWidget {
  final String path;

  const _UploadThumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        color: Colors.grey.shade100,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : Icon(
                Icons.broken_image_outlined,
                color: Colors.grey.shade500,
              ),
      ),
    );
  }
}
