import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:table_calendar/table_calendar.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Using real Firebase — no emulators needed
  runApp(const ChoreMateApp());
}

class ChoreMateApp extends StatelessWidget {
  const ChoreMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChoreMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const HouseGate();
        return const LoginScreen();
      },
    );
  }
}

// ============================================================
// HOUSE GATE
// ============================================================
class HouseGate extends StatelessWidget {
  const HouseGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const HouseSelectionScreen();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final houseIds = List<String>.from(data?['houseIds'] ?? []);
        if (houseIds.isEmpty) return const HouseSelectionScreen();
        return HomeScreen(houseId: houseIds.first);
      },
    );
  }
}

// ============================================================
// LOGIN SCREEN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? error;
  bool isLoading = false;

  Future<void> signIn() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ChoreMate')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Image.asset('assets/logo.png', height: 300),
            const SizedBox(height: 32),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : signIn,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              ),
              child: const Text('Don\'t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SIGN UP SCREEN
// ============================================================
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String? error;
  bool isLoading = false;

  Future<void> signUp() async {
    if (nameController.text.trim().isEmpty) {
      setState(() => error = 'Name is required');
      return;
    }
    if (emailController.text.trim().isEmpty) {
      setState(() => error = 'Email is required');
      return;
    }
    if (passwordController.text.length < 6) {
      setState(() => error = 'Password must be at least 6 characters');
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      setState(() => error = 'Passwords do not match');
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
            'displayName': nameController.text.trim(),
            'email': emailController.text.trim(),
            'houseIds': [],
          });
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.person_add,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Create your account',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Alex Johnson',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'e.g. alex@example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign Up', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Already have an account? Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOUSE SELECTION SCREEN
// ============================================================
class HouseSelectionScreen extends StatelessWidget {
  const HouseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChoreMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to ChoreMate!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new house or join an existing one.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateHouseScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text(
                  'Create a House',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinHouseScreen()),
                ),
                icon: const Icon(Icons.group_add),
                label: const Text(
                  'Join with Code',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CREATE HOUSE SCREEN
// ============================================================
class CreateHouseScreen extends StatefulWidget {
  const CreateHouseScreen({super.key});

  @override
  State<CreateHouseScreen> createState() => _CreateHouseScreenState();
}

class _CreateHouseScreenState extends State<CreateHouseScreen> {
  final nameController = TextEditingController();
  final rulesController = TextEditingController();
  String? error;
  bool isLoading = false;

  Future<void> createHouse() async {
    if (nameController.text.trim().isEmpty) {
      setState(() => error = 'House name is required');
      return;
    }
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createHouse')
          .call({
            'name': nameController.text.trim(),
            'rules': rulesController.text.trim(),
          });
      final data = Map<String, dynamic>.from(result.data as Map);
      final joinCode = data['joinCode'] as String;
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('House Created!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this code with your housemates:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      joinCode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: joinCode));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a House')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'House Name',
                hintText: 'e.g. Elm Street House',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rulesController,
              decoration: const InputDecoration(
                labelText: 'House Rules (optional)',
                hintText: 'e.g. No shoes inside, quiet after 10pm',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : createHouse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create House',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// JOIN HOUSE SCREEN
// ============================================================
class JoinHouseScreen extends StatefulWidget {
  const JoinHouseScreen({super.key});

  @override
  State<JoinHouseScreen> createState() => _JoinHouseScreenState();
}

class _JoinHouseScreenState extends State<JoinHouseScreen> {
  final codeController = TextEditingController();
  String? error;
  bool isLoading = false;

  Future<void> joinHouse() async {
    if (codeController.text.trim().isEmpty) {
      setState(() => error = 'Join code is required');
      return;
    }
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('joinHouse')
          .call({'joinCode': codeController.text.trim()});
      final data = Map<String, dynamic>.from(result.data as Map);
      final houseName = data['houseName'] as String;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined "$houseName" successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      String message = e.toString();
      if (message.contains('not-found'))
        message = 'Invalid join code. Please check and try again.';
      else if (message.contains('already-exists'))
        message = 'You are already a member of this house.';
      if (!mounted) return;
      setState(() => error = message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a House')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.vpn_key_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Enter your house code',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask your housemate for the 6-character code',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Join Code',
                hintText: 'e.g. ELM123',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : joinHouse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Join House', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOME SCREEN — Bottom Navigation with 4 tabs
// ============================================================
class HomeScreen extends StatefulWidget {
  final String houseId;
  const HomeScreen({super.key, required this.houseId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ChoresTab(houseId: widget.houseId),
      EventsTab(houseId: widget.houseId),
      HouseInfoTab(houseId: widget.houseId),
      ProfileTab(houseId: widget.houseId),
    ];
    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Chores'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.home), label: 'House'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================
// CHORES TAB
// ============================================================
class ChoresTab extends StatelessWidget {
  final String houseId;
  const ChoresTab({super.key, required this.houseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chores')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('houses')
            .doc(houseId)
            .collection('chores')
            .orderBy('dueDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No chores yet',
                    style: TextStyle(color: Colors.grey[500], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create one',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }
          final pending = docs
              .where((d) => (d.data() as Map)['completed'] == false)
              .toList();
          final completed = docs
              .where((d) => (d.data() as Map)['completed'] == true)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Pending (${pending.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...pending.map(
                  (doc) =>
                      _ChoreCard(doc: doc, houseId: houseId, isPending: true),
                ),
                const SizedBox(height: 24),
              ],
              if (completed.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Completed (${completed.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
                ...completed.map(
                  (doc) =>
                      _ChoreCard(doc: doc, houseId: houseId, isPending: false),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateChoreScreen(houseId: houseId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// CHORE CARD
// ============================================================
class _ChoreCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String houseId;
  final bool isPending;
  const _ChoreCard({
    required this.doc,
    required this.houseId,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String;
    final assignedTo = data['assignedTo'] as String;
    final recurrence = data['recurrence'] as String? ?? 'none';
    final completed = data['completed'] as bool;
    DateTime? dueDate;
    if (data['dueDate'] is Timestamp)
      dueDate = (data['dueDate'] as Timestamp).toDate();
    final isOverdue =
        dueDate != null &&
        !completed &&
        dueDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: completed ? Colors.grey[50] : null,
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            completed ? Icons.check_circle : Icons.circle_outlined,
            color: completed
                ? Colors.teal
                : (isOverdue ? Colors.red : Colors.grey[400]),
            size: 28,
          ),
          onPressed: completed
              ? null
              : () async {
                  try {
                    await FirebaseFunctions.instance
                        .httpsCallable('completeChore')
                        .call({'houseId': houseId, 'choreId': doc.id});
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$name" completed!')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: completed ? TextDecoration.lineThrough : null,
            color: completed ? Colors.grey[500] : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildAssignedTo(context, assignedTo),
            const SizedBox(height: 2),
            Row(
              children: [
                if (dueDate != null) ...[
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: isOverdue ? Colors.red : Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${dueDate.month}/${dueDate.day}/${dueDate.year}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isOverdue ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ],
                if (recurrence != 'none') ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat, size: 12, color: Colors.teal[700]),
                        const SizedBox(width: 4),
                        Text(
                          recurrence,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedTo(BuildContext context, String assignedTo) {
    if (assignedTo == 'anyone') {
      return Row(
        children: [
          Icon(Icons.group, size: 14, color: Colors.teal[500]),
          const SizedBox(width: 4),
          Text(
            'Anyone',
            style: TextStyle(
              fontSize: 13,
              color: Colors.teal[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(assignedTo)
          .get(),
      builder: (context, snapshot) {
        String displayName = assignedTo;
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          displayName = userData?['displayName'] ?? assignedTo;
        }
        return Row(
          children: [
            Icon(Icons.person, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              displayName,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// CREATE CHORE SCREEN
// ============================================================
class CreateChoreScreen extends StatefulWidget {
  final String houseId;
  const CreateChoreScreen({super.key, required this.houseId});

  @override
  State<CreateChoreScreen> createState() => _CreateChoreScreenState();
}

class _CreateChoreScreenState extends State<CreateChoreScreen> {
  final nameController = TextEditingController();
  String? error;
  bool isLoading = false;
  DateTime selectedDate = DateTime.now();
  String selectedRecurrence = 'none';
  String? selectedMemberId;
  List<Map<String, dynamic>> members = [];
  final recurrenceOptions = ['none', 'daily', 'weekly', 'biweekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getHouseInfo')
          .call({'houseId': widget.houseId});
      final data = Map<String, dynamic>.from(result.data as Map);
      final memberList = (data['members'] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
      setState(() {
        members = [
          {'uid': 'anyone', 'displayName': 'Anyone (first available)'},
          ...memberList,
        ];
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        selectedMemberId = members.any((m) => m['uid'] == currentUid)
            ? currentUid
            : members.first['uid'] as String;
      });
    } catch (e) {
      setState(() => error = 'Error loading members');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _createChore() async {
    if (nameController.text.trim().isEmpty) {
      setState(() => error = 'Chore name is required');
      return;
    }
    if (selectedMemberId == null) {
      setState(() => error = 'Please select who this chore is assigned to');
      return;
    }
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      await FirebaseFunctions.instance.httpsCallable('createChore').call({
        'houseId': widget.houseId,
        'name': nameController.text.trim(),
        'assignedTo': selectedMemberId,
        'dueDate': selectedDate.toIso8601String(),
        'recurrence': selectedRecurrence,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chore created!')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Chore')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Chore Name',
                hintText: 'e.g. Take out trash',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('Assign to', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (members.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedMemberId,
                    isExpanded: true,
                    items: members
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m['uid'] as String,
                            child: Text(m['displayName'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => selectedMemberId = val),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text('Due Date', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Recurrence', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedRecurrence,
                  isExpanded: true,
                  items: recurrenceOptions
                      .map(
                        (r) => DropdownMenuItem<String>(
                          value: r,
                          child: Text(
                            r == 'none'
                                ? 'One-time'
                                : r[0].toUpperCase() + r.substring(1),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => selectedRecurrence = val ?? 'none'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _createChore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Chore',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// EVENTS TAB — Calendar view with event list
// ============================================================
class EventsTab extends StatefulWidget {
  final String houseId;
  const EventsTab({super.key, required this.houseId});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('houses')
            .doc(widget.houseId)
            .collection('events')
            .orderBy('startDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          final docs = snapshot.data!.docs;

          // Build map of date -> events
          final Map<DateTime, List<QueryDocumentSnapshot>> eventsByDay = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['startDate'] is Timestamp) {
              final date = (data['startDate'] as Timestamp).toDate();
              final dayKey = DateTime(date.year, date.month, date.day);
              eventsByDay[dayKey] ??= [];
              eventsByDay[dayKey]!.add(doc);
            }
          }

          final selectedDayKey = DateTime(
            _selectedDay.year,
            _selectedDay.month,
            _selectedDay.day,
          );
          final selectedEvents = eventsByDay[selectedDayKey] ?? [];

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) =>
                    setState(() => _calendarFormat = format),
                onDaySelected: (selectedDay, focusedDay) => setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                }),
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                eventLoader: (day) =>
                    eventsByDay[DateTime(day.year, day.month, day.day)] ?? [],
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.teal.shade200,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Colors.teal.shade700,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 6,
                  markersMaxCount: 3,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonShowsNext: false,
                  titleCentered: true,
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.grey[300]),
              Expanded(
                child: selectedEvents.isEmpty
                    ? Center(
                        child: Text(
                          'No events on this day',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: selectedEvents.length,
                        itemBuilder: (context, index) => _EventCard(
                          doc: selectedEvents[index],
                          houseId: widget.houseId,
                          isPast: false,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateEventScreen(houseId: widget.houseId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// EVENT CARD
// ============================================================
class _EventCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String houseId;
  final bool isPast;
  const _EventCard({
    required this.doc,
    required this.houseId,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String;
    final description = data['description'] as String? ?? '';
    final createdBy = data['createdBy'] as String? ?? '';
    DateTime? startDate;
    if (data['startDate'] is Timestamp)
      startDate = (data['startDate'] as Timestamp).toDate();

    String timeStr = '';
    if (startDate != null && (startDate.hour != 0 || startDate.minute != 0)) {
      final hour = startDate.hour > 12
          ? startDate.hour - 12
          : (startDate.hour == 0 ? 12 : startDate.hour);
      final amPm = startDate.hour >= 12 ? 'PM' : 'AM';
      final minute = startDate.minute.toString().padLeft(2, '0');
      timeStr = '$hour:$minute $amPm';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(createdBy)
                      .get(),
                  builder: (context, snapshot) {
                    String name = '';
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      name = userData?['displayName'] ?? '';
                    }
                    if (name.isEmpty) return const SizedBox.shrink();
                    return Text(
                      'Created by $name',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    );
                  },
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Event'),
                        content: Text(
                          'Are you sure you want to delete "$title"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    try {
                      await FirebaseFunctions.instance
                          .httpsCallable('deleteEvent')
                          .call({'houseId': houseId, 'eventId': doc.id});
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"$title" deleted')),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      String msg = e.toString();
                      if (msg.contains('permission-denied'))
                        msg = 'Only the house rep can delete events.';
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CREATE EVENT SCREEN
// ============================================================
class CreateEventScreen extends StatefulWidget {
  final String houseId;
  const CreateEventScreen({super.key, required this.houseId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String? error;
  bool isLoading = false;
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  Future<void> _createEvent() async {
    if (titleController.text.trim().isEmpty) {
      setState(() => error = 'Event title is required');
      return;
    }
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final eventDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      await FirebaseFunctions.instance.httpsCallable('createEvent').call({
        'houseId': widget.houseId,
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'startDate': eventDateTime.toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event created!')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = selectedTime.hour > 12
        ? selectedTime.hour - 12
        : (selectedTime.hour == 0 ? 12 : selectedTime.hour);
    final amPm = selectedTime.hour >= 12 ? 'PM' : 'AM';
    final minute = selectedTime.minute.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Event Title',
                hintText: 'e.g. House Meeting',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Discuss chore rotation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Text('Date', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Time', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '$hour:$minute $amPm',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _createEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Event',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOUSE INFO TAB
// ============================================================
class HouseInfoTab extends StatelessWidget {
  final String houseId;
  const HouseInfoTab({super.key, required this.houseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('House Info')),
      body: FutureBuilder(
        future: FirebaseFunctions.instance.httpsCallable('getHouseInfo').call({
          'houseId': houseId,
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading house info: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );

          final data = Map<String, dynamic>.from(snapshot.data!.data as Map);
          final houseName = data['name'] as String;
          final joinCode = data['joinCode'] as String;
          final rules = data['rules'] as String;
          final members = (data['members'] as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCard(
                  children: [
                    Text(
                      houseName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.vpn_key, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Join Code: ',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          joinCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: joinCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Join code copied!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.rule,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'House Rules',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rules.isNotEmpty ? rules : 'No rules set yet.',
                      style: TextStyle(
                        color: rules.isNotEmpty
                            ? Colors.black87
                            : Colors.grey[500],
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Members (${members.length})',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...members.map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Text(
                                (member['displayName'] as String)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['displayName'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    member['email'] as String,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (member['role'] == 'rep')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Rep',
                                  style: TextStyle(
                                    color: Colors.teal.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ContactsSection(houseId: houseId),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// CONTACTS SECTION
// ============================================================
class _ContactsSection extends StatelessWidget {
  final String houseId;
  const _ContactsSection({required this.houseId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFunctions.instance.httpsCallable('getContacts').call({
        'houseId': houseId,
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _SectionCard(
            children: [
              Text(
                'Error loading contacts',
                style: TextStyle(color: Colors.red[400]),
              ),
            ],
          );

        final data = Map<String, dynamic>.from(snapshot.data!.data as Map);
        final contacts = (data['contacts'] as List)
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();

        return _SectionCard(
          children: [
            Row(
              children: [
                Icon(
                  Icons.contacts,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shared Contacts (${contacts.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.teal,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateContactScreen(houseId: houseId),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contacts.isEmpty)
              Text(
                'No contacts added yet.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ...contacts.map(
              (contact) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _getLabelColor(
                        contact['label'] as String,
                      ),
                      child: Icon(
                        _getLabelIcon(contact['label'] as String),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            contact['phone'] as String,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((contact['label'] as String).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getLabelColor(
                            contact['label'] as String,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          contact['label'] as String,
                          style: TextStyle(
                            color: _getLabelColor(contact['label'] as String),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getLabelColor(String label) {
    switch (label.toLowerCase()) {
      case 'landlord':
        return Colors.blue;
      case 'plumber':
        return Colors.orange;
      case 'electrician':
        return Colors.amber.shade700;
      case 'utility':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getLabelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'landlord':
        return Icons.apartment;
      case 'plumber':
        return Icons.plumbing;
      case 'electrician':
        return Icons.electrical_services;
      case 'utility':
        return Icons.water_drop;
      default:
        return Icons.phone;
    }
  }
}

// ============================================================
// CREATE CONTACT SCREEN
// ============================================================
class CreateContactScreen extends StatefulWidget {
  final String houseId;
  const CreateContactScreen({super.key, required this.houseId});

  @override
  State<CreateContactScreen> createState() => _CreateContactScreenState();
}

class _CreateContactScreenState extends State<CreateContactScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  String selectedLabel = 'other';
  String? error;
  bool isLoading = false;
  final labelOptions = [
    'landlord',
    'plumber',
    'electrician',
    'utility',
    'other',
  ];

  Future<void> _createContact() async {
    if (nameController.text.trim().isEmpty) {
      setState(() => error = 'Contact name is required');
      return;
    }
    if (phoneController.text.trim().isEmpty) {
      setState(() => error = 'Phone number is required');
      return;
    }
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      await FirebaseFunctions.instance.httpsCallable('addContact').call({
        'houseId': widget.houseId,
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'label': selectedLabel,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact added!')));
      Navigator.of(context).pop();
    } catch (e) {
      String message = e.toString();
      if (message.contains('permission-denied'))
        message = 'Only the house rep can add contacts.';
      if (!mounted) return;
      setState(() => error = message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Contact')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                hintText: 'e.g. Bob the Plumber',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 555-123-4567',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            Text('Label', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedLabel,
                  isExpanded: true,
                  items: labelOptions
                      .map(
                        (l) => DropdownMenuItem<String>(
                          value: l,
                          child: Text(l[0].toUpperCase() + l.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => selectedLabel = val ?? 'other'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _createContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Add Contact', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION CARD
// ============================================================
class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ============================================================
// PROFILE TAB
// ============================================================
class ProfileTab extends StatelessWidget {
  final String houseId;
  const ProfileTab({super.key, required this.houseId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (user?.email ?? 'U').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.email ?? 'Unknown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseFunctions.instance
                        .httpsCallable('leaveHouse')
                        .call({'houseId': houseId});
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                label: const Text(
                  'Leave House',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
