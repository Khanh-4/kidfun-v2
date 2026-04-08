import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/location_repository.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class LocationHistoryScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const LocationHistoryScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  final _locationRepo = LocationRepository(DioClient.instance);
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await _locationRepo.getHistory(widget.profileId, dateStr);
      setState(() {
        _events = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching history: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch sử: ${widget.profileName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: AppColors.slate50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: _selectDate,
                  child: const Text('Thay đổi'),
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? Center(
                        child: Text(
                          'Không có dữ liệu vị trí',
                          style: GoogleFonts.nunito(color: AppColors.slate500, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final type = event['type'] as String? ?? 'LOCATION';
                          final timeStr = event['timestamp'] as String;
                          final time = DateTime.tryParse(timeStr)?.toLocal() ?? DateTime.now();
                          
                          IconData iconData = Icons.location_on;
                          Color iconColor = Colors.blue;
                          String title = 'Cập nhật Vị trí';
                          
                          if (type == 'ENTER') {
                            iconData = Icons.login;
                            iconColor = Colors.green;
                            title = 'Vào vùng an toàn: ${event['geofenceName']}';
                          } else if (type == 'EXIT') {
                            iconData = Icons.logout;
                            iconColor = Colors.orange;
                            title = 'Rời vùng an toàn: ${event['geofenceName']}';
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: iconColor.withOpacity(0.2),
                              child: Icon(iconData, color: iconColor),
                            ),
                            title: Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                            subtitle: Text(DateFormat('HH:mm:ss').format(time)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
