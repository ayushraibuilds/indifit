import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/colors.dart';
import '../../data/repositories/calendar_read_repository.dart';
import 'calendar_controller.dart';
import 'occurrence_actions_sheet.dart';

/// Calendar screen exposing Today, Week, and Month planning views for scheduled occurrences.
class ProgramCalendarScreen extends ConsumerStatefulWidget {
  const ProgramCalendarScreen({super.key});

  @override
  ConsumerState<ProgramCalendarScreen> createState() =>
      _ProgramCalendarScreenState();
}

class _ProgramCalendarScreenState extends ConsumerState<ProgramCalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showActions(CalendarOccurrenceReadItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => OccurrenceActionsSheet(occurrenceItem: item),
    );
  }

  Color _statusColor(String status, bool isDeload) {
    if (isDeload) return Colors.purple;
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'partiallyCompleted':
        return Colors.teal;
      case 'inProgress':
        return Colors.cyan;
      case 'rescheduled':
        return Colors.amber;
      case 'skipped':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'planned':
      default:
        return AppColors.primary;
    }
  }

  Widget _buildOccurrenceCard(CalendarOccurrenceReadItem item) {
    final occ = item.occurrence;
    final color = _statusColor(occ.status, item.isDeload);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.cardBackground,
      child: ListTile(
        onTap: () => _showActions(item),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(
            occ.status == 'completed'
                ? Icons.check_circle_rounded
                : occ.status == 'inProgress'
                ? Icons.play_circle_fill_rounded
                : Icons.fitness_center_rounded,
            color: color,
          ),
        ),
        title: Text(
          item.template.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: GoogleFonts.outfit().fontFamily,
          ),
        ),
        subtitle: Text(
          'Date: ${occ.effectiveLocalDate}${item.isDeload ? " • Deload" : ""}',
          style: TextStyle(
            color: item.isOverdue ? Colors.orange : Colors.grey,
            fontWeight: item.isOverdue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            occ.status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOccurrenceList(List<CalendarOccurrenceReadItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No workouts scheduled in this range.',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: GoogleFonts.outfit().fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, idx) => _buildOccurrenceCard(items[idx]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(calendarControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Training Calendar',
          style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded),
            tooltip: 'Author / Activate Program',
            onPressed: () => context.push('/program-author'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Selected Date'),
            Tab(text: 'Range'),
            Tab(text: 'Overdue'),
          ],
        ),
      ),
      body: uiState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Selected Date View
                _buildOccurrenceList(uiState.selectedDateOccurrences),
                // 2. Range View
                _buildOccurrenceList(uiState.rangeOccurrences),
                // 3. Overdue View
                _buildOccurrenceList(uiState.overdueOccurrences),
              ],
            ),
    );
  }
}
