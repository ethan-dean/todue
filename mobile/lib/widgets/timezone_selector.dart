import 'package:flutter/material.dart';
import '../services/user_api.dart';

const List<String> _popularTimezones = [
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Anchorage',
  'Pacific/Honolulu',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Asia/Tokyo',
  'Asia/Shanghai',
  'Asia/Kolkata',
  'Australia/Sydney',
  'Pacific/Auckland',
];

class TimezoneSelector extends StatefulWidget {
  final String currentTimezone;
  final ValueChanged<String> onSelected;

  const TimezoneSelector({
    Key? key,
    required this.currentTimezone,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<TimezoneSelector> createState() => _TimezoneSelectorState();
}

class _TimezoneSelectorState extends State<TimezoneSelector> {
  List<String> _allTimezones = [];
  List<String> _filteredTimezones = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTimezones();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTimezones() async {
    try {
      final timezones = await userApi.getTimezones();
      if (mounted) {
        setState(() {
          _allTimezones = timezones;
          _filteredTimezones = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allTimezones = _popularTimezones;
          _filteredTimezones = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        _filteredTimezones = [];
      } else {
        final q = query.toLowerCase().replaceAll(' ', '_');
        final qSpace = query.toLowerCase();
        _filteredTimezones = _allTimezones.where((tz) {
          return tz.toLowerCase().contains(q) ||
              tz.toLowerCase().replaceAll('_', ' ').contains(qSpace);
        }).toList();
      }
    });
  }

  String _formatTz(String tz) => tz.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Timezone'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search timezones...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: _onSearchChanged,
              autofocus: true,
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: _searchQuery.trim().isEmpty
                  ? _buildPopularList()
                  : _buildFilteredList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPopularList() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Popular',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ..._popularTimezones.map((tz) => _buildTimezoneItem(tz)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'All Timezones',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ..._allTimezones.map((tz) => _buildTimezoneItem(tz)),
      ],
    );
  }

  Widget _buildFilteredList() {
    if (_filteredTimezones.isEmpty) {
      return const Center(
        child: Text('No timezones found', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: _filteredTimezones.length,
      itemBuilder: (context, index) => _buildTimezoneItem(_filteredTimezones[index]),
    );
  }

  Widget _buildTimezoneItem(String tz) {
    final isSelected = tz == widget.currentTimezone;
    return ListTile(
      title: Text(
        _formatTz(tz),
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () {
        widget.onSelected(tz);
        Navigator.of(context).pop();
      },
    );
  }
}
