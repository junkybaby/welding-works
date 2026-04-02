import 'dart:convert';
import 'dart:io';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:welding_works/admin_mobile_ui.dart';
import 'package:welding_works/app_config.dart';
import 'package:welding_works/app_routes.dart';
import 'package:welding_works/assessment_screen.dart';
import 'package:welding_works/auth_session.dart';
import 'package:welding_works/criteria_dashboard.dart';

const String kTesdaCcEmail = "tesdaweldingworksservice@gmail.com";
enum _ExportAction { email, share }

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final List<_Batch> _batches = [];
  final List<_ArchivedBatch> _archive = [];
  bool _isLoading = true;
  String _loadError = "";
  String _trainerEmail = "";
  String _trainerUsername = "";

  @override
  void initState() {
    super.initState();
    _loadSessionAndData();
  }

  Future<void> _loadSessionAndData() async {
    final email = await AuthSession.getEmail();
    final username = await AuthSession.getUsername();
    setState(() {
      _trainerEmail = email ?? "";
      if (username != null && username.isNotEmpty) {
        _trainerUsername = username;
      } else if (_trainerEmail.contains("@")) {
        _trainerUsername = _trainerEmail.split("@")[0];
      }
    });
    await _refreshData();
  }

  Future<void> _refreshData() async {
    if (_trainerEmail.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = "";
    });
    try {
      await Future.wait([_fetchBatches(), _fetchArchive()]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = "Unable to load dashboard data.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dashboard load failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      if (_trainerEmail.isNotEmpty) {
        final url = Uri.parse("${AppConfig.weldingApi}/logout.php");
        await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": _trainerEmail,
            "role": "trainer",
          }),
        );
      }
    } catch (_) {}
    await AuthSession.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _openCreateBatchDialog() async {
    final trainingCenterController = TextEditingController();
    final lastNameController = TextEditingController();
    final firstNameController = TextEditingController();
    final middleInitialController = TextEditingController();
    final List<String> trainees = [];

    final result = await showDialog<_Batch>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          void addTrainee() {
            final last = lastNameController.text.trim();
            final first = firstNameController.text.trim();
            final mi = middleInitialController.text.trim();
            if (last.isEmpty || first.isEmpty) {
              return;
            }
            final miPart = mi.isNotEmpty ? " ${mi.toUpperCase()}." : "";
            final formatted = "${last}, ${first}${miPart}";
            setDialogState(() {
              trainees.add(formatted);
              lastNameController.clear();
              firstNameController.clear();
              middleInitialController.clear();
            });
          }

          return AlertDialog(
            title: const Text('Create Batch'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batch name: SMAW NC I',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: trainingCenterController,
                    decoration: const InputDecoration(
                      labelText: 'School / Training Center',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add trainee',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: middleInitialController,
                          decoration: const InputDecoration(
                            labelText: 'MI',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: addTrainee,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add trainee',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (trainees.isNotEmpty) ...[
                    const Divider(height: 20),
                    const Text(
                      'Trainees',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: trainees
                          .map(
                            (name) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('• $name'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final center = trainingCenterController.text.trim();
                  if (center.isEmpty || trainees.isEmpty) {
                    return;
                  }

                  Navigator.pop(
                    context,
                    _Batch(
                      name: trainingCenterController.text.trim(),
                      trainingCenter: center,
                      createdAt: DateTime.now(),
                      trainees: trainees
                          .map((t) => Trainee(id: 0, name: t))
                          .toList(),
                    ),
                  );
                },
                child: const Text('Create'),
              ),
            ],
          );
        });
      },
    );

    if (result != null) {
      await _createBatch(result);
    }
  }

  Future<void> _createBatch(_Batch batch) async {
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/create_batch.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "trainer_email": _trainerEmail,
          "trainer_username": _trainerUsername,
          "name": batch.name,
          "training_center": batch.trainingCenter,
          "trainees": batch.trainees.map((t) => t.name).toList(),
        }),
      );
      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }
      final data = jsonDecode(response.body);
      if (data is Map && data["status"] == "success") {
        await _fetchBatches();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"] ?? "Create batch failed")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _fetchBatches() async {
    try {
    final url = Uri.parse("${AppConfig.weldingApi}/list_batches.php");
    final response = await http
        .post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"trainer_email": _trainerEmail}),
    )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception("Active batches returned ${response.statusCode}");
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data["status"] != "success") {
      throw Exception(
        data is Map ? (data["message"] ?? "Active batches load failed") : "Active batches load failed",
      );
    }
    final List<_Batch> loaded = [];
    final batches = data["batches"];
    if (batches is List) {
      for (final item in batches) {
        final trainees = <Trainee>[];
        final tlist = item["trainees"];
        if (tlist is List) {
          for (final t in tlist) {
            final result = (t["result"] ?? "Pending").toString();
            trainees.add(
              Trainee(
                id: _parseId(t["id"]),
                name: (t["trainee_name"] ?? "").toString(),
                trainingCenter:
                    (t["training_center"] ?? "").toString(),
                status: (t["status"] ?? "Not Yet Competent").toString(),
                result: result,
                assessed: result != "Pending",
                assessedDate: (t["assessed_date"] ?? "").toString(),
              ),
            );
          }
        }
        loaded.add(
          _Batch(
            id: _parseId(item["id"]),
            name: (item["name"] ?? "").toString(),
            trainingCenter: (item["training_center"] ?? "").toString(),
            createdAt: DateTime.tryParse((item["created_at"] ?? "").toString()) ??
                DateTime.now(),
            trainees: trainees,
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _batches
        ..clear()
        ..addAll(loaded);
    });
    } catch (e) {
      throw Exception("Batches: $e");
    }
  }

  Future<void> _fetchArchive() async {
    try {
    final url = Uri.parse("${AppConfig.weldingApi}/list_archive.php");
    final response = await http
        .post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"trainer_email": _trainerEmail}),
    )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception("Archive returned ${response.statusCode}");
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data["status"] != "success") {
      throw Exception(
        data is Map ? (data["message"] ?? "Archive load failed") : "Archive load failed",
      );
    }
    final List<_ArchivedBatch> records = [];
    final batches = data["batches"];
    if (batches is List) {
      for (final item in batches) {
        final trainees = <_ArchivedTrainee>[];
        final tlist = item["trainees"];
        if (tlist is List) {
          for (final t in tlist) {
            trainees.add(
              _ArchivedTrainee(
                name: (t["trainee_name"] ?? "").toString(),
                status: (t["status"] ?? "Not Yet Competent").toString(),
                result: (t["result"] ?? "Pending").toString(),
                assessedDate: (t["assessed_date"] ?? "").toString(),
              ),
            );
          }
        }
        records.add(
          _ArchivedBatch(
            id: _parseId(item["id"]),
            batchName: (item["name"] ?? "").toString(),
            trainingCenter: (item["training_center"] ?? "").toString(),
            archivedAt: DateTime.tryParse(
                  (item["archived_at"] ?? "").toString(),
                ) ??
                DateTime.now(),
            trainees: trainees,
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _archive
        ..clear()
        ..addAll(records);
    });
    } catch (e) {
      throw Exception("Archive: $e");
    }
  }

  Future<bool> _archiveBatch(_Batch batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Batch'),
        content: Text('Archive ${batch.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/archive_batch.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"batch_id": batch.id}),
      );
      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }
      final data = jsonDecode(response.body);
      if (data is Map && data["status"] == "success") {
        await _refreshData();
        return true;
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"] ?? "Archive failed")),
      );
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
    return false;
  }

  Future<void> _updateTraineeStatus(Trainee trainee) async {
    if (trainee.id <= 0) return;
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/update_trainee_status.php");
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "batch_trainee_id": trainee.id,
          "status": trainee.status,
          "result": trainee.result,
        }),
      );
    } catch (_) {
      // Ignore UI errors; refresh will reconcile.
    }
  }

  Future<void> _updateBatch(_Batch batch) async {
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/update_batch.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "batch_id": batch.id,
          "training_center": batch.trainingCenter,
          "trainees": batch.trainees
              .map((t) => {"id": t.id, "name": t.name})
              .toList(),
        }),
      );
      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }
      final data = jsonDecode(response.body);
      if (data is Map && data["status"] == "success") {
        await _fetchBatches();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"] ?? "Update failed")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _openArchive() async {
    await _fetchArchive();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ArchiveScreen(
          records: _archive,
          onUndoArchive: _undoArchiveBatch,
        ),
      ),
    );
  }

  Future<void> _undoArchiveBatch(_ArchivedBatch batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Archive'),
        content: Text('Restore ${batch.batchName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/unarchive_batch.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"batch_id": batch.id}),
      );
      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }
      final data = jsonDecode(response.body);
      if (data is Map && data["status"] == "success") {
        await _refreshData();
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"] ?? "Restore failed")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _openEditBatchDialog(_Batch batch) async {
    final trainingCenterController =
        TextEditingController(text: batch.trainingCenter);
    final trainees = batch.trainees
        .map((t) => Trainee(
              id: t.id,
              name: t.name,
              trainingCenter: t.trainingCenter,
              assessed: t.assessed,
              status: t.status,
              result: t.result,
              score: t.score,
            ))
        .toList();

    final lastNameController = TextEditingController();
    final firstNameController = TextEditingController();
    final middleInitialController = TextEditingController();

    final result = await showDialog<_Batch>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          void addTrainee() {
            final last = lastNameController.text.trim();
            final first = firstNameController.text.trim();
            final mi = middleInitialController.text.trim();
            if (last.isEmpty || first.isEmpty) return;
            final miPart = mi.isNotEmpty ? " ${mi.toUpperCase()}." : "";
            final formatted = "${last}, ${first}${miPart}";
            setDialogState(() {
              trainees.add(Trainee(id: 0, name: formatted));
              lastNameController.clear();
              firstNameController.clear();
              middleInitialController.clear();
            });
          }

          return AlertDialog(
            title: const Text('Edit Batch'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: trainingCenterController,
                    decoration: const InputDecoration(
                      labelText: 'School / Training Center',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Trainees',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...trainees.asMap().entries.map((entry) {
                    final index = entry.key;
                    final trainee = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: TextEditingController(text: trainee.name),
                        onChanged: (value) => trainees[index].name = value,
                        decoration: const InputDecoration(
                          labelText: 'Trainee name',
                        ),
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  const Text(
                    'Add trainee',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: middleInitialController,
                          decoration: const InputDecoration(
                            labelText: 'MI',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: addTrainee,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add trainee',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final center = trainingCenterController.text.trim();
                  if (center.isEmpty || trainees.isEmpty) return;
                  Navigator.pop(
                    context,
                    _Batch(
                      id: batch.id,
                      name: batch.name,
                      trainingCenter: center,
                      createdAt: batch.createdAt,
                      trainees: trainees,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );

    if (result != null) {
      await _updateBatch(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminMobileScaffold(
      title: 'Trainer Dashboard',
      subtitle: _trainerUsername.isEmpty
          ? 'Create, assess, archive, and review batches.'
          : 'Logged in as $_trainerUsername',
      actions: [
        IconButton(
          onPressed: _openArchive,
          icon: const Icon(Icons.archive_outlined, color: Colors.white),
          tooltip: 'Archived batches',
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CriteriaDashboard(),
              ),
            );
          },
          icon: const Icon(Icons.fact_check_outlined, color: Colors.white),
          tooltip: 'Criteria dashboard',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
          tooltip: 'My account',
          onSelected: (value) {
            if (value == "logout") {
              _logout();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: "logout",
              child: Text("Logout"),
            ),
          ],
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateBatchDialog,
        backgroundColor: AdminMobilePalette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Batch'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError.isNotEmpty
              ? AdminMobileBody(
                  children: [
                    AdminMobileCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminMobileBadge('Load Error'),
                          const SizedBox(height: 14),
                          Text(
                            _loadError,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AdminMobilePalette.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pull to retry by reopening the page or use the app again after the server is ready.',
                            style: TextStyle(
                              color: AdminMobilePalette.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: adminActionButtonStyle(),
                            onPressed: _refreshData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
          : AdminMobileBody(
              children: [
                AdminMobileCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminMobileBadge('Batch Management'),
                      const SizedBox(height: 14),
                      const Text(
                        'Active Batches',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AdminMobilePalette.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _batches.isEmpty
                            ? 'No batches yet. Add your first batch to get started.'
                            : '${_batches.length} active batch${_batches.length == 1 ? '' : 'es'} ready for assessment.',
                        style: const TextStyle(
                          color: AdminMobilePalette.muted,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                _BatchesView(
                  batches: _batches,
                  onOpenBatch: (batch) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _BatchDetailScreen(
                          batch: batch,
                          onArchive: _archiveBatch,
                          onUpdateStatus: _updateTraineeStatus,
                        ),
                      ),
                    );
                    await _fetchBatches();
                  },
                  onArchiveBatch: _archiveBatch,
                  onEditBatch: _openEditBatchDialog,
                ),
              ],
            ),
    );
  }
}

class _BatchesView extends StatelessWidget {
  const _BatchesView({
    required this.batches,
    required this.onOpenBatch,
    required this.onArchiveBatch,
    required this.onEditBatch,
  });

  final List<_Batch> batches;
  final void Function(_Batch batch) onOpenBatch;
  final Future<bool> Function(_Batch batch) onArchiveBatch;
  final void Function(_Batch batch) onEditBatch;

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return const AdminMobileCard(
        child: Text('No batches yet. Tap Add Batch to create one.'),
      );
    }

    return Column(
      children: [
        for (final batch in batches) ...[
          _BatchCard(
            batch: batch,
            onOpenBatch: onOpenBatch,
            onArchiveBatch: onArchiveBatch,
            onEditBatch: onEditBatch,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: batches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final batch = batches[index];
        final assessedCount =
            batch.trainees.where((t) => t.result != "Pending").length;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onOpenBatch(batch),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          batch.trainingCenter,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => onEditBatch(batch),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit batch',
                      ),
                      IconButton(
                        onPressed: () => onArchiveBatch(batch),
                        icon: const Icon(Icons.archive_outlined),
                        tooltip: 'Archive batch',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    batch.name,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created ${_formatDate(batch.createdAt)} · '
                    '${batch.trainees.length} trainees · '
                    '$assessedCount assessed',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.onOpenBatch,
    required this.onArchiveBatch,
    required this.onEditBatch,
  });

  final _Batch batch;
  final void Function(_Batch batch) onOpenBatch;
  final Future<bool> Function(_Batch batch) onArchiveBatch;
  final void Function(_Batch batch) onEditBatch;

  @override
  Widget build(BuildContext context) {
    final assessedCount =
        batch.trainees.where((t) => t.result != "Pending").length;

    return AdminMobileCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onOpenBatch(batch),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    batch.trainingCenter,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AdminMobilePalette.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onEditBatch(batch),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit batch',
                ),
                IconButton(
                  onPressed: () => onArchiveBatch(batch),
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'Archive batch',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              batch.name,
              style: const TextStyle(color: AdminMobilePalette.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AdminMobileBadge('${batch.trainees.length} trainees'),
                AdminMobileBadge('$assessedCount assessed'),
                AdminMobileBadge(_formatDate(batch.createdAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveView extends StatelessWidget {
  const _ArchiveView({
    required this.records,
    required this.onUndoArchive,
  });

  final List<_ArchivedBatch> records;
  final void Function(_ArchivedBatch batch) onUndoArchive;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(
        child: Text('No archived batches yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = records[index];
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(record.batchName),
          subtitle: Text(
            '${record.trainingCenter}\nArchived: ${_formatDate(record.archivedAt)}',
          ),
          trailing: IconButton(
            onPressed: () => onUndoArchive(record),
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Undo archive',
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ArchivedBatchDetailScreen(batch: record),
              ),
            );
          },
        );
      },
    );
  }
}

class _ArchiveScreen extends StatelessWidget {
  const _ArchiveScreen({
    required this.records,
    required this.onUndoArchive,
  });

  final List<_ArchivedBatch> records;
  final void Function(_ArchivedBatch batch) onUndoArchive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Batches'),
      ),
      body: _ArchiveView(records: records, onUndoArchive: onUndoArchive),
    );
  }
}

class _TraineeReportView extends StatelessWidget {
  const _TraineeReportView({required this.batches});

  final List<_Batch> batches;

  bool _isCompleted(Trainee trainee) {
    return trainee.status == "Competent" && trainee.result == "Assessed";
  }

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return const Center(
        child: Text('No batches yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: batches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final batch = batches[index];
        final completed =
            batch.trainees.where(_isCompleted).toList(growable: false);
        final total = batch.trainees.length;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.trainingCenter,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  batch.name,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  'Completed competencies: ${completed.length}/$total',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                if (completed.isEmpty)
                  const Text(
                    'No trainees have completed competencies yet.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  ...completed.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t.name)),
                          Text(
                            t.status,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BatchDetailScreen extends StatefulWidget {
  const _BatchDetailScreen({
    required this.batch,
    required this.onArchive,
    required this.onUpdateStatus,
  });

  final _Batch batch;
  final Future<bool> Function(_Batch batch) onArchive;
  final Future<void> Function(Trainee trainee) onUpdateStatus;

  @override
  State<_BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _ArchivedBatchDetailScreen extends StatelessWidget {
  const _ArchivedBatchDetailScreen({required this.batch});

  final _ArchivedBatch batch;

  Future<_ExportAction?> _pickExportAction(BuildContext context) {
    return showDialog<_ExportAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Export Report"),
        content: const Text("Choose how you want to send the report."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ExportAction.share),
            child: const Text("Share to Any App"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 21),
            ),
            onPressed: () => Navigator.pop(context, _ExportAction.email),
            child: const Text("Email to TESDA"),
          ),
        ],
      ),
    );
  }

  Future<void> _exportArchivedBatchReport(BuildContext context) async {
    try {
      final assessed = batch.trainees.where((t) => t.result != "Pending").toList();
      if (assessed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No assessed trainees to export.")),
        );
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln("Archived Batch Report");
      buffer.writeln("Training Center,${_csvEscape(batch.trainingCenter)}");
      buffer.writeln("Batch,${_csvEscape(batch.batchName)}");
      buffer.writeln("Trainee,First,MI,Result,Status,Assessed Date");
      for (final trainee in assessed) {
        final parts = _splitName(trainee.name);
        buffer.writeln(
          [
            _csvEscape(parts[0]),
            _csvEscape(parts[1]),
            _csvEscape(parts[2]),
            _csvEscape(trainee.result),
            _csvEscape(trainee.status),
            _csvEscape(trainee.assessedDate),
          ].join(","),
        );
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        "${dir.path}/archived_batch_${batch.id}_${DateTime.now().millisecondsSinceEpoch}.csv",
      );
      await file.writeAsString(buffer.toString());
      final action = await _pickExportAction(context);
      if (action == null) return;
      if (action == _ExportAction.share) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: "Archived batch assessment report",
          text: "Archived batch assessment report",
        );
        return;
      }
        final email = Email(
          subject: "Archived batch assessment report",
          body: "Please see the attached archived batch assessment report.",
          attachmentPaths: [file.path],
          cc: [kTesdaCcEmail],
          isHTML: false,
        );
        try {
          await FlutterEmailSender.send(email);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not open email app: $e")),
          );
        }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assessedCount =
        batch.trainees.where((t) => t.result != "Pending").length;
    return Scaffold(
      appBar: AppBar(
        title: Text(batch.batchName),
        actions: [
          if (assessedCount > 0)
            IconButton(
              onPressed: () => _exportArchivedBatchReport(context),
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export batch report',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.trainingCenter,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text('Archived: ${_formatDate(batch.archivedAt)}'),
                  const SizedBox(height: 6),
                  Text('Trainees: ${batch.trainees.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Trainees',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (batch.trainees.isEmpty)
            const Text('No trainees found in this archived batch.')
          else
            ...batch.trainees.map(
              (t) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    '${t.status} · ${t.result}'
                    '${t.assessedDate.isNotEmpty ? " · Assessed: ${t.assessedDate}" : ""}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BatchDetailScreenState extends State<_BatchDetailScreen> {
  Future<_ExportAction?> _pickExportAction() async {
    if (!mounted) return null;
    return showDialog<_ExportAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Export Report"),
        content: const Text("Choose how you want to send the report."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ExportAction.share),
            child: const Text("Share to Any App"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 21),
            ),
            onPressed: () => Navigator.pop(context, _ExportAction.email),
            child: const Text("Email to TESDA"),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBatchReport() async {
    try {
      final assessed = widget.batch.trainees.where((t) => t.result != "Pending").toList();
      if (assessed.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No assessed trainees to export.")),
        );
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln("Batch Report");
      buffer.writeln("Training Center,${_csvEscape(widget.batch.trainingCenter)}");
      buffer.writeln("Batch,${_csvEscape(widget.batch.name)}");
      buffer.writeln("Trainee,First,MI,Result,Status,Assessed Date");
      for (final trainee in assessed) {
        final parts = _splitName(trainee.name);
        buffer.writeln(
          [
            _csvEscape(parts[0]),
            _csvEscape(parts[1]),
            _csvEscape(parts[2]),
            _csvEscape(trainee.result),
            _csvEscape(trainee.status),
            _csvEscape(trainee.assessedDate),
          ].join(","),
        );
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        "${dir.path}/batch_report_${widget.batch.id}_${DateTime.now().millisecondsSinceEpoch}.csv",
      );
      await file.writeAsString(buffer.toString());
      final action = await _pickExportAction();
      if (action == null) return;
      if (action == _ExportAction.share) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: "Batch assessment report",
          text: "Batch assessment report",
        );
        return;
      }
        final email = Email(
          subject: "Batch assessment report",
          body: "Please see the attached batch assessment report.",
          attachmentPaths: [file.path],
          cc: [kTesdaCcEmail],
          isHTML: false,
        );
        try {
          await FlutterEmailSender.send(email);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not open email app: $e")),
          );
        }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assessedCount =
        widget.batch.trainees.where((t) => t.result != "Pending").length;
    final allAssessed = assessedCount == widget.batch.trainees.length;
    final totalCount = widget.batch.trainees.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batch.trainingCenter),
        actions: [
          if (assessedCount > 0)
            IconButton(
              onPressed: _exportBatchReport,
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export batch report',
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.batch.trainees.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.batch.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trainees listed: $totalCount',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Assessed: $assessedCount',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }
          final trainee = widget.batch.trainees[index - 1];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              title: Text(trainee.name),
              subtitle: Text(
                '${trainee.status} - ${trainee.result}'
                '${trainee.assessedDate.isNotEmpty ? " · Assessed: ${trainee.assessedDate}" : ""}',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AssessmentScreen(trainee: trainee),
                    ),
                  );
                  await widget.onUpdateStatus(trainee);
                  setState(() {});
                },
                child: Text(trainee.assessed ? 'Review' : 'Assess'),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: allAssessed
                ? () async {
                    final ok = await widget.onArchive(widget.batch);
                    if (ok && mounted) {
                      Navigator.pop(context);
                    }
                  }
                : null,
            child: Text(
              allAssessed
                  ? 'Finish Batch Assessment ($assessedCount assessed)'
                  : 'Assess all trainees to finish batch',
            ),
          ),
        ),
      ),
    );
  }
}

class _Batch {
  _Batch({
    this.id = 0,
    required this.name,
    required this.trainingCenter,
    required this.createdAt,
    required this.trainees,
  });

  final int id;
  final String name;
  final String trainingCenter;
  final DateTime createdAt;
  final List<Trainee> trainees;
}

class Trainee {
  Trainee({
    required this.id,
    required this.name,
    this.trainingCenter = '',
    this.assessed = false,
    this.status = 'Not Yet Competent',
    this.result = 'Pending',
    this.score = 0,
    this.assessedDate = '',
  });

  final int id;
  String name;
  String trainingCenter;
  bool assessed;
  String status;
  String result;
  int score;
  String assessedDate;
}

class _ArchivedBatch {
  _ArchivedBatch({
    required this.id,
    required this.batchName,
    required this.trainingCenter,
    required this.archivedAt,
    required this.trainees,
  });

  final int id;
  final String batchName;
  final String trainingCenter;
  final DateTime archivedAt;
  final List<_ArchivedTrainee> trainees;
}

class _ArchivedTrainee {
  _ArchivedTrainee({
    required this.name,
    required this.status,
    required this.result,
    required this.assessedDate,
  });

  final String name;
  final String status;
  final String result;
  final String assessedDate;
}

int _parseId(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

String _csvEscape(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

List<String> _splitName(String raw) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty) {
    return ["", "", ""];
  }
  final parts = cleaned.split(",");
  final lastName = parts.isNotEmpty ? parts[0].trim() : cleaned;
  final rest = parts.length > 1 ? parts.sublist(1).join(",").trim() : "";
  if (rest.isEmpty) {
    return [lastName, "", ""];
  }
  final restParts = rest.split(RegExp(r"\s+")).where((p) => p.isNotEmpty).toList();
  final first = restParts.isNotEmpty ? restParts[0] : "";
  final mi = restParts.length > 1 ? restParts.sublist(1).join(" ") : "";
  return [lastName, first, mi];
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
