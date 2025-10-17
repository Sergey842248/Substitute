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
  final _weightController = TextEditingController(text: '1.0');
  final _noteController = TextEditingController();
  final List<String> _germanGrades = [
    '1+', '1', '1-',
    '2+', '2', '2-',
    '3+', '3', '3-',
    '4+', '4', '4-',
    '5+', '5', '5-',
    '6'
  ];
  String? _selectedGrade;
  DateTime _selectedDate = DateTime.now();
  String _selectedSubject = '';
  List<String> _subjects = [];

  double _parseGermanGrade(String grade) {
    switch (grade) {
      case '1+': return 0.7;
      case '1': return 1.0;
      case '1-': return 1.3;
      case '2+': return 1.7;
      case '2': return 2.0;
      case '2-': return 2.3;
      case '3+': return 2.7;
      case '3': return 3.0;
      case '3-': return 3.3;
      case '4+': return 3.7;
      case '4': return 4.0;
      case '4-': return 4.3;
      case '5+': return 4.7;
      case '5': return 5.0;
      case '5-': return 5.3;
      case '6': return 6.0;
      default: return 1.0;
    }
  }

  String _formatGermanGrade(double grade) {
    if (grade <= 0.85) return '1+';
    if (grade <= 1.15) return '1';
    if (grade <= 1.5) return '1-';
    if (grade <= 1.85) return '2+';
    if (grade <= 2.15) return '2';
    if (grade <= 2.5) return '2-';
    if (grade <= 2.85) return '3+';
    if (grade <= 3.15) return '3';
    if (grade <= 3.5) return '3-';
    if (grade <= 3.85) return '4+';
    if (grade <= 4.15) return '4';
    if (grade <= 4.5) return '4-';
    if (grade <= 4.85) return '5+';
    if (grade <= 5.15) return '5';
    if (grade <= 5.5) return '5-';
    return '6';
  }

  bool _usePointsSystem = false;
  double _maxPoints = 100.0;
  final TextEditingController _gradeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadGrades();
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _subjectController.dispose();
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usePointsSystem = prefs.getBool('use_points_system') ?? false;
      _maxPoints = double.tryParse(prefs.getString('max_points') ?? '100') ?? 100.0;
    });
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
    if ((_formKey.currentState?.validate() ?? false) && 
        (_selectedGrade != null || _gradeController.text.isNotEmpty)) {
      
      final grade = Grade(
        subject: _selectedSubject.isEmpty ? _subjectController.text : _selectedSubject,
        grade: _usePointsSystem 
            ? double.parse(_gradeController.text.replaceAll(',', '.')) 
            : _parseGermanGrade(_selectedGrade!),
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
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _resetForm() {
    _subjectController.clear();
    _selectedGrade = null;
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

  Widget _buildGradeInput() {
    if (_usePointsSystem) {
      return TextFormField(
        controller: _gradeController,
        decoration: InputDecoration(
          labelText: 'Points',
          border: OutlineInputBorder(),
          suffixText: 'max $_maxPoints',
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter points';
          }
          final points = double.tryParse(value.replaceAll(',', '.'));
          if (points == null || points < 0 || points > _maxPoints) {
            return 'Please enter points between 0 and $_maxPoints';
          }
          return null;
        },
      );
    } else {
      return DropdownButtonFormField<String>(
        value: _selectedGrade,
        decoration: InputDecoration(
          labelText: 'Grade',
          border: OutlineInputBorder(),
        ),
        items: _germanGrades.map((grade) {
          return DropdownMenuItem(
            value: grade,
            child: Text(grade),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedGrade = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a grade';
          }
          return null;
        },
      );
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
                  Text('OR', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
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
                _buildGradeInput(),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Theme(
      data: theme.copyWith(
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Notenübersicht', style: TextStyle(fontWeight: FontWeight.w600)),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: theme.textTheme.titleLarge?.color,
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: colorScheme.primary, size: 22),
              ),
              onPressed: _showAddGradeDialog,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _grades.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grade_outlined, size: 64, color: colorScheme.primary.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine Noten',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Füge deine erste Note hinzu, um den Überblick zu behalten',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddGradeDialog,
                        icon: Icon(Icons.add, size: 20),
                        label: Text('Note hinzufügen'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final subject = subjects[index];
                          final subjectGrades = _grades.where((g) => g.subject == subject).toList();
                          final average = _calculateAverage(subject);
                          
                          return _buildSubjectCard(
                            context,
                            subject: subject,
                            average: average,
                            grades: subjectGrades,
                            colorScheme: colorScheme,
                          );
                        },
                        childCount: subjects.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDeleteSubject(String subject) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fach löschen'),
        content: Text('Möchtest du wirklich alle Noten für "$subject" löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() {
        _grades.removeWhere((g) => g.subject == subject);
        _subjects.remove(subject);
      });
      await _saveGrades();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alle Noten für $subject wurden gelöscht')),
        );
      }
    }
  }

  Widget _buildSubjectCard(
    BuildContext context, {
    required String subject,
    required double average,
    required List<Grade> grades,
    required ColorScheme colorScheme,
  }) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onLongPress: () => _confirmDeleteSubject(subject),
      child: Card(
        child: Theme(
          data: theme.copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildAverageChip(average, colorScheme),
              ],
            ),
            children: [
              Divider(height: 1, indent: 16, endIndent: 16),
              ...grades.map((grade) => _buildGradeTile(grade, colorScheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeTile(Grade grade, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final displayGrade = _usePointsSystem 
        ? '${grade.grade.toStringAsFixed(1)}/${_maxPoints.toStringAsFixed(0)}'
        : _formatGermanGrade(grade.grade);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _getGradeColor(grade.grade, colorScheme).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          displayGrade,
          style: theme.textTheme.titleMedium?.copyWith(
            color: _getGradeColor(grade.grade, colorScheme),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        'Weight: ${grade.weight}x',
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${_formatDate(grade.date)}${grade.note.isNotEmpty ? ' • ${grade.note}' : ''}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        onPressed: () => _confirmDeleteGrade(grade),
      ),
    );
  }

  Color _getGradeColor(double grade, ColorScheme colorScheme) {
    if (_usePointsSystem) {
      // For points system, higher is better
      final percentage = (grade / _maxPoints) * 100;
      if (percentage >= 80) return Colors.green; // 80-100% = green
      if (percentage >= 50) return Colors.orange; // 50-79% = orange
      return colorScheme.error; // 0-49% = red
    } else {
      // Standard grade system - lower is better
      if (grade <= 2.0) return Colors.green;
      if (grade <= 3.0) return Colors.orange;
      return colorScheme.error;
    }
  }

  Widget _buildAverageChip(double average, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Ø ${average.toStringAsFixed(2)}',
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _confirmDeleteGrade(Grade grade) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note löschen'),
        content: Text('Möchtest du diese Note wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final subject = grade.subject;
      setState(() {
        _grades.remove(grade);
        if (!_grades.any((g) => g.subject == subject)) {
          _subjects.remove(subject);
        }
      });
      await _saveGrades();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Note wurde gelöscht')),
        );
      }
    }
  }
}
