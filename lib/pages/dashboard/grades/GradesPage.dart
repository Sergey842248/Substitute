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
  late final TextEditingController _subjectController;
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
  Map<String, bool> _expandedSubjects = {};

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
    _subjectController = TextEditingController();
    _loadSettings();
    _loadGrades();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _weightController.dispose();
    _noteController.dispose();
    _gradeController.dispose();
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
      // Initialize expanded state for all subjects - collapsed by default
      _expandedSubjects = { for (var subject in _subjects) subject: false };
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

  void _showAddGradeDialog({
    String? subject,
    required void Function(Grade grade) onGradeAdded,
  }) {
    // Use a local variable for the selected subject
    String? selectedSubject = subject;
    // Create a new controller for the dialog
    final subjectController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final weightController = TextEditingController(text: '1.0');
    final noteController = TextEditingController();
    var selectedDate = DateTime.now();
    String? selectedGrade;

    // Set up the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Note hinzufügen'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_subjects.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: selectedSubject,
                          decoration: InputDecoration(
                            labelText: 'Fach auswählen',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Neues Fach eingeben', style: TextStyle(color: Colors.grey)),
                            ),
                            ..._subjects.map((subj) => DropdownMenuItem(
                                  value: subj,
                                  child: Text(subj),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedSubject = value;
                              if (value != null) {
                                subjectController.clear();
                              }
                            });
                          },
                          validator: (value) {
                            if ((value == null || value.isEmpty) &&
                                (subjectController.text.trim().isEmpty)) {
                              return 'Bitte wähle ein Fach aus oder gib ein neues ein';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        if (selectedSubject == null) ...[
                          TextFormField(
                            controller: subjectController,
                            decoration: InputDecoration(
                              labelText: 'Neues Fach',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if ((value == null || value.trim().isEmpty) &&
                                  (selectedSubject == null || selectedSubject!.isEmpty)) {
                                return 'Bitte gib einen gültigen Fachnamen ein';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                        ],
                      ] else ...[
                        TextFormField(
                          controller: subjectController,
                          decoration: InputDecoration(
                            labelText: 'Fachname',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Bitte gib einen gültigen Fachnamen ein';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                      ],

                      // Grade Input
                      DropdownButtonFormField<String>(
                        value: selectedGrade,
                        decoration: InputDecoration(
                          labelText: 'Note',
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
                            selectedGrade = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte wähle eine Note aus';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Weight Input
                      TextFormField(
                        controller: weightController,
                        decoration: InputDecoration(
                          labelText: 'Gewichtung',
                          border: OutlineInputBorder(),
                          hintText: '1.0',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final weight = double.tryParse(value.replaceAll(',', '.'));
                          if (weight == null || weight <= 0) {
                            return 'Bitte eine gültige Gewichtung eingeben';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Date Picker
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Datum',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                              ),
                              Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Note Input
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Notiz (optional)',
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('ABBRECHEN'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final subjectName = selectedSubject ?? subjectController.text.trim();
                      if (subjectName.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bitte ein gültiges Fach eingeben')),
                          );
                        }
                        return;
                      }

                      if (selectedGrade == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bitte eine Note auswählen')),
                          );
                        }
                        return;
                      }

                      try {
                        final grade = Grade(
                          subject: subjectName,
                          grade: _parseGermanGrade(selectedGrade!),
                          weight: double.tryParse(weightController.text.replaceAll(',', '.')) ?? 1.0,
                          date: selectedDate,
                          note: noteController.text,
                        );

                        onGradeAdded(grade);

                        await _saveGrades();

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Note wurde hinzugefügt'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Fehler beim Speichern: $e'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('HINZUFÜGEN'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // The dialog has been closed, dispose controllers
      subjectController.dispose();
      weightController.dispose();
      noteController.dispose();
    });
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
    _subjects.sort();
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
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: colorScheme.primary, size: 22),
              ),
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'add_grade',
                  child: Text('Note hinzufügen'),
                ),
                PopupMenuItem(
                  value: 'add_subject',
                  child: Text('Fach erstellen'),
                ),
              ],
              onSelected: (value) {
                if (value == 'add_grade') {
                  _showAddGradeDialog(
                    onGradeAdded: (grade) {
                      setState(() {
                        _grades.add(grade);
                        if (!_subjects.contains(grade.subject)) {
                          _subjects.add(grade.subject);
                          _subjects.sort();
                          // Expand the subject immediately when a grade is added
                          _expandedSubjects[grade.subject] = true;
                        }
                      });
                    },
                  );
                } else if (value == 'add_subject') {
                  _showAddSubjectDialog();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _subjects.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grade_outlined, size: 64, color: colorScheme.primary.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Fächer vorhanden',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Füge dein erstes Fach hinzu, um Noten zu verwalten',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddSubjectDialog,
                        icon: Icon(Icons.add, size: 20),
                        label: Text('Fach erstellen'),
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
                          final subject = _subjects[index];
                          final subjectGrades = _grades.where((g) => g.subject == subject).toList();
                          final average = subjectGrades.isNotEmpty ? _calculateAverage(subject) : 0.0;
                          
          return _buildSubjectCard(
            context,
            subject: subject,
            average: average,
            grades: subjectGrades,
            colorScheme: colorScheme,
            onEditGrade: _showEditGradeDialog,
            onEditSubject: _showEditSubjectDialog,
          );
                        },
                        childCount: _subjects.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showAddSubjectDialog() async {
    final subjectController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Neues Fach erstellen'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: subjectController,
            decoration: InputDecoration(
              labelText: 'Fachname',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bitte gib einen Fachnamen ein';
              }
              if (_subjects.contains(value.trim())) {
                return 'Dieses Fach existiert bereits';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final subject = subjectController.text.trim();
                setState(() {
                  _subjects.add(subject);
                  _subjects.sort();
                  _expandedSubjects[subject] = true;
                });
                _saveGrades();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fach "$subject" wurde erstellt')),
                );
              }
            },
            child: Text('Erstellen'),
          ),
        ],
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
    required Function(String) onEditSubject,
    required Function(Grade) onEditGrade,
  }) {
    final isExpanded = _expandedSubjects[subject] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedSubjects[subject] = !isExpanded;
          });
        },
        onLongPress: () => _showSubjectOptionsDialog(subject),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subject,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (grades.isNotEmpty && isExpanded) _buildAverageChip(average, colorScheme),
                ],
              ),
              const SizedBox(height: 16),
              if (isExpanded) ...[
                if (grades.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                        Text(
                          'Keine Noten vorhanden',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showAddGradeDialog(
                              subject: subject,
                              onGradeAdded: (grade) {
                                setState(() {
                                  _grades.add(grade);
                                  if (!_subjects.contains(grade.subject)) {
                                    _subjects.add(grade.subject);
                                    _subjects.sort();
                                    // Expand the subject immediately when a grade is added
                                    _expandedSubjects[grade.subject] = true;
                                  }
                                });
                              },
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Note hinzufügen'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...grades.map((grade) => GestureDetector(
                    onLongPress: () => _showGradeOptionsDialog(grade),
                    child: _buildGradeTile(grade, colorScheme),
                  )),
              ],
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
      setState(() {
        _grades.remove(grade);
      });
      await _saveGrades();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Note wurde gelöscht')),
        );
      }
    }
  }

  void _showEditGradeDialog(Grade gradeToEdit) {
    // Initialize form fields with existing grade data
    final subjectController = TextEditingController(text: gradeToEdit.subject);
    final weightController = TextEditingController(text: gradeToEdit.weight.toString());
    final noteController = TextEditingController(text: gradeToEdit.note);
    var selectedDate = gradeToEdit.date;
    String? selectedGrade = _formatGermanGrade(gradeToEdit.grade);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Note bearbeiten'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedGrade,
                        decoration: InputDecoration(
                          labelText: 'Note',
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
                            selectedGrade = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte wähle eine Note aus';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Weight Input
                      TextFormField(
                        controller: weightController,
                        decoration: InputDecoration(
                          labelText: 'Gewichtung',
                          border: OutlineInputBorder(),
                          hintText: '1.0',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final weight = double.tryParse(value.replaceAll(',', '.'));
                          if (weight == null || weight <= 0) {
                            return 'Bitte eine gültige Gewichtung eingeben';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Date Picker
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Datum',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                              ),
                              Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Note Input
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Notiz (optional)',
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('ABBRECHEN'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      if (selectedGrade == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bitte eine Note auswählen')),
                          );
                        }
                        return;
                      }

                      try {
                        final editedGrade = Grade(
                          subject: gradeToEdit.subject,
                          grade: _parseGermanGrade(selectedGrade!),
                          weight: double.tryParse(weightController.text.replaceAll(',', '.')) ?? gradeToEdit.weight,
                          date: selectedDate,
                          note: noteController.text,
                        );

                        // Update the grade in the list
                        final index = _grades.indexOf(gradeToEdit);
                        if (index != -1) {
                          setState(() {
                            _grades[index] = editedGrade;
                          });
                          await _saveGrades();
                        }

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Note wurde aktualisiert'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Fehler beim Speichern: $e'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('SPEICHERN'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Dispose controllers after dialog closes
      subjectController.dispose();
      weightController.dispose();
      noteController.dispose();
    });
  }

  void _showSubjectOptionsDialog(String subject) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Fach bearbeiten'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditSubjectDialog(subject);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Fach löschen', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteSubject(subject);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGradeOptionsDialog(Grade grade) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Note bearbeiten'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditGradeDialog(grade);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Note löschen', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteGrade(grade);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditSubjectDialog(String subjectToEdit) {
    final subjectController = TextEditingController(text: subjectToEdit);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fach bearbeiten'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: subjectController,
            decoration: InputDecoration(
              labelText: 'Fachname',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bitte gib einen Fachnamen ein';
              }
              if (value.trim() != subjectToEdit && _subjects.contains(value.trim())) {
                return 'Dieses Fach existiert bereits';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final newSubjectName = subjectController.text.trim();
                if (newSubjectName != subjectToEdit) {
                  setState(() {
                    // Update all grades with the old subject name
                    for (var i = 0; i < _grades.length; i++) {
                      if (_grades[i].subject == subjectToEdit) {
                        _grades[i] = Grade(
                          subject: newSubjectName,
                          grade: _grades[i].grade,
                          weight: _grades[i].weight,
                          date: _grades[i].date,
                          note: _grades[i].note,
                        );
                      }
                    }
                    // Update the subject list
                    final subjectIndex = _subjects.indexOf(subjectToEdit);
                    if (subjectIndex != -1) {
                      _subjects[subjectIndex] = newSubjectName;
                      _subjects.sort();
                    }
                    // Update the expanded subjects map
                    _expandedSubjects[newSubjectName] = _expandedSubjects[subjectToEdit] ?? false;
                    _expandedSubjects.remove(subjectToEdit);
                  });
                  _saveGrades();
                }
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fach "$newSubjectName" wurde aktualisiert')),
                );
              }
            },
            child: Text('Speichern'),
          ),
        ],
      ),
    ).then((_) {
      // Dispose controller after dialog closes
      subjectController.dispose();
    });
  }
}
