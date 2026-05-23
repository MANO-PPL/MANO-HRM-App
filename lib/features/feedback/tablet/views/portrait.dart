import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/feedback_service.dart';
import '../../../../shared/services/mail_service.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/dashed_container.dart';
import '../../../../shared/widgets/toast_helper.dart';

class FeedbackTabletPortrait extends StatefulWidget {
  const FeedbackTabletPortrait({super.key});

  @override
  State<FeedbackTabletPortrait> createState() => _FeedbackTabletPortraitState();
}

class _FeedbackTabletPortraitState extends State<FeedbackTabletPortrait>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _selectedTabIndex = 0;
  late FeedbackService _feedbackService;

  final _bugFormKey = GlobalKey<FormState>();
  final _feedbackFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<File> _attachedFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initTabController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dio = Provider.of<AuthService>(context, listen: false).dio;
      _feedbackService = FeedbackService(dio);
    });
  }

  void _initTabController() {
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging ||
          _tabController!.index != _selectedTabIndex) {
        setState(() => _selectedTabIndex = _tabController!.index);
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final activeKey = _selectedTabIndex == 0 ? _bugFormKey : _feedbackFormKey;
    if (!activeKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final type = _selectedTabIndex == 0 ? 'BUG' : 'FEEDBACK';
      final typeLabel = _selectedTabIndex == 0 ? 'Bug Report' : 'Feedback';

      await _feedbackService.submitFeedback(
        title: _titleController.text,
        description: _descController.text,
        type: type,
        files: _attachedFiles,
      );

      // Trigger Email
      await MailService().sendFeedbackEmail(
        title: _titleController.text,
        description: _descController.text,
        type: type,
        attachments: _attachedFiles,
      );

      if (mounted) {
        context.showToast(
          '$typeLabel submitted successfully.',
          isSuccess: true,
        );

        _titleController.clear();
        _descController.clear();
        setState(() => _attachedFiles = []);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Submit Failed: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null) {
      setState(() {
        _attachedFiles.addAll(
          result.paths.where((p) => p != null).map((p) => File(p!)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Custom Tab Switcher
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _buildCustomTab(
                    "Bug Report",
                    Icons.bug_report_outlined,
                    0,
                    const Color(0xFFEF4444), // Red
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildCustomTab(
                    "Feedback",
                    Icons.chat_bubble_outline,
                    1,
                    const Color(0xFF5B60F6), // Blue
                    isDark,
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController!,
            // physics: const NeverScrollableScrollPhysics(), // Enable swipe
            children: [
              _buildFormContent(
                isBugReport: true,
                isDark: isDark,
                primaryColor: const Color(0xFFEF4444),
              ),
              _buildFormContent(
                isBugReport: false,
                isDark: isDark,
                primaryColor: const Color(0xFF5B60F6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTab(
    String label,
    IconData icon,
    int index,
    Color activeColor,
    bool isDark,
  ) {
    final isSelected = _selectedTabIndex == index;

    return InkWell(
      onTap: () {
        _tabController?.animateTo(index);
        setState(() => _selectedTabIndex = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2D3139) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent({
    required bool isBugReport,
    required bool isDark,
    required Color primaryColor,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        child: Form(
          key: isBugReport ? _bugFormKey : _feedbackFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(isBugReport ? "TITLE" : "TITLE"),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                style: GoogleFonts.poppins(fontSize: 16),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                decoration: InputDecoration(
                  hintText: isBugReport
                      ? "e.g., Error on Leave Page"
                      : "e.g., Suggestion for Dashboard",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF161B22)
                      : const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel("DESCRIPTION"),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                minLines: 3,
                maxLines: null,
                style: GoogleFonts.poppins(fontSize: 16),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                decoration: InputDecoration(
                  hintText: "Describe the issue or feedback in detail...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.all(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF161B22)
                      : const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel("SCREENSHOTS (OPTIONAL)"),
              const SizedBox(height: 12),

              InkWell(
                onTap: _pickFiles,
                borderRadius: BorderRadius.circular(16),
                child: DashedContainer(
                  color: primaryColor.withValues(
                    alpha: 0.3,
                  ), // Light colored dash
                  strokeWidth: 2,
                  borderRadius: 16,
                  gap: 6,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.file_upload_outlined,
                            color: primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _attachedFiles.isEmpty
                              ? "Click to upload images"
                              : "${_attachedFiles.length} images attached",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "PNG, JPG up to 50MB",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          "Submit Report",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}
