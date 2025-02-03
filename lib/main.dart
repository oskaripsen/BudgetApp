import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:syncfusion_flutter_charts/charts.dart';  // Use syncfusion_flutter_charts instead of fl_chart
import 'services/chat_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CalendarWeek(),
      routes: {
        '/dashboard': (context) => DashboardPage(),
      },
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

  @override
  void initState() {
    super.initState();
    _loadExpenses();
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

  void _clearCustomDateRange() {
    setState(() {
      _customStartDate = null;
      _customEndDate = null;
      _calendarFormat = CalendarFormat.week; // Reset to default view
    });
  }

  bool _areAllExpensesSettled() {
    if (_selectedDay == null || _notes[_selectedDay!] == null) return false;
    return _notes[_selectedDay!]!.every((note) => note['settled'] == true);
  }

  double _calculateTotalBudget() {
  DateTime startDate;
  DateTime endDate;

  if (_calendarFormat == CalendarFormat.month) {
    startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
    endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
  } else if (_calendarFormat == CalendarFormat.week) {
    startDate = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    endDate = _focusedDay.add(Duration(days: DateTime.daysPerWeek - _focusedDay.weekday));
  } else if (_customStartDate != null && _customEndDate != null) {
    startDate = _customStartDate!;
    endDate = _customEndDate!;
  } else {
    return 0;
  }

  double totalBudget = 0;
  _notes.forEach((date, notes) {
    if (date.isAfter(startDate.subtract(Duration(days: 1))) && date.isBefore(endDate.add(Duration(days: 1)))){
      totalBudget += notes.fold(0, (sum, item) => sum + (item['amount'] ?? 0));
    }
  });

  return totalBudget;
}

double _calculateDailyBudget() {
  if (_selectedDay == null || _notes[_selectedDay!] == null) return 0;
  return _notes[_selectedDay!]!.fold(0, (sum, item) => sum + (item['amount'] ?? 0));
}

  double _calculateTotalActual() {
  if (_selectedDay == null || _notes[_selectedDay!] == null) return 0;
  return _notes[_selectedDay!]!.fold(0, (sum, item) => sum + (item['actual']?.toDouble() ?? item['projected_amount']?.toDouble() ?? 0.0));
  }

  String _calculateDelta() {
  double delta = (_calculateTotalActual() - _calculateTotalBudget()).toDouble();
  return delta >= 0 ? '+\$${delta.toStringAsFixed(2)}' : '-\$${(-delta).toStringAsFixed(2)}';
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

  void _showSettleExpensesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                          'Settle Expenses',
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
                  // Expenses list
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _notes[_selectedDay]?.length ?? 0,
                      itemBuilder: (context, index) {
                        final note = _notes[_selectedDay]![index];
                        final TextEditingController actualController = TextEditingController();
                        final TextEditingController titleController = TextEditingController(text: note['title']);
                        String selectedCurrency = note['currency'];

                        return Row(
                          children: [
                            Icon(
                              note['settled'] == true
                                  ? Icons.check_circle
                                  : Icons.help_outline,
                              color: note['settled'] == true ? Colors.blue : Colors.grey,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (note['isEditing'] ?? false)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: titleController,
                                            decoration: InputDecoration(
                                              labelText: 'Title',
                                            ),
                                            onSubmitted: (value) {
                                              setModalState(() {
                                                note['title'] = value;
                                              });
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Container(
                                          width: 80,
                                          child: TextField(
                                            controller: actualController,
                                            decoration: InputDecoration(
                                              labelText: 'Actual',
                                            ),
                                            keyboardType: TextInputType.number,
                                            onSubmitted: (value) {
                                              setModalState(() {
                                                note['actual'] = double.parse(value);
                                                note['isEditing'] = false;
                                                note['settled'] = true;
                                              });
                                              setState(() {}); // Update the state immediately
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        DropdownButton<String>(
                                          value: selectedCurrency,
                                          onChanged: (String? newValue) {
                                            setModalState(() {
                                              selectedCurrency = newValue!;
                                              note['currency'] = newValue;
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
                                        SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            setModalState(() {
                                              note['actual'] = double.parse(actualController.text);
                                              note['isEditing'] = false;
                                              note['settled'] = true;
                                            });
                                            setState(() {}); // Update the state immediately
                                          },
                                          child: Text('OK'),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(note['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Projected: \$${note['amount'].toStringAsFixed(2)}', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            if (!(note['isEditing'] ?? false))
                              IconButton(
                                icon: Icon(Icons.check, color: Colors.green),
                                onPressed: () {
                                  setModalState(() {
                                    note['actual'] = note['amount'];
                                    note['settled'] = true;
                                  });
                                  setState(() {}); // Update the state immediately
                                },
                              ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.grey),
                              onPressed: () {
                                setModalState(() {
                                  note['isEditing'] = !(note['isEditing'] ?? false);
                                });
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Add other expenses
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          _notes[_selectedDay]?.add({
                            'title': 'New Expense',
                            'amount': 0.0,
                            'currency': _selectedCurrency,
                            'isEditing': true,
                          });
                        });
                      },
                      child: Text('Add other expenses'),
                    ),
                  ),
                  // Done button
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {}); // Update the state immediately
                      },
                      child: Text('Done'),
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
          IconButton(
            icon: Icon(Icons.dashboard),
            onPressed: () {
              Navigator.pushNamed(context, '/dashboard');
            },
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
                    IconButton(
                      icon: Icon(Icons.clear, size: 20, color: Colors.grey),
                      onPressed: _clearCustomDateRange,
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
            child: Text(
              'Daily spending: \$${_calculateTotalActual().toStringAsFixed(2)}'
              ' (Delta: ${_calculateDelta()})'
              '${_areAllExpensesSettled() ? " (All expenses settled)" : ""}',
              style: TextStyle(fontWeight: FontWeight.bold),
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
                    if (_selectedDay == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a date first.')),
                      );
                      return;
                    }
                    if (_titleController.text.isNotEmpty && _amountController.text.isNotEmpty) {
                      setState(() {
                        if (_notes[_selectedDay!] == null) {
                          _notes[_selectedDay!] = [];
                        }
                        _notes[_selectedDay!]!.add({
                          'title': _titleController.text,
                          'description': _descriptionController.text,
                          'amount': double.parse(_amountController.text),
                          'currency': _selectedCurrency,
                        });
                        _titleController.clear();
                        _descriptionController.clear();
                        _amountController.clear();
                      });
                    }
                  },
                  child: Text('Add Cost'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Daily budget: \$${_calculateDailyBudget().toStringAsFixed(2)}'
              '${_areAllExpensesSettled() ? " (All expenses settled)" : ""}',
              style: TextStyle(fontWeight: FontWeight.bold),
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
                          'Daily budget: \$${_calculateTotalBudget().toStringAsFixed(2)}',
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
                                  Text(' / \$${(note['actual'] ?? note['amount']).toStringAsFixed(2)}'),
                                  Text(' (Delta: \$${((note['actual'] ?? note['amount']) - note['amount']).toStringAsFixed(2)})'),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _showSettleExpensesDialog,
              child: Text('Settle Expenses'),
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

  void _addOrUpdateExpense(Map<String, dynamic> expense) async {
    try {
      if (expense['id'] == null) {
        await ChatService.saveBudgetEntry(expense);
      } else {
        await ChatService.updateBudgetEntry(expense);
      }
      _loadExpenses();
    } catch (e) {
      print('Error saving/updating expense: $e');
    }
  }

  void _deleteExpense(int id) async {
    try {
      await ChatService.deleteBudgetEntry({'id': id});
      _loadExpenses();
    } catch (e) {
      print('Error deleting expense: $e');
    }
  }

  void _loadExpenses() async {
    try {
      final expenses = await ChatService.loadBudgetEntries();
      setState(() {
        _notes = {};
        for (var expense in expenses) {
          final date = DateTime.parse(expense['date']);
          if (_notes[date] == null) {
            _notes[date] = [];
          }
          _notes[date]!.add(expense);
        }
      });
    } catch (e) {
      print('Error loading expenses: $e');
    }
  }
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<_SpendingData> _spendingData = [];
  List<_CategoryData> _categoryData = [];
  String _aiInsights = '';
  String _aiRecommendations = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load spending data and generate charts
      final expenses = await ChatService.loadBudgetEntries();
      print('Expenses loaded: $expenses');
      final spendingData = _generateSpendingData(expenses);
      final categoryData = _generateCategoryData(expenses);
      print('Spending Data: $spendingData');
      print('Category Data: $categoryData');

      // Get AI insights and recommendations
      final insights = await ChatService.getChatResponse('Provide insights into my spending patterns.', _formatNotes(expenses));
      final recommendations = await ChatService.getChatResponse('Give me personalized recommendations to increase my wealth.', _formatNotes(expenses));
      print('AI Insights: $insights');
      print('AI Recommendations: $recommendations');

      setState(() {
        _spendingData = spendingData;
        _categoryData = categoryData;
        _aiInsights = insights;
        _aiRecommendations = recommendations;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
  }

  List<_SpendingData> _generateSpendingData(List<Map<String, dynamic>> expenses) {
    // Generate spending data for charts
    return expenses.map((expense) {
      return _SpendingData(DateTime.parse(expense['date']), expense['amount']);
    }).toList();
  }

  List<_CategoryData> _generateCategoryData(List<Map<String, dynamic>> expenses) {
    // Generate category data for charts
    Map<String, double> categoryTotals = {};
    for (var expense in expenses) {
      if (categoryTotals.containsKey(expense['title'])) {
        categoryTotals[expense['title']] = categoryTotals[expense['title']]! + expense['amount'];
      } else {
        categoryTotals[expense['title']] = expense['amount'];
      }
    }
    return categoryTotals.entries.map((entry) {
      return _CategoryData(entry.key, entry.value);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _formatNotes(List<Map<String, dynamic>> expenses) {
    // Format notes for AI request
    Map<String, List<Map<String, dynamic>>> notes = {};
    for (var expense in expenses) {
      String date = expense['date'];
      if (!notes.containsKey(date)) {
        notes[date] = [];
      }
      notes[date]!.add({
        'title': expense['title'],
        'amount': expense['amount'],
        'currency': expense['currency'],
      });
    }
    return notes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF123456),
        title: Text('Dashboard', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('Spending Over Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 200,
                child: SfCartesianChart(
                  primaryXAxis: DateTimeAxis(),
                  series: <ChartSeries>[
                    LineSeries<_SpendingData, DateTime>(
                      dataSource: _spendingData,
                      xValueMapper: (_SpendingData data, _) => data.date,
                      yValueMapper: (_SpendingData data, _) => data.amount,
                    )
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('Spending by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 200,
                child: SfCircularChart(
                  series: <CircularSeries>[
                    PieSeries<_CategoryData, String>(
                      dataSource: _categoryData,
                      xValueMapper: (_CategoryData data, _) => data.category,
                      yValueMapper: (_CategoryData data, _) => data.amount,
                    )
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('AI Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_aiInsights),
              ),
              SizedBox(height: 16),
              Text('Personalized Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_aiRecommendations),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendingData {
  _SpendingData(this.date, this.amount);

  final DateTime date;
  final double amount;
}

class _CategoryData {
  _CategoryData(this.category, this.amount);

  final String category;
  final double amount;
}