import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import the Firebase configuration

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions
        .currentPlatform, // Use the correct Firebase config
  );
  runApp(MyApp());
}

class DefaultFirebaseOptions {
  // ignore: prefer_typing_uninitialized_variables
  static var currentPlatform;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return TaskListScreen();
          }
          return LoginScreen();
        },
      ),
    );
  }
}

class Task {
  final String id;
  final String name;
  final bool completed;
  final List<String> subtasks;
  final DateTime timestamp;

  Task({
    required this.id,
    required this.name,
    required this.completed,
    required this.subtasks,
    required this.timestamp,
  });

  factory Task.fromSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return Task(
      id: snapshot.id,
      name: data['name'] ?? '',
      completed: data['completed'] ?? false,
      subtasks: List<String>.from(data['subtasks'] ?? []),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginScreen({super.key});

  Future<void> _signIn(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    }
  }

  Future<void> _signUp(BuildContext context) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Manager - Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _signIn(context),
                  child: const Text('Sign In'),
                ),
                ElevatedButton(
                  onPressed: () => _signUp(context),
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _subtaskController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Task> _tasks = [];
  final List<String> _currentSubtasks = [];

  @override
  void dispose() {
    _taskNameController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final taskName = _taskNameController.text;
    if (taskName.isEmpty) return;

    await _firestore.collection('tasks').add({
      'name': taskName,
      'completed': false,
      'subtasks': _currentSubtasks,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser?.uid,
    });

    _taskNameController.clear();
    _currentSubtasks.clear();
  }

  Future<void> _deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
  }

  Future<void> _toggleCompleted(Task task) async {
    await _firestore.collection('tasks').doc(task.id).update({
      'completed': !task.completed,
    });
  }

  void _addSubtask() {
    if (_subtaskController.text.isNotEmpty) {
      setState(() {
        _currentSubtasks.add(_subtaskController.text);
        _subtaskController.clear();
      });
    }
  }

  void _removeSubtask(int index) {
    setState(() {
      _currentSubtasks.removeAt(index);
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Widget _buildTaskItem(Task task) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            Checkbox(
              value: task.completed,
              onChanged: (value) => _toggleCompleted(task),
            ),
            Expanded(
              child: Text(
                task.name,
                style: TextStyle(
                  decoration:
                      task.completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text(
                  'Subtasks:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...task.subtasks
                    .map(
                      (subtask) => ListTile(
                        title: Text(subtask),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            // Implement subtask removal if needed
                          },
                        ),
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _deleteTask(task.id),
              child: const Text('Delete Task',
                  style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut)
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _taskNameController,
                  decoration: const InputDecoration(
                    labelText: 'Task Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _subtaskController,
                  decoration: InputDecoration(
                    labelText: 'Add Subtask (e.g., "9am-10am: HW1")',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addSubtask,
                    ),
                  ),
                  onSubmitted: (_) => _addSubtask(),
                ),
                if (_currentSubtasks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Current Subtasks:'),
                  ..._currentSubtasks.asMap().entries.map(
                        (entry) => ListTile(
                          title: Text(entry.value),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeSubtask(entry.key),
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 10),
                ElevatedButton(
                    onPressed: _addTask, child: const Text('Add Task')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('tasks')
                  .where(
                    'userId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No tasks yet. Add your first task!'),
                  );
                }

                _tasks = snapshot.data!.docs
                    .map((doc) => Task.fromSnapshot(doc))
                    .toList();

                return ListView.builder(
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) =>
                      _buildTaskItem(_tasks[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
