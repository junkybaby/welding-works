import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Settings'),
              Tab(text: 'Logs'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _SettingsTab(),
            _LogsTab(),
            _ReportsTab(),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final users = [
      _UserRow(name: 'Juan Dela Cruz', role: 'Trainer', status: 'Active'),
      _UserRow(name: 'Maria Santos', role: 'Trainee', status: 'Pending'),
      _UserRow(name: 'Admin User', role: 'Admin', status: 'Active'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...users.map((u) => _UserCard(user: u)),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Enable registrations'),
          subtitle: const Text('Allow new trainers/trainees to sign up'),
        ),
        SwitchListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Require OTP verification'),
          subtitle: const Text('Force email OTP on signup'),
        ),
        ListTile(
          title: const Text('Password policy'),
          subtitle: const Text('Minimum 8 chars, 1 upper, 1 number'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        ListTile(
          title: const Text('API base URL'),
          subtitle: const Text('http://192.168.5.143:8080'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
      ],
    );
  }
}

class _LogsTab extends StatelessWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context) {
    final logs = [
      _LogItem('Admin logged in', '2026-03-12 01:12'),
      _LogItem('User created: Maria Santos', '2026-03-12 01:05'),
      _LogItem('Settings updated: OTP required', '2026-03-11 23:48'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(log.message),
          subtitle: Text(log.timestamp),
          leading: const Icon(Icons.receipt_long),
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Generate daily activity log'),
          subtitle: const Text('Exports CSV for today'),
          trailing: const Icon(Icons.download),
          onTap: () {},
        ),
        ListTile(
          title: const Text('Assessment summary'),
          subtitle: const Text('Per batch and trainee results'),
          trailing: const Icon(Icons.download),
          onTap: () {},
        ),
        ListTile(
          title: const Text('User audit report'),
          subtitle: const Text('Create a full audit trail'),
          trailing: const Icon(Icons.download),
          onTap: () {},
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final _UserRow user;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        title: Text(user.name),
        subtitle: Text('${user.role} · ${user.status}'),
        trailing: PopupMenuButton<String>(
          onSelected: (_) {},
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Text('View')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'disable', child: Text('Disable')),
          ],
        ),
      ),
    );
  }
}

class _UserRow {
  const _UserRow({
    required this.name,
    required this.role,
    required this.status,
  });

  final String name;
  final String role;
  final String status;
}

class _LogItem {
  const _LogItem(this.message, this.timestamp);

  final String message;
  final String timestamp;
}
