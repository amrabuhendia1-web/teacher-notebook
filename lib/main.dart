import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

// --- الألوان والمظهر (المستمدة من CSS) ---
class AppColors {
  static const primary = Color(0xFF2563EB);
  static const secondary = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const bgLight = Color(0xFFF0F2F5);
  static const cardLight = Colors.white;
  static const textMainLight = Color(0xFF1E293B);
  static const textSubLight = Color(0xFF64748B);

  // Dark Mode
  static const bgDark = Color(0xFF121212);
  static const cardDark = Color(0xFF1E1E1E);
  static const primaryDark = Color(0xFFBB86FC);
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..loadData(),
      child: const TeacherApp(),
    ),
  );
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'دفتر المدرس',
      debugShowCheckedModeBanner: false,
      themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bgLight,
        primaryColor: AppColors.primary,
        fontFamily: 'Cairo', // تأكد من إضافة الخط في pubspec
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDark,
        primaryColor: AppColors.primaryDark,
        fontFamily: 'Cairo',
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const MainNavigator(),
    );
  }
}

// --- النماذج (Models) ---
class Group {
  String id;
  String name;
  double price;
  int system; // 1 or 2
  List<SessionSchedule> sessions;
  List<Student> students;
  int currentSession;
  int currentMonth;
  List<AttendanceRecord> attendanceHistory;
  int reminderMinutes;

  Group({
    required this.id,
    required this.name,
    required this.price,
    required this.system,
    required this.sessions,
    required this.students,
    this.currentSession = 1,
    this.currentMonth = 1,
    this.attendanceHistory = const [],
    this.reminderMinutes = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'price': price, 'system': system,
    'sessions': sessions.map((e) => e.toJson()).toList(),
    'students': students.map((e) => e.toJson()).toList(),
    'currentSession': currentSession, 'currentMonth': currentMonth,
    'attendanceHistory': attendanceHistory.map((e) => e.toJson()).toList(),
    'reminderMinutes': reminderMinutes,
  };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'], name: json['name'], price: json['price'].toDouble(), system: json['system'],
    sessions: (json['sessions'] as List).map((e) => SessionSchedule.fromJson(e)).toList(),
    students: (json['students'] as List).map((e) => Student.fromJson(e)).toList(),
    currentSession: json['currentSession'], currentMonth: json['currentMonth'],
    attendanceHistory: (json['attendanceHistory'] as List).map((e) => AttendanceRecord.fromJson(e)).toList(),
    reminderMinutes: json['reminderMinutes'] ?? 0,
  );
}

class SessionSchedule {
  String day;
  String time;
  SessionSchedule({required this.day, required this.time});
  Map<String, dynamic> toJson() => {'day': day, 'time': time};
  factory SessionSchedule.fromJson(Map<String, dynamic> json) => SessionSchedule(day: json['day'], time: json['time']);
}

class Student {
  String id;
  String name;
  List<int> paidMonths;
  List<Note> notes;
  Student({required this.id, required this.name, this.paidMonths = const [], this.notes = const []});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'paidMonths': paidMonths, 'notes': notes.map((e) => e.toJson()).toList()};
  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'], name: json['name'], paidMonths: List<int>.from(json['paidMonths']),
    notes: (json['notes'] as List).map((e) => Note.fromJson(e)).toList(),
  );
}

class Note {
  String text;
  String date;
  int month;
  int session;
  bool notified;
  Note({required this.text, required this.date, required this.month, required this.session, this.notified = false});
  Map<String, dynamic> toJson() => {'text': text, 'date': date, 'month': month, 'session': session, 'notified': notified};
  factory Note.fromJson(Map<String, dynamic> json) => Note(
    text: json['text'], date: json['date'], month: json['month'], session: json['session'], notified: json['notified'] ?? false,
  );
}

class AttendanceRecord {
  int month;
  int session;
  String date;
  Map<String, String> studentStatus; // studentId : status
  AttendanceRecord({required this.month, required this.session, required this.date, required this.studentStatus});
  Map<String, dynamic> toJson() => {'month': month, 'session': session, 'date': date, 'studentStatus': studentStatus};
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
    month: json['month'], session: json['session'], date: json['date'],
    studentStatus: Map<String, String>.from(json['studentStatus']),
  );
}

// --- إدارة الحالة (AppState) ---
class AppState extends ChangeNotifier {
  List<Group> groups = [];
  bool isDarkMode = false;
  String currentScreen = 'dashboard';
  Group? activeGroup;
  Student? activeStudent;

  void setScreen(String screen, {Group? group, Student? student}) {
    currentScreen = screen;
    if (group != null) activeGroup = group;
    if (student != null) activeStudent = student;
    notifyListeners();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('teacherAppData');
    isDarkMode = prefs.getBool('isDarkMode') ?? false;
    if (data != null) {
      final List decoded = jsonDecode(data)['groups'];
      groups = decoded.map((e) => Group.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('teacherAppData', jsonEncode({'groups': groups.map((e) => e.toJson()).toList()}));
    prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    saveData();
  }

  void addGroup(Group group) {
    groups.add(group);
    saveData();
  }

  void deleteGroup(String id) {
    groups.removeWhere((g) => g.id == id);
    saveData();
  }

  void deleteAll() {
    groups = [];
    saveData();
  }
}

// --- الملاح الرئيسي (Main Navigator) ---
class MainNavigator extends StatelessWidget {
  const MainNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    switch (state.currentScreen) {
      case 'dashboard': return const DashboardScreen();
      case 'attendance': return const AttendanceScreen();
      case 'add_group': return const AddGroupScreen();
      case 'edit_group': return const EditGroupScreen();
      case 'notes': return const NotesScreen();
      case 'finance_main': return const FinanceMainScreen();
      case 'finance_group': return const FinanceGroupScreen();
      case 'settings': return const SettingsScreen();
      default: return const DashboardScreen();
    }
  }
}

// --- 1. شاشة لوحة التحكم (Dashboard) ---
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final daysArabic = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final todayName = daysArabic[now.weekday % 7];
    final todayDate = intl.DateFormat.yMMMMEEEEd('ar').format(now);

    final todayGroups = state.groups.where((g) => g.sessions.any((s) => s.day == todayName)).toList();
    final otherGroups = state.groups.where((g) => !g.sessions.any((s) => s.day == todayName)).toList();

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('دفتر المدرس ✎', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(todayDate, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                _buildSectionTitle('مجموعات اليوم', Icons.calendar_today),
                if (todayGroups.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد مجموعات اليوم'))),
                ...todayGroups.map((g) => _buildGroupCard(context, g)),
                const SizedBox(height: 20),
                if (otherGroups.isNotEmpty) ...[
                  _buildSectionTitle('كل المجموعات الأخرى', Icons.folder_open),
                  ...otherGroups.map((g) => _buildGroupCard(context, g)),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
    );
  }

  Widget _buildGroupCard(BuildContext context, Group g) {
    final max = g.system == 1 ? 4 : 8;
    final isPay = g.currentSession == max;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              justifyAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(g.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPay ? AppColors.danger.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(isPay ? 'حصة دفع' : 'حصة عادية', style: TextStyle(color: isPay ? AppColors.danger : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 5), Text(g.sessions.map((s) => '${s.day} ${s.time}').join(' | '), style: const TextStyle(fontSize: 12, color: Colors.grey))]),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الحصة ${g.currentSession} من $max', style: const TextStyle(fontSize: 13)),
                Text('${g.students.length} طالب', style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPay ? AppColors.secondary : AppColors.primary,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => context.read<AppState>().setScreen('attendance', group: g),
              child: Text(isPay ? 'تسجيل الحضور والدفع 💰' : 'تسجيل الحضور ✓', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, border: const Border(top: BorderSide(color: Colors.black12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navBtn(context, 'مجموعة +', AppColors.secondary, () => context.read<AppState>().setScreen('add_group')),
          _navBtn(context, 'المال 💰', AppColors.primary, () => context.read<AppState>().setScreen('finance_main')),
          _navBtn(context, 'إعدادات ⚙', Colors.grey, () => context.read<AppState>().setScreen('settings')),
        ],
      ),
    );
  }

  Widget _navBtn(BuildContext context, String label, Color color, VoidCallback press) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: press,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

// --- 2. شاشة التحضير (Attendance) ---
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, String> currentStatus = {};
  List<String> currentPaid = [];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final g = state.activeGroup!;
    final max = g.system == 1 ? 4 : 8;
    final isPayDay = g.currentSession == max;

    return Scaffold(
      appBar: AppBar(
        title: Text(g.name),
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: () => state.setScreen('edit_group'))],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: Theme.of(context).cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الشهر ${g.currentMonth} - الحصة ${g.currentSession}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (isPayDay) const Text('⚠️ اليوم موعد تحصيل المصاريف', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: g.students.length,
              itemBuilder: (context, index) {
                final s = g.students[index];
                return Card(
                  child: ListTile(
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.note_alt_outlined),
                          onPressed: () => state.setScreen('notes', student: s),
                        ),
                        _statusIcon(s.id, 'present', Icons.check_circle, Colors.green),
                        _statusIcon(s.id, 'absent', Icons.cancel, Colors.red),
                        if (isPayDay)
                          IconButton(
                            icon: Icon(Icons.monetization_on, color: currentPaid.contains(s.id) ? Colors.blue : Colors.grey),
                            onPressed: () {
                              setState(() {
                                if (currentPaid.contains(s.id)) currentPaid.remove(s.id); else currentPaid.add(s.id);
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _saveAttendance(context, g),
              child: const Text('حفظ وإنهاء الحصة ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _statusIcon(String sid, String status, IconData icon, Color color) {
    bool active = currentStatus[sid] == status;
    return IconButton(
      icon: Icon(icon, color: active ? color : Colors.grey.shade300),
      onPressed: () {
        setState(() {
          currentStatus[sid] = status;
        });
      },
    );
  }

  void _saveAttendance(BuildContext context, Group g) {
    final state = context.read<AppState>();
    final now = intl.DateFormat.yMMMMEEEEd('ar').format(DateTime.now());
    
    final record = AttendanceRecord(
      month: g.currentMonth,
      session: g.currentSession,
      date: now,
      studentStatus: Map.from(currentStatus),
    );

    g.attendanceHistory.add(record);
    
    // تسجيل الدفع
    for (var sid in currentPaid) {
      final s = g.students.firstWhere((st) => st.id == sid);
      if (!s.paidMonths.contains(g.currentMonth)) s.paidMonths.add(g.currentMonth);
    }

    // تحديث الحصة والشهر
    final max = g.system == 1 ? 4 : 8;
    if (g.currentSession < max) {
      g.currentSession++;
    } else {
      g.currentSession = 1;
      g.currentMonth++;
    }

    state.saveData();
    state.setScreen('dashboard');
  }
}

// --- 3. شاشة إضافة مجموعة (Add Group) ---
class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({super.key});

  @override
  State<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final studentCtrl = TextEditingController();
  int system = 1;
  List<String> students = [];
  Map<int, String> sessionDays = {1: 'السبت', 2: 'الأحد'};
  Map<int, String> sessionTimes = {1: '12:00', 2: '12:00'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مجموعة جديدة')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildField('اسم المجموعة', nameCtrl, TextInputType.text),
          _buildField('المصاريف الشهرية (للمجموعة ككل)', priceCtrl, TextInputType.number),
          const Text('نظام الحصص', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(child: RadioListTile(title: const Text('حصة/أسبوع'), value: 1, groupValue: system, onChanged: (v) => setState(() => system = v!))),
              Expanded(child: RadioListTile(title: const Text('حصتين/أسبوع'), value: 2, groupValue: system, onChanged: (v) => setState(() => system = v!))),
            ],
          ),
          _buildSessionPicker(1),
          if (system == 2) _buildSessionPicker(2),
          const Divider(),
          const Text('الطلاب', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(child: TextField(controller: studentCtrl, decoration: const InputDecoration(hintText: 'اسم الطالب'))),
              IconButton(icon: const Icon(Icons.add_circle, color: AppColors.secondary), onPressed: () {
                if (studentCtrl.text.isNotEmpty) {
                  setState(() { students.add(studentCtrl.text); studentCtrl.clear(); });
                }
              }),
            ],
          ),
          Wrap(
            children: students.map((s) => Chip(label: Text(s), onDeleted: () => setState(() => students.remove(s)))).toList(),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 50)),
            onPressed: _save,
            child: const Text('حفظ المجموعة', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(controller: ctrl, keyboardType: type, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
    );
  }

  Widget _buildSessionPicker(int n) {
    final days = ['السبت', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'الأحد'];
    return Column(
      children: [
        Text('ميعاد الحصة $n'),
        DropdownButton<String>(
          value: sessionDays[n],
          isExpanded: true,
          items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => sessionDays[n] = v!),
        ),
        TextButton(onPressed: () async {
          final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
          if (t != null) setState(() => sessionTimes[n] = t.format(context));
        }, child: Text('الوقت: ${sessionTimes[n]}')),
      ],
    );
  }

  void _save() {
    if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty || students.isEmpty) return;
    final List<SessionSchedule> sess = [SessionSchedule(day: sessionDays[1]!, time: sessionTimes[1]!)];
    if (system == 2) sess.add(SessionSchedule(day: sessionDays[2]!, time: sessionTimes[2]!));

    final newGroup = Group(
      id: DateTime.now().toString(),
      name: nameCtrl.text,
      price: double.parse(priceCtrl.text),
      system: system,
      sessions: sess,
      students: students.map((s) => Student(id: DateTime.now().toString() + s, name: s)).toList(),
    );

    context.read<AppState>().addGroup(newGroup);
    context.read<AppState>().setScreen('dashboard');
  }
}

// --- شاشات أخرى (Finance, Notes, Settings) ---
// تم اختصارها هنا لتوفير المساحة ولكنها تتبع نفس منطق الـ HTML المرفق

class FinanceMainScreen extends StatelessWidget {
  const FinanceMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    double total = 0, collected = 0;

    for (var g in state.groups) {
      total += g.price;
      double share = g.students.isEmpty ? 0 : g.price / g.students.length;
      int paidCount = g.students.where((s) => s.paidMonths.contains(g.currentMonth)).length;
      collected += share * paidCount;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('السجل المالي')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF1E40AF)]), borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _sumItem('الإجمالي', total.toStringAsFixed(0)),
                _sumItem('تحصيل', collected.toStringAsFixed(0)),
                _sumItem('متبقي', (total - collected).toStringAsFixed(0)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: state.groups.length,
              itemBuilder: (context, i) {
                final g = state.groups[i];
                return ListTile(
                  title: Text(g.name),
                  subtitle: Text('${g.students.length} طلاب'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => state.setScreen('finance_group', group: g),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _sumItem(String label, String val) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]);
  }
}

class FinanceGroupScreen extends StatelessWidget {
  const FinanceGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final g = state.activeGroup!;
    double share = g.students.isEmpty ? 0 : g.price / g.students.length;

    return Scaffold(
      appBar: AppBar(title: Text('ماليات: ${g.name}')),
      body: ListView.builder(
        itemCount: g.students.length,
        itemBuilder: (context, i) {
          final s = g.students[i];
          bool paid = s.paidMonths.contains(g.currentMonth);
          return ListTile(
            title: Text(s.name),
            trailing: Chip(
              label: Text(paid ? 'تم الدفع' : 'لم يدفع'),
              backgroundColor: paid ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            ),
          );
        },
      ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final noteCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.activeStudent!;
    return Scaffold(
      appBar: AppBar(title: Text('ملاحظات: ${s.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(child: TextField(controller: noteCtrl, decoration: const InputDecoration(hintText: 'اكتب ملاحظة...'))),
                IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: () {
                  if (noteCtrl.text.isNotEmpty) {
                    setState(() {
                      s.notes.add(Note(text: noteCtrl.text, date: DateTime.now().toString(), month: state.activeGroup!.currentMonth, session: state.activeGroup!.currentSession));
                      noteCtrl.clear();
                      state.saveData();
                    });
                  }
                }),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: s.notes.length,
              itemBuilder: (context, i) {
                final n = s.notes[s.notes.length - 1 - i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  child: ListTile(
                    title: Text(n.text),
                    subtitle: Text(n.date.substring(0, 16)),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                      setState(() { s.notes.remove(n); state.saveData(); });
                    }),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          SwitchListTile(
            title: const Text('الوضع الداكن (Dark Mode)'),
            value: state.isDarkMode,
            onChanged: (v) => state.toggleTheme(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('حذف جميع البيانات', style: TextStyle(color: Colors.red)),
            onTap: () {
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text('تأكيد الحذف'),
                content: const Text('سيتم حذف كافة المجموعات والطلاب والبيانات المالية نهائياً!'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                  TextButton(onPressed: () { state.deleteAll(); Navigator.pop(ctx); }, child: const Text('حذف الكل', style: TextStyle(color: Colors.red))),
                ],
              ));
            },
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('إصدار 1.0.0 - فلاتر', style: TextStyle(color: Colors.grey))),
          )
        ],
      ),
    );
  }
}

class EditGroupScreen extends StatelessWidget {
  const EditGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final g = state.activeGroup!;
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل المجموعة')),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            state.deleteGroup(g.id);
            state.setScreen('dashboard');
          },
          child: const Text('حذف هذه المجموعة نهائياً', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
