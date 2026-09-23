import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PickupSchedulerWidget extends StatefulWidget {
  final String collectorUid;
  final Function(DateTime selectedDate, String timeSlot) onScheduleConfirmed;

  const PickupSchedulerWidget({
    super.key,
    required this.collectorUid,
    required this.onScheduleConfirmed,
  });

  @override
  State<PickupSchedulerWidget> createState() => _PickupSchedulerWidgetState();
}

class _PickupSchedulerWidgetState extends State<PickupSchedulerWidget> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoadingSlots = false;
  List<String> _availableSlots = [];

  // Hardcoded time slots (8 AM - 5 PM, 2-hour windows)
  final List<String> _timeSlots = [
    '08:00-10:00',
    '10:00-12:00',
    '13:00-15:00',
    '15:00-17:00',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Schedule Pickup',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Date Picker
          Text('Select Date', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate != null
                        ? DateFormat(
                            'EEEE, MMMM d, yyyy',
                          ).format(_selectedDate!)
                        : 'Tap to select date',
                    style: TextStyle(
                      color: _selectedDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedDate != null) ...[
            const SizedBox(height: 16),

            // Time Slot Selector
            Text(
              'Select Time Slot',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _isLoadingSlots
                ? const Center(child: CircularProgressIndicator())
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSlots.map((slot) {
                      final isSelected = _selectedTimeSlot == slot;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTimeSlot = selected ? slot : null;
                          });
                        },
                        selectedColor: Colors.blue.shade700,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
          ],

          const SizedBox(height: 24),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedDate != null && _selectedTimeSlot != null
                  ? _confirmSchedule
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Confirm Schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)), // 30 days ahead
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null;
      });
      await _loadAvailableSlots(picked);
    }
  }

  Future<void> _loadAvailableSlots(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _availableSlots = [];
    });

    try {
      final dateString = DateFormat('yyyy-MM-dd').format(date);

      // Query booked slots for this collector on this date
      final bookedSnapshot = await FirebaseFirestore.instance
          .collection('timeSlots')
          .where('collectorUid', isEqualTo: widget.collectorUid)
          .where('date', isEqualTo: dateString)
          .where('isBooked', isEqualTo: true)
          .get();

      final bookedSlots = bookedSnapshot.docs
          .map((doc) => doc['startTime'] as String)
          .toSet();

      // Filter out booked slots
      setState(() {
        _availableSlots = _timeSlots
            .where((slot) => !bookedSlots.contains(slot.split('-').first))
            .toList();
      });
    } catch (e) {
      print('❌ Error loading slots: $e');
      // Fallback: show all slots if query fails
      setState(() {
        _availableSlots = _timeSlots;
      });
    } finally {
      setState(() {
        _isLoadingSlots = false;
      });
    }
  }

  void _confirmSchedule() {
    if (_selectedDate != null && _selectedTimeSlot != null) {
      widget.onScheduleConfirmed(_selectedDate!, _selectedTimeSlot!);
    }
  }
}
