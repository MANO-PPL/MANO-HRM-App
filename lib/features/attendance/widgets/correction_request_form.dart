
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../shared/services/auth_service.dart';
import '../models/correction_request.dart';
import '../services/attendance_service.dart';

import 'correction_ui_components.dart';
import '../../../../features/leave/widgets/custom_date_picker_dialog.dart';

class CorrectionRequestForm extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback? onClose; // Added
  final DateTime? initialDate;

  const CorrectionRequestForm({super.key, required this.onSuccess, this.onClose, this.initialDate});

  @override
  State<CorrectionRequestForm> createState() => _CorrectionRequestFormState();
}

class _CorrectionRequestFormState extends State<CorrectionRequestForm> {
  late AttendanceService _service;
  bool _isLoading = false;
  bool _isLoadingRecords = false;

  // Form State
  late DateTime _requestDate;
  CorrectionType _type = CorrectionType.missedPunch;
  CorrectionMethod _method = CorrectionMethod.addSession;
  final TextEditingController _reasonController = TextEditingController();
  
  // Method: Reset
  TimeOfDay? _timeIn;
  TimeOfDay? _timeOut;

  // Method: Add Session (List of maps)
  List<Map<String, TimeOfDay>> _sessions = [];
  
  // Attachments
  List<PlatformFile> _selectedFiles = [];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _requestDate = widget.initialDate ?? DateTime.now();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AttendanceService(authService.dio);
    
    // Auto-fetch if date is provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchExistingRecords(_requestDate);
    });
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _submit() async {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a reason for the correction")),
      );
      return;
    }

    Map<String, dynamic> correctionData = {};

    if (_method == CorrectionMethod.reset || _method == CorrectionMethod.fix) {
      if (_timeIn == null || _timeOut == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select both 'Time In' and 'Time Out'")),
        );
        return;
      }
      correctionData = {
        'requested_time_in': '${_timeIn!.hour.toString().padLeft(2, '0')}:${_timeIn!.minute.toString().padLeft(2, '0')}:00',
        'requested_time_out': '${_timeOut!.hour.toString().padLeft(2, '0')}:${_timeOut!.minute.toString().padLeft(2, '0')}:00',
      };
    } else if (_method == CorrectionMethod.addSession) {
      if (_sessions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add at least one session")),
        );
        return;
      }
      correctionData = {
        'sessions': _sessions.map((s) => {
          'time_in': '${s['in']!.hour.toString().padLeft(2, '0')}:${s['in']!.minute.toString().padLeft(2, '0')}:00',
          'time_out': '${s['out']!.hour.toString().padLeft(2, '0')}:${s['out']!.minute.toString().padLeft(2, '0')}:00',
        }).toList(),
      };
    }

    setState(() => _isLoading = true);

    try {
      final position = await _getCurrentLocation();
      
      await _service.submitCorrectionRequest(
        requestDate: DateFormat('yyyy-MM-dd').format(_requestDate),
        correctionType: _type.toString().split('.').last.replaceAll(RegExp(r'(?=[A-Z])'), '_').toLowerCase(),
        correctionMethod: _method.toString().split('.').last.replaceAll(RegExp(r'(?=[A-Z])'), '_').toLowerCase(),
        reason: _reasonController.text,
        correctionData: correctionData, // service now auto-converts to proposed_data array
        latitude: position?.latitude,
        longitude: position?.longitude,
        attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
      );
      
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime(bool isTimeIn, {int? sessionIndex}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF4F46E5),
            colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (sessionIndex != null) {
          if (isTimeIn) _sessions[sessionIndex]['in'] = picked;
          else _sessions[sessionIndex]['out'] = picked;
        } else {
          if (isTimeIn) _timeIn = picked;
          else _timeOut = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchExistingRecords(DateTime date) async {
    setState(() => _isLoadingRecords = true);
    try {
      final fromDate = DateFormat('yyyy-MM-dd').format(date);
      final records = await _service.getMyRecords(
        fromDate: fromDate,
        toDate: fromDate,
        limit: 50,
      );

      if (records.isNotEmpty) {
        // Filter records that have a timeIn
        final validRecords = records.where((r) => r.timeIn != null).toList();
        
        if (validRecords.isNotEmpty) {
          // Sort by timeIn to get the earliest/first session
          validRecords.sort((a, b) => a.timeIn!.compareTo(b.timeIn!));
          
          final record = validRecords.first;
        if (record.timeIn != null || record.timeOut != null) {
          setState(() {
            if (record.timeIn != null) {
              final dtIn = DateTime.parse(record.timeIn!);
              _timeIn = TimeOfDay.fromDateTime(dtIn);
            }
            if (record.timeOut != null) {
              final dtOut = DateTime.parse(record.timeOut!);
              _timeOut = TimeOfDay.fromDateTime(dtOut);
            }
            
            // Sync sessions if in addSession mode
            if (_timeIn != null || _timeOut != null) {
               _sessions = [{
                 'in': _timeIn ?? const TimeOfDay(hour: 9, minute: 0),
                 'out': _timeOut ?? const TimeOfDay(hour: 18, minute: 0),
               }];
            }
          });
        }
        }
      } else {
        // Clear if no records
        setState(() {
          _timeIn = null;
          _timeOut = null;
          _sessions = [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching records: $e");
    } finally {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!,
              width: 1,
            ),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF30363D) : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CorrectionHeader(
                      title: 'Apply Correction',
                      onClose: widget.onClose, // Pass onClose
                    ),
                    
                    const CorrectionLabel(label: 'Date'),
                    CorrectionInputField(
                      value: DateFormat('dd-MM-yyyy').format(_requestDate),
                      suffixIcon: Icons.calendar_today_outlined,
                      isLoading: _isLoadingRecords,
                      onTap: () async {
                        final date = await showDialog<DateTime>(
                          context: context,
                          builder: (context) => CustomDatePickerDialog(
                            initialDate: _requestDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          ),
                        );
                        if (date != null) {
                          setState(() => _requestDate = date);
                          _fetchExistingRecords(date);
                        }
                      },
                    ),

                    const CorrectionLabel(label: 'Type'),
                    CorrectionInputField(
                      value: {
                        CorrectionType.correction: 'Correction',
                        CorrectionType.missedPunch: 'Missed Punch',
                        CorrectionType.overtime: 'Overtime',
                        CorrectionType.other: 'Other',
                      }[_type]!,
                      suffixIcon: Icons.keyboard_arrow_down,
                      onTap: () async {
                        final result = await showModalBottomSheet<CorrectionType>(
                          context: context,
                          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                          builder: (context) => Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: CorrectionType.values.map((e) => ListTile(
                                title: Text(
                                  {
                                    CorrectionType.correction: 'Correction',
                                    CorrectionType.missedPunch: 'Missed Punch',
                                    CorrectionType.overtime: 'Overtime',
                                    CorrectionType.other: 'Other',
                                  }[e]!,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                ),
                                onTap: () => Navigator.pop(context, e),
                                selected: _type == e,
                                selectedTileColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                selectedColor: const Color(0xFF4F46E5),
                              )).toList(),
                            ),
                          ),
                        );
                        if (result != null) setState(() => _type = result);
                      },
                    ),

                    const CorrectionLabel(label: 'Method'),
                    CorrectionSegmentedControl<CorrectionMethod>(
                      value: _method == CorrectionMethod.fix ? CorrectionMethod.addSession : _method,
                      items: {
                        CorrectionMethod.addSession: 'Manual Correction',
                        CorrectionMethod.reset: 'Reset Day',
                      },
                      onChanged: (val) => setState(() => _method = val),
                    ),

                    if (_method == CorrectionMethod.addSession) ...[
                      const CorrectionLabel(label: 'Sessions'),
                      ..._sessions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final session = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: CorrectionInputField(
                                  value: _formatTime(session['in']),
                                  suffixIcon: Icons.access_time,
                                  onTap: () => _pickTime(true, sessionIndex: index),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CorrectionInputField(
                                  value: _formatTime(session['out']),
                                  suffixIcon: Icons.access_time,
                                  onTap: () => _pickTime(false, sessionIndex: index),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: isDark ? Colors.redAccent : Colors.red),
                                onPressed: () => setState(() => _sessions.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      }),
                      CorrectionDashedButton(
                        label: 'Add Another Session',
                        onTap: () => setState(() => _sessions.add({'in': const TimeOfDay(hour: 9, minute: 0), 'out': const TimeOfDay(hour: 18, minute: 0)})),
                      ),
                    ] else ...[
                      const CorrectionLabel(label: 'Timings'),
                      Row(
                        children: [
                          Expanded(
                            child: CorrectionInputField(
                              value: _formatTime(_timeIn),
                              hintText: 'In Time',
                              suffixIcon: Icons.access_time,
                              onTap: () => _pickTime(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CorrectionInputField(
                              value: _formatTime(_timeOut),
                              hintText: 'Out Time',
                              suffixIcon: Icons.access_time,
                              onTap: () => _pickTime(false),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const CorrectionLabel(label: 'Reason'),
                    CorrectionInputField(
                      value: _reasonController.text,
                      hintText: 'Why is this correction needed?',
                      isMultiline: true,
                      onTap: () async {
                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) => _ReasonInputDialog(initialValue: _reasonController.text),
                        );
                        if (result != null) setState(() => _reasonController.text = result);
                      },
                    ),

                    const SizedBox(height: 16),
                    
                    // Attachments Section
                    InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? Colors.black12 : Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.attach_file,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Attach Documents (PDF, Images)',
                                style: GoogleFonts.poppins(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.add_circle_outline,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    file.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => setState(() => _selectedFiles.removeAt(index)),
                                  child: const Icon(Icons.close, size: 14, color: Colors.red),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 24),

                    CorrectionSubmitButton(
                      label: 'Submit Request',
                      isLoading: _isLoading,
                      onTap: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

class _ReasonInputDialog extends StatefulWidget {
  final String initialValue;
  const _ReasonInputDialog({required this.initialValue});

  @override
  State<_ReasonInputDialog> createState() => _ReasonInputDialogState();
}

class _ReasonInputDialogState extends State<_ReasonInputDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      title: Text('Enter Reason', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Why is this correction needed?',
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
          child: const Text('Done', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
