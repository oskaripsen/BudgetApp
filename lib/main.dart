import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'services/chat_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CalendarWeek(),
    );
  }
}

class CalendarWeek extends StatefulWidget {
  @override
  _CalendarWeekState createState() => _CalendarWeekState();
}

class _CalendarWeekState extends State<CalendarWeek> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _notes = {};
  TextEditingController _noteController = TextEditingController();
  TextEditingController _titleController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _amountController = TextEditingController();
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _selectedCurrency = 'USD'; // Add this line
  final List<Map<String, String>> _chatMessages = []; // Add this line
  final TextEditingController _chatController = TextEditingController(); // Add this line
  bool _isLoadingResponse = false;
  final ScrollController _scrollController = ScrollController();
  String _currentAlias = 'default';  // Add this line

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _chatMessages.add({
      'text': 'Welcome! I\'m your AI budget assistant. You can ask me questions about your spending patterns, get budgeting advice, or request spending summaries. For example:\n\n• How much did I spend this week?\n• What\'s my biggest expense category?\n• Can you analyze my spending habits?\n• Show me my daily averages.',
      'sender': 'ai',
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _chatController.dispose(); // Add this line
    super.dispose();
  }

  void _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime(2030),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );
    if (picked != null && picked.start != null && picked.end != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _calendarFormat = CalendarFormat.month; // Reset to month view for custom range
      });
    }
  }

  double _calculateTotalBudget() {
    double total = 0;
    DateTime startDate = _customStartDate ?? _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    DateTime endDate = _customEndDate ?? _focusedDay.add(Duration(days: DateTime.daysPerWeek - _focusedDay.weekday));
    
    _notes.forEach((date, notes) {
      if (date.isAfter(startDate.subtract(Duration(days: 1))) && date.isBefore(endDate.add(Duration(days: 1)))) {
        total += notes.fold(0, (sum, item) => sum + item['amount']);
      }
    });
    return total;
  }

  Future<void> _sendMessage(String message, [StateSetter? setModalState]) async {
    if (message.isEmpty) return;

    setState(() {
      _chatMessages.add({
        'text': message,
        'sender': 'user',
      });
      _isLoadingResponse = true;
      _chatController.clear();
    });
    if (setModalState != null) {
      setModalState(() {});
    }

    // Use the new ChatService instead of OpenAIService
    final response = await ChatService.getChatResponse(message, _notes);

    setState(() {
      _chatMessages.add({
        'text': response,
        'sender': 'ai',
      });
      _isLoadingResponse = false;
    });
    if (setModalState != null) {
      setModalState(() {});
    }
  }

  void _showChatDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF123456),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'AI Budget Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Chat messages
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final message = _chatMessages[index];
                        return Align(
                          alignment: message['sender'] == 'user' 
                              ? Alignment.centerRight 
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            padding: EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: message['sender'] == 'user' 
                                  ? Color(0xFF123456) 
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              message['text']!,
                              style: TextStyle(
                                color: message['sender'] == 'user' 
                                    ? Colors.white 
                                    : Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isLoadingResponse)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF123456)),
                        ),
                      ),
                    ),
                  // Input field
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: 'Ask about your spending...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onSubmitted: (text) {
                              if (!_isLoadingResponse && text.isNotEmpty) {
                                _sendMessage(text, setModalState);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: _isLoadingResponse 
                            ? null 
                            : () => _sendMessage(_chatController.text, setModalState),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD), // Light blue background
      appBar: AppBar(
        backgroundColor: Color(0xFF123456), // Main blue color
        title: Text(
          'Budget Tracker',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: _currentAlias,
              style: TextStyle(color: Colors.white),
              dropdownColor: Color(0xFF123456),
              onChanged: (String? newValue) async {
                if (newValue != null) {
                  setState(() {
                    _currentAlias = newValue;
                    _notes.clear();
                  });
                  final entries = await ChatService.loadBudgetEntries(_currentAlias);
                  setState(() {
                    for (var entry in entries) {
                      final date = DateTime.parse(entry['date']);
                      if (_notes[date] == null) {
                        _notes[date] = [];
                      }
                      _notes[date]!.add(entry);
                    }
                  });
                }
              },
              items: ['default', 'family', 'personal', 'business']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: TextStyle(color: Colors.white)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Total budget for the period: \$${_calculateTotalBudget().toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: false,
              rightChevronVisible: true,
              headerPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              headerMargin: const EdgeInsets.only(bottom: 8.0),
              titleTextFormatter: (date, locale) {
                return '${_getMonthName(date.month)} ${date.year}';
              },
              rightChevronMargin: const EdgeInsets.only(right: 70),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Color(0xFF123456),
                shape: BoxShape.circle,
              ),
            ),
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _noteController.text = _notes[_selectedDay]?.map((note) => note['title']).join(', ') ?? '';
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            rangeStartDay: _customStartDate,
            rangeEndDay: _customEndDate,
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (context, day) {
                return Row(
                  children: [
                    Text(
                      '${_getMonthName(day.month)} ${day.year}',
                      style: TextStyle(fontSize: 17.0),
                    ),
                    Spacer(),
                    DropdownButton<String>(
                      value: _calendarFormat == CalendarFormat.month ? 'Month' : 'Week',
                      onChanged: (String? newValue) {
                        setState(() {
                          if (newValue == 'Custom') {
                            _selectCustomDateRange(context);
                          } else {
                            _calendarFormat = newValue == 'Month' ? CalendarFormat.month : CalendarFormat.week;
                          }
                        });
                      },
                      items: ['Month', 'Week', 'Custom'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                if (_notes.containsKey(day)) {
                  return Stack(
                    children: [
                      Center(child: Text('${day.day}')),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Icon(Icons.note, size: 16, color: Color(0xFF123456)),
                      ),
                    ],
                  );
                } else {
                  return Center(child: Text('${day.day}'));
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Title',
                  ),
                  controller: _titleController,
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  controller: _descriptionController,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Expected Cost',
                        ),
                        keyboardType: TextInputType.number,
                        controller: _amountController,
                      ),
                    ),
                    SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _selectedCurrency,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCurrency = newValue!;
                        });
                      },
                      items: <String>['CHF', 'USD', 'DKK']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedDay != null && _titleController.text.isNotEmpty && _amountController.text.isNotEmpty) {
                      setState(() {
                        if (_notes[_selectedDay!] == null) {
                          _notes[_selectedDay!] = [];
                        }
                        _notes[_selectedDay!]!.add({
                          'title': _titleController.text,
                          'description': _descriptionController.text,
                          'amount': double.parse(_amountController.text),
                          'currency': _selectedCurrency, // Add this line
                        });
                        _titleController.clear();
                        _descriptionController.clear();
                        _amountController.clear();
                      });
                    }
                  },
                  child: Text('Add Cost'),  // Changed from 'Add Expense' to 'Add Cost'
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedDay == null || _notes[_selectedDay!] == null
                ? Center(child: Text('No expenses for the selected day'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Daily budget: \$${_notes[_selectedDay!]!.fold<double>(0, (sum, item) => sum + item['amount']).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _notes[_selectedDay!]!.length,
                          itemBuilder: (context, index) {
                            var note = _notes[_selectedDay!]![index];
                            return ListTile(
                              title: Text(
                                note['title'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(note['description']),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('\$${note['amount'].toStringAsFixed(2)}'),
                                  IconButton(
                                    icon: Icon(Icons.close, color: Color(0xFF123456)),
                                    onPressed: () {
                                      setState(() {
                                        _notes[_selectedDay!]!.remove(note);
                                        if (_notes[_selectedDay!]!.isEmpty) {
                                          _notes.remove(_selectedDay!);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showChatDialog,
        backgroundColor: Color(0xFF123456),
        child: Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  String _getMonthName(int month) {
    return [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ][month - 1];
  }
}