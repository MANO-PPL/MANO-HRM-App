import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'custom_date_picker_dialog.dart';
import '../../../shared/widgets/toast_helper.dart';

class LeaveForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final bool isLoading;
  final Function(DateTime?, DateTime?)? onDatesChanged; // Trace callback

  const LeaveForm({super.key, required this.onSubmit, this.isLoading = false, this.onDatesChanged});

  @override
  State<LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<LeaveForm> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Casual Leave';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final _reasonController = TextEditingController();
  final _otherTypeController = TextEditingController(); // ADDED
  PlatformFile? _attachedFile;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _attachedFile = result.files.first);
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedType == 'Other' && _otherTypeController.text.trim().isEmpty) {
        context.showToast("Please specify the leave type.", isWarning: true);
        return;
      }

      widget.onSubmit({
        'leave_type': _selectedType == 'Other' ? _otherTypeController.text : _selectedType,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'reason': _reasonController.text,
        'attachment': _attachedFile,
      });
      // Optional: Clear form
      _otherTypeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey : const Color(0xFF64748B); // Slate 500
    final inputFillColor = isDark ? Colors.transparent : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0); // Slate 200

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(Icons.add, color: const Color(0xFF5B60F6), size: 24),
               const SizedBox(width: 8),
               Text("APPLY FOR LEAVE", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 24),
          
          // Leave Type
          Text("LEAVE TYPE", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedType,
            items: ['Casual Leave', 'Sick Leave', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.poppins(color: textColor)))).toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF5B60F6))),
              filled: true,
              fillColor: inputFillColor,
            ),
            dropdownColor: isDark ? const Color(0xFF161B22) : Colors.white,
            icon: Icon(Icons.keyboard_arrow_down, color: labelColor),
          ),
          
          if (_selectedType == 'Other') ...[
             const SizedBox(height: 12),
             TextFormField(
               controller: _otherTypeController,
               style: GoogleFonts.poppins(color: textColor),
               decoration: InputDecoration(
                 hintText: 'Enter custom leave type',
                 hintStyle: GoogleFonts.poppins(color: labelColor),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                 focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF5B60F6))),
                 filled: true,
                 fillColor: inputFillColor,
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
               ),
             ),
          ],
          
          const SizedBox(height: 16),
          
          // Dates
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("START DATE", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final d = await showDialog<DateTime>(
                          context: context,
                          builder: (context) => CustomDatePickerDialog(
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          ),
                        );
                        if(d != null) {
                           setState(() => _startDate = d);
                           widget.onDatesChanged?.call(_startDate, _endDate);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(12),
                          color: inputFillColor,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 16, color: labelColor),
                            const SizedBox(width: 8),
                            Text(DateFormat('MMM dd, yyyy').format(_startDate), style: GoogleFonts.poppins(color: textColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("END DATE", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final d = await showDialog<DateTime>(
                          context: context,
                          builder: (context) => CustomDatePickerDialog(
                            initialDate: _endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          ),
                        );
                        if(d != null) {
                           setState(() => _endDate = d);
                           widget.onDatesChanged?.call(_startDate, _endDate);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(12),
                          color: inputFillColor,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 16, color: labelColor),
                            const SizedBox(width: 8),
                            Text(DateFormat('MMM dd, yyyy').format(_endDate), style: GoogleFonts.poppins(color: textColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // Duration Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
               color: isDark ? const Color(0xFF161B22).withOpacity(0.5) : const Color(0xFFF8FAFC),
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Duration", style: GoogleFonts.poppins(color: const Color(0xFF5B60F6), fontSize: 13, fontWeight: FontWeight.w500)),
                 const SizedBox(height: 4),
                 Text(
                   "${_endDate.difference(_startDate).inDays + 1} Days", 
                   style: GoogleFonts.poppins(
                     color: textColor, 
                     fontSize: 16, 
                     fontWeight: FontWeight.bold
                   )
                 ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Reason
          Text("REASON", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            style: GoogleFonts.poppins(color: textColor),
            decoration: InputDecoration(
              hintText: 'Why do you need leave?',
              hintStyle: GoogleFonts.poppins(color: labelColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF5B60F6))),
              filled: true,
              fillColor: inputFillColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (v) => v!.isEmpty ? 'Please enter a reason' : null,
          ),
          
          const SizedBox(height: 16),
          
          // Attachment
          Text("ATTACHMENT (OPTIONAL)", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor)),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickFile,
            child: Container(
               decoration: BoxDecoration(
                 color: isDark ? null : const Color(0xFFF8FAFC), 
                 borderRadius: BorderRadius.circular(12),
               ),
               child: DottedBorderContainer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(Icons.attach_file, color: const Color(0xFF5B60F6).withOpacity(0.8), size: 18),
                       const SizedBox(width: 8),
                       Text(
                         _attachedFile != null ? _attachedFile!.name : "Click to attach document...",
                         style: GoogleFonts.poppins(color: labelColor, fontSize: 13),
                         overflow: TextOverflow.ellipsis,
                       ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32), 
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B60F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: widget.isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Submit Request", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper for Dotted Border
class DottedBorderContainer extends StatelessWidget {
  final Widget child;
  const DottedBorderContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _DottedPainter(color: Colors.grey.withOpacity(0.5)),
        child: child,
      ),
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  _DottedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Simple implementation or use package:dotted_border for simplicity if available. 
    // Drawing a rect with dash effect manually for zero dependency if preferred, 
    // but here just a simple border visual helper.
    // For now standard border dash.
    
    double dashWidth = 5, dashSpace = 3, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      canvas.drawLine(Offset(startX, size.height), Offset(startX + dashWidth, size.height), paint);
      startX += dashWidth + dashSpace;
    }
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      canvas.drawLine(Offset(size.width, startY), Offset(size.width, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
