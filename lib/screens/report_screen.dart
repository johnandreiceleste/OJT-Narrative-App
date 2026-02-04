import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/report.dart';
import '../services/export_service.dart';

class ReportScreen extends StatefulWidget {
  final DateTime date;

  const ReportScreen({super.key, required this.date});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _titleController = TextEditingController();
  final _narrativeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageUrl;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isExporting = false;
  Report? _existingReport;

  @override
  void initState() {
    super.initState();
    _loadExistingReport();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _narrativeController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingReport() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final normalizedDate =
          DateTime(widget.date.year, widget.date.month, widget.date.day);

      final response = await supabase
          .from('reports')
          .select()
          .eq('user_id', userId)
          .eq('date', normalizedDate.toIso8601String())
          .maybeSingle();

      if (response != null && mounted) {
        final report = Report.fromJson(response);
        setState(() {
          _existingReport = report;
          _titleController.text = report.title;
          _narrativeController.text = report.narrative;
          _imageUrl = report.imageUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        setState(() {
          _imageBytes = file.bytes;
          _imageName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final normalizedDate =
          DateTime(widget.date.year, widget.date.month, widget.date.day);

      String? uploadedImageUrl = _imageUrl;

      if (_imageBytes != null && _imageName != null) {
        final fileName =
            '${userId}_${normalizedDate.millisecondsSinceEpoch}_$_imageName';
        await supabase.storage.from('report-images').uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: const FileOptions(upsert: true),
            );

        uploadedImageUrl =
            supabase.storage.from('report-images').getPublicUrl(fileName);
      }

      final reportData = {
        'user_id': userId,
        'date': normalizedDate.toIso8601String(),
        'title': _titleController.text.trim(),
        'narrative': _narrativeController.text.trim(),
        'image_url': uploadedImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_existingReport != null) {
        await supabase
            .from('reports')
            .update(reportData)
            .eq('id', _existingReport!.id);
      } else {
        reportData['created_at'] = DateTime.now().toIso8601String();
        await supabase.from('reports').insert(reportData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Report saved successfully ✓'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportAllReports() async {
    setState(() => _isExporting = true);
    // (keeping your original export logic – can be styled similarly if desired)
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: true);

      final reports = response.map((json) => Report.fromJson(json)).toList();

      if (reports.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No reports to export yet')),
          );
        }
        return;
      }

      final exportService = ExportService();
      final fileName = await exportService.exportReportsToDocx(reports);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Exported to $fileName'),
              backgroundColor: Colors.green.shade700),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final softBg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final shadow = isDark
        ? BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(4, 6))
        : BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10));

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: softBg,
        foregroundColor: theme.colorScheme.onBackground,
        title: Text(
          'Daily Report – ${DateFormat('MMM dd, yyyy').format(widget.date)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.download_rounded),
              onPressed: _isExporting ? null : _exportAllReports,
              tooltip: 'Export All Reports',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 48 : 20,
                      vertical: 16,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ─── Image Upload / Preview ───────────────────────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [shadow],
                                ),
                                clipBehavior: Clip.antiAlias,
                                height: isWide ? 420 : 280,
                                child: InkWell(
                                  onTap: _pickImage,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (_imageBytes != null)
                                        Image.memory(_imageBytes!,
                                            fit: BoxFit.cover)
                                      else if (_imageUrl != null)
                                        Image.network(
                                          _imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildEmptyImagePlaceholder(),
                                        )
                                      else
                                        _buildEmptyImagePlaceholder(),
                                      Positioned(
                                        bottom: 16,
                                        right: 16,
                                        child: FloatingActionButton.small(
                                          onPressed: _pickImage,
                                          backgroundColor: theme
                                              .colorScheme.primary
                                              .withOpacity(0.9),
                                          child: const Icon(Icons
                                              .add_photo_alternate_rounded),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // ─── Title ────────────────────────────────────────────────
                              _buildSoftTextField(
                                controller: _titleController,
                                label: 'Report Title',
                                hint: 'e.g. Daily Activities – Site Inspection',
                                validator: (v) => v?.trim().isEmpty ?? true
                                    ? 'Title is required'
                                    : null,
                              ),

                              const SizedBox(height: 28),

                              // ─── Narrative ────────────────────────────────────────────
                              _buildSoftTextField(
                                controller: _narrativeController,
                                label: 'Narrative / Daily Summary',
                                hint:
                                    'Describe what you did today, challenges, learnings...',
                                maxLines: 14,
                                validator: (v) => v?.trim().isEmpty ?? true
                                    ? 'Please write your report'
                                    : null,
                              ),

                              const SizedBox(height: 40),

                              // ─── Save Button ──────────────────────────────────────────
                              FilledButton.icon(
                                onPressed: _isSaving ? null : _saveReport,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  _isSaving ? 'Saving...' : 'Save Report',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_rounded,
            size: 72,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to upload photo / proof',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 6 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }
}
