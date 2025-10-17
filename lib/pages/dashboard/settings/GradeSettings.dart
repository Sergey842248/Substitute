import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GradeSettings extends StatefulWidget {
  @override
  _GradeSettingsState createState() => _GradeSettingsState();
}

class _GradeSettingsState extends State<GradeSettings> {
  late bool _usePointsSystem;
  final _maxPointsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usePointsSystem = prefs.getBool('use_points_system') ?? false;
      _maxPointsController.text = prefs.getString('max_points') ?? '100';
    });
  }

  Future<void> _saveSettings({bool showSnackBar = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_points_system', _usePointsSystem);
    await prefs.setString('max_points', _maxPointsController.text);
    
    if (mounted && showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Einstellungen gespeichert')),
      );
    }
  }

  Future<void> _confirmSystemChange(bool newValue) async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('System wechseln'),
        content: Text('Achtung: Beim Wechsel des Bewertungssystems werden alle bestehenden Einträge gelöscht. Möchtest du fortfahren?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Fortfahren', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      // Clear all grades and subjects
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('grades');
      await prefs.remove('subjects');
      
      // Update the UI and save settings
      if (mounted) {
        setState(() {
          _usePointsSystem = newValue;
        });
        await _saveSettings(showSnackBar: false);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bewertungssystem wurde umgestellt. Bitte füge neue Einträge hinzu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grade Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                _saveSettings();
              }
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            SwitchListTile(
              title: Text('Punktesystem verwenden'),
              subtitle: Text('Zwischen Noten- und Punktesystem wechseln'),
              value: _usePointsSystem,
              onChanged: (value) async {
                if (value != _usePointsSystem) {
                  await _confirmSystemChange(value);
                }
              },
            ),
            if (_usePointsSystem) ...[              
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxPointsController,
                decoration: InputDecoration(
                  labelText: 'Maximum Points',
                  border: OutlineInputBorder(),
                  helperText: 'Enter maximum achievable points',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter maximum points';
                  }
                  final points = double.tryParse(value);
                  if (points == null || points <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _maxPointsController.dispose();
    super.dispose();
  }
}
