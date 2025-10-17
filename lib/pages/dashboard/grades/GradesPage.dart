import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Grade {
  final String subject;
  final double grade;
  final double weight;
  final DateTime date;
  final String note;

  Grade({
    required this.subject,
    required this.grade,
    this.weight = 1.0,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'grade': grade,
        'weight': weight,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Grade.fromJson(Map<String, dynamic> json) => Grade(
        subject: json['subject'],
        grade: json['grade'].toDouble(),
        weight: json['weight']?.toDouble() ?? 1.0,
        date: DateTime.parse(json['date']),
        note: json['note'] ?? '',
      );
}

class GradesPage extends StatefulWidget {
  @override
  _GradesPageState createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  List<Grade> _grades = [];
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _gradeController = TextEditingController();
  final _weightController = TextEditingController(text: '1.0');
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedSubject = '';
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final gradesJson = prefs.getStringList('grades') ?? [];
    final subjects = prefs.getStringList('subjects') ?? [];
    
    setState(() {
      _grades = gradesJson.map<Grade>((json) => Grade.fromJson(Map<String, dynamic>.from(jsonDecode(json)))).toList();
      _subjects = subjects;
    });
  }

  Future<void> _saveGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final gradesJson = _grades.map<String>((grade) => jsonEncode(grade.toJson())).toList();
    await prefs.setStringList('grades', gradesJson);
    await prefs.setStringList('subjects', _subjects);
  }

  Future<void> _addGrade() async {
    if (_formKey.currentState?.validate() ?? false) {
      final grade = Grade(
        subject: _selectedSubject.isEmpty ? _subjectController.text : _selectedSubject,
        grade: double.parse(_gradeController.text.replaceAll(',', '.')),
        weight: double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 1.0,
        date: _selectedDate,
        note: _noteController.text,
      );

      setState(() {
        _grades.add(grade);
        if (!_subjects.contains(grade.subject)) {
          _subjects.add(grade.subject);
        }
      });

      await _saveGrades();
      _resetForm();
      Navigator.of(context).pop();
    }
  }

  void _resetForm() {
    _subjectController.clear();
    _gradeController.clear();
    _weightController.text = '1.0';
    _noteController.clear();
    _selectedDate = DateTime.now();
    _selectedSubject = '';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAddGradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Grade'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_subjects.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedSubject.isEmpty ? null : _selectedSubject,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: _subjects
                        .map((subject) => DropdownMenuItem(
                              value: subject,
                              child: Text(subject),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubject = value ?? '';
                      });
                    },
                    validator: (value) {
                      if ((value == null || value.isEmpty) && _subjectController.text.isEmpty) {
                        return 'Please select or enter a subject';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Text('OR', textAlign: TextAlign.center),
                  SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: 'New Subject',
                    border: OutlineInputBorder(),
                  ),
                  enabled: _selectedSubject.isEmpty,
                  validator: (value) {
                    if ((value == null || value.isEmpty) && _selectedSubject.isEmpty) {
                      return 'Please enter a subject';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _gradeController,
                  decoration: InputDecoration(
                    labelText: 'Grade',
                    border: OutlineInputBorder(),
                    suffixText: '1.0-6.0',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a grade';
                    }
                    final grade = double.tryParse(value.replaceAll(',', '.'));
                    if (grade == null || grade < 1.0 || grade > 6.0) {
                      return 'Please enter a valid grade (1.0-6.0)';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  decoration: InputDecoration(
                    labelText: 'Weight',
                    border: OutlineInputBorder(),
                    hintText: '1.0',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final weight = double.tryParse(value.replaceAll(',', '.'));
                    if (weight == null || weight <= 0) {
                      return 'Please enter a valid weight';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                        ),
                        Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: _addGrade,
            child: Text('ADD'),
          ),
        ],
      ),
    );
  }

  double _calculateAverage(String subject) {
    final subjectGrades = _grades.where((g) => g.subject == subject).toList();
    if (subjectGrades.isEmpty) return 0.0;
    
    double sum = 0;
    double totalWeight = 0;
    
    for (var grade in subjectGrades) {
      sum += grade.grade * grade.weight;
      totalWeight += grade.weight;
    }
    
    return totalWeight > 0 ? (sum / totalWeight) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _grades.map((g) => g.subject).toSet().toList()..sort();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('My Grades'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddGradeDialog,
          ),
        ],
      ),
      body: _grades.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grade_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No grades yet',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to add your first grade',
                    style: Theme.of(context).textTheme.bodyText2,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final subjectGrades = _grades.where((g) => g.subject == subject).toList();
                final average = _calculateAverage(subject);
                
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    title: Text(
                      subject,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Average: ${average.toStringAsFixed(2)}'),
                    children: [
                      ...subjectGrades.map((grade) => ListTile(
                            title: Text('Grade: ${grade.grade} (Weight: ${grade.weight})'),
                            subtitle: Text(
                                '${grade.date.day}.${grade.date.month}.${grade.date.year}${grade.note.isNotEmpty ? ' • ${grade.note}' : ''}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                setState(() {
                                  _grades.remove(grade);
                                  // Remove subject if no more grades
                                  if (!_grades.any((g) => g.subject == subject)) {
                                    _subjects.remove(subject);
                                  }
                                });
                                await _saveGrades();
                              },
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGradeDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}
