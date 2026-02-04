import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/attendance_record.dart';
import '../models/report.dart';
import '../services/export_service.dart';
import 'report_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, AttendanceRecord> _attendanceRecords = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAttendanceRecords();
  }

  // ────────────────────────────────────────────────
  //               DATA LOADING & ACTIONS
  // ────────────────────────────────────────────────

  Future<void> _loadAttendanceRecords() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('attendance')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      final records = <DateTime, AttendanceRecord>{};
      for (var record in response) {
        final date = DateTime.parse(record['date']);
        records[DateTime(date.year, date.month, date.day)] =
            AttendanceRecord.fromJson(record);
      }

      setState(() => _attendanceRecords = records);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading records: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTimeEntry(String type) async {
    if (_selectedDay == null) return;

    final now = TimeOfDay.now();
    final normalizedDate =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

    // Very basic time validation (you can make it more precise)
    String? errorMsg;
    switch (type) {
      case 'time_in_am':
        if (now.hour >= 8) errorMsg = 'AM Time-in must be before 8:00 AM';
        break;
      case 'time_out_am':
        if (now.hour < 11) errorMsg = 'AM Time-out should be after 11:00 AM';
        break;
      case 'time_in_pm':
        if (now.hour < 12 || now.hour >= 14)
          errorMsg = 'PM Time-in should be 12:00–1:59 PM';
        break;
      case 'time_out_pm':
        if (now.hour < 17) errorMsg = 'PM Time-out should be after 5:00 PM';
        break;
    }

    if (errorMsg != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMsg)));
      }
      return;
    }

    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      final userId = supabase.auth.currentUser!.id;
      final existing = _attendanceRecords[normalizedDate];

      if (existing != null) {
        await supabase.from('attendance').update({
          type: timeStr,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existing.id);
      } else {
        await supabase.from('attendance').insert({
          'user_id': userId,
          'date': normalizedDate.toIso8601String(),
          type: timeStr,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await _loadAttendanceRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Time recorded ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> _exportAllReports() async {
    // ... (keeping your original export logic)
    // You can apply similar soft styling to SnackBars if desired
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: true);

      if (response.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No reports to export yet.')),
          );
        }
        return;
      }

      final reports = response.map((j) => Report.fromJson(j)).toList();
      final exportService = ExportService();
      final fileName = await exportService.exportReportsToDocx(reports);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${reports.length} reports'),
            backgroundColor: Colors.green.shade700,
          ),
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
      setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────
  //                     BUILD
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final softBg = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF0F2F5);
    final cardBg = isDark ? const Color(0xFF2A2A3A) : Colors.white;
    final shadowColor =
        isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.08);

    final selectedRecord = _selectedDay != null
        ? _attendanceRecords[DateTime(
            _selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]
        : null;

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        
        title: const Text(
          'OJT Attendance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _isLoading ? null : _exportAllReports,
            tooltip: 'Export all reports',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _signOut,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 720;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ─── Calendar Card ───────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarFormat: CalendarFormat.month,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              todayDecoration: BoxDecoration(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: BoxDecoration(
                                color: theme.colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                              weekendTextStyle: TextStyle(
                                color: theme.colorScheme.error.withOpacity(0.7),
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle:
                                  theme.textTheme.titleLarge!.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              leftChevronIcon:
                                  const Icon(Icons.chevron_left_rounded),
                              rightChevronIcon:
                                  const Icon(Icons.chevron_right_rounded),
                            ),
                            eventLoader: (day) {
                              final d = DateTime(day.year, day.month, day.day);
                              return _attendanceRecords.containsKey(d)
                                  ? [d]
                                  : [];
                            },
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ─── Attendance + Report section ─────────────────
                        if (_selectedDay != null)
                          Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: shadowColor,
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('MMMM dd, yyyy – EEEE')
                                      .format(_selectedDay!),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (isWide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: _buildShiftSection('Morning',
                                              true, selectedRecord, theme)),
                                      const SizedBox(width: 24),
                                      Expanded(
                                          child: _buildShiftSection('Afternoon',
                                              false, selectedRecord, theme)),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      _buildShiftSection('Morning Shift', true,
                                          selectedRecord, theme),
                                      const SizedBox(height: 28),
                                      _buildShiftSection('Afternoon Shift',
                                          false, selectedRecord, theme),
                                    ],
                                  ),

                                const SizedBox(height: 32),
                                const Divider(height: 1),
                                const SizedBox(height: 24),

                                // Write Report Button (FAB style)
                                Center(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ReportScreen(date: _selectedDay!),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit_note_rounded,
                                        size: 28),
                                    label: const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 4),
                                      child: Text('Write Narrative Report',
                                          style: TextStyle(fontSize: 16)),
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 20),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildShiftSection(
      String title, bool isMorning, AttendanceRecord? record, ThemeData theme) {
    final times = isMorning
        ? [
            ('Time In (AM)', 'time_in_am', record?.timeInAm),
            ('Time Out (AM)', 'time_out_am', record?.timeOutAm)
          ]
        : [
            ('Time In (PM)', 'time_in_pm', record?.timeInPm),
            ('Time Out (PM)', 'time_out_pm', record?.timeOutPm)
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        ...times.map((t) {
          final (label, field, value) = t;
          final recorded = value != null && value.isNotEmpty;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(
                  recorded ? Icons.check_circle : Icons.access_time_rounded,
                  color: recorded ? Colors.green.shade400 : null,
                ),
                title: Text(label),
                subtitle: Text(
                  recorded ? value! : 'Not recorded',
                  style: TextStyle(
                    color: recorded ? null : theme.disabledColor,
                  ),
                ),
                trailing: FilledButton.tonal(
                  onPressed: recorded ? null : () => _handleTimeEntry(field),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Record'),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
