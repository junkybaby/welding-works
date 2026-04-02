import 'dart:convert';
import 'dart:io';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welding_works/admin_mobile_ui.dart';
import 'package:welding_works/app_config.dart';
import 'package:welding_works/auth_session.dart';
import 'package:welding_works/trainer_dashboard.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key, required this.trainee});

  final Trainee trainee;

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  static const String _tesdaCcEmail = "tesdaweldingworksservice@gmail.com";
  static const String _hideYoloInstructionsKey = "hide_yolo_instructions";
  bool _isLoading = true;
  bool _isSaving = false;
  String _error = "";
  String _demoImageUrl = "";
  String _demoOriginalImageUrl = "";
  String _demoAnnotatedImageUrl = "";
  String _demoLabel = "";
  String _demoConfidence = "";
  String _demoReason = "";
  List<_DemoDetection> _demoDetections = [];
  bool _hasPerformanceAssessment = false;
  final Map<String, int> _criteriaScores = {};
  bool _criteriaLoaded = false;
  String _oralStatus = 'pending';
  String _writtenStatus = 'pending';
  String _demoStatus = 'pending';
  String _oralDate = '-';
  String _writtenDate = '-';
  String _demoDate = '-';
  String _summaryStatus = '';
  String _summaryResult = '';
  bool _syncingDemoStatus = false;
  final ImagePicker _picker = ImagePicker();
  List<_CriteriaSection> _assessmentSections = [];
  final List<_CriteriaSection> _fallbackSections = [
    _CriteriaSection(
      title: "Perform root pass",
      items: [
        "1.1 Root pass is performed in accordance with WPS and/or client specifications.",
        "1.2 Task is performed in accordance with company or industry requirement and safety procedure.",
        "1.3 Weld is visually checked for defects and repaired, as required.",
        "1.4 Weld is visually acceptable in accordance with applicable codes and standards.",
      ],
    ),
    _CriteriaSection(
      title: "Clean root pass",
      items: [
        "2.1 Root pass is cleaned and free from defects and discontinuities.",
        "2.2 Task is performed in accordance with approved WPS.",
      ],
    ),
    _CriteriaSection(
      title: "Weld subsequent/filling passes",
      items: [
        "3.1 Subsequent/ filling passes is performed in accordance with approved WPS.",
        "3.2 Weld visually is checked for defects and repaired, as required.",
        "3.3 Weld is visually acceptable in accordance with applicable codes and standards.",
      ],
    ),
    _CriteriaSection(
      title: "Perform capping",
      items: [
        "4.1 Capping is performed in accordance with approved WPS and/or client specifications.",
        "4.2 Weld is visually checked for defects and repaired, as required.",
        "4.3 Weld is visually acceptable in accordance with applicable codes and standards.",
      ],
    ),
    _CriteriaSection(
      title: "Defects (Surface Level)",
      isSurfaceDefects: true,
      items: [
        "Porosity",
        "Undercut",
        "Arc Strike",
        "Spatters",
        "Burn Through",
        "Crater cracks",
        "Cracks",
        "Pinholes/Blowholes",
        "Overlap",
        "Misalignment",
      ],
    ),
    _CriteriaSection(
      title: "Defects (Non-Surface Level)",
      items: [
        "Distortion",
        "Slag inclusion",
        "Concavity/convexity",
        "Degree of reinforcement",
        "Lack of Fusion",
        "Under Fill",
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAssessmentCriteria().then((_) => _fetchProgress());
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return "-";
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  int _oralPoints() => _oralStatus == 'competent' ? 25 : 0;
  int _writtenPoints() => _writtenStatus == 'competent' ? 25 : 0;
  static const int _demoMaxPoints = 50;

  int _demoPoints() {
    final sectionItems = _assessmentSections.fold<int>(
      0,
      (sum, section) => sum + section.items.length,
    );
    final totalItems = sectionItems > 0 ? sectionItems : _criteriaScores.length;
    if (totalItems == 0) return 0;
    final scored = _criteriaScores.entries.fold<int>(0, (sum, entry) {
      final isDefect = _isDefectItem(entry.key);
      if (isDefect) {
        return sum + (entry.value == 0 ? 1 : 0);
      }
      return sum + (entry.value == 1 ? 1 : 0);
    });
    final ratio = scored / totalItems;
    return (ratio * _demoMaxPoints).round();
  }

  int _totalPoints() => _oralPoints() + _writtenPoints() + _demoPoints();

  String _totalCompetencyLabel() {
    final total = _totalPoints();
    return total >= 75 ? "Competent" : "Not Yet Competent";
  }

  String _effectiveDemoStatus() {
    return _totalPoints() >= 75 ? 'competent' : 'not_yet_competent';
  }

  bool get _assessmentComplete =>
      _oralStatus != 'pending' &&
      _writtenStatus != 'pending' &&
      _demoStatus != 'pending';

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

  Future<void> _exportTraineeReport() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln("Trainee Report");
      buffer.writeln("Trainee,${widget.trainee.name}");
      buffer.writeln("Training Center,${widget.trainee.trainingCenter}");
      buffer.writeln("Oral,${_labelFor(_oralStatus)},${_oralDate},${_oralPoints()}");
      buffer.writeln("Written,${_labelFor(_writtenStatus)},${_writtenDate},${_writtenPoints()}");
      buffer.writeln("Demo,${_labelFor(_effectiveDemoStatus())},${_demoDate},${_demoPoints()}");
      buffer.writeln("Total Points,${_totalPoints()}");
      buffer.writeln("Result,${_totalCompetencyLabel()}");

      final dir = await getTemporaryDirectory();
      final file = File(
        "${dir.path}/trainee_report_${widget.trainee.id}_${DateTime.now().millisecondsSinceEpoch}.csv",
      );
      await file.writeAsString(buffer.toString());
      final action = await _pickExportAction();
      if (action == null) return;
      if (action == _ExportAction.share) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: "Trainee assessment report",
          text: "Trainee assessment report",
        );
        return;
      }
        final email = Email(
          subject: "Trainee assessment report",
          body: "Please see the attached trainee assessment report.",
          attachmentPaths: [file.path],
          cc: [_tesdaCcEmail],
          isHTML: false,
        );
        try {
          await FlutterEmailSender.send(email);
        } catch (e) {
          if (!mounted) return;
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

  String _resolveImageUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return "";
    final normalizedSlashes = trimmed.replaceAll("\\", "/");
    final parsed = Uri.tryParse(normalizedSlashes);
    final base = Uri.parse(AppConfig.baseHost);

    if (parsed != null && parsed.hasScheme) {
      return normalizedSlashes;
    }

    final isDemoAsset =
        normalizedSlashes.startsWith("/demo_archive/") ||
        normalizedSlashes.startsWith("/yolo_uploads/") ||
        normalizedSlashes.startsWith("/yolo_outputs/") ||
        normalizedSlashes.startsWith("/welding_api/demo_archive/") ||
        normalizedSlashes.startsWith("/welding_api/yolo_uploads/") ||
        normalizedSlashes.startsWith("/welding_api/yolo_outputs/");

    if (isDemoAsset) {
      final assetPath = normalizedSlashes.startsWith("/welding_api/")
          ? normalizedSlashes
          : "/welding_api$normalizedSlashes";
      final encodedPath = Uri.encodeQueryComponent(assetPath);
      return "${AppConfig.weldingApi}/demo_asset.php?path=$encodedPath";
    }

    if (normalizedSlashes.startsWith("/")) {
      return "${base.scheme}://${base.host}${base.hasPort ? ":${base.port}" : ""}$normalizedSlashes";
    }

    return "${AppConfig.weldingApi}/$normalizedSlashes";
  }

  bool get _canAssessDemo =>
      _oralStatus == 'competent' && _writtenStatus == 'competent';

  String _labelFor(String status) {
    switch (status) {
      case 'competent':
        return 'Competent';
      case 'not_yet_competent':
        return 'Not Yet Competent';
      default:
        return 'Pending';
    }
  }

  String _formatConfidencePercentage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "";
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return trimmed;
    final percent = parsed <= 1 ? parsed * 100 : parsed;
    return "${percent.toStringAsFixed(2)}%";
  }

  String _demoOverallConfidence() {
    final misalignmentConfidences = _demoDetections
        .where((detection) => _normalizedDetectionKey(detection.label) == "misalignment")
        .map((detection) => double.tryParse(detection.confidence.trim()))
        .whereType<double>()
        .map((value) => value <= 1 ? value * 100 : value)
        .toList();
    if (misalignmentConfidences.isNotEmpty) {
      final strongestMisalignment = misalignmentConfidences.reduce(
        (current, next) => current >= next ? current : next,
      );
      return "${strongestMisalignment.toStringAsFixed(2)}%";
    }

    final confidences = _demoDetections
        .where((detection) => _normalizedDetectionKey(detection.label) != "good welding")
        .map((detection) => double.tryParse(detection.confidence.trim()))
        .whereType<double>()
        .map((value) => value <= 1 ? value * 100 : value)
        .toList();
    if (confidences.isEmpty) {
      return _formatConfidencePercentage(_demoConfidence);
    }
    final total = confidences.reduce((sum, value) => sum + value);
    final average = total / confidences.length;
    return "${average.toStringAsFixed(2)}%";
  }

  String _normalizeCriteriaText(String value) {
    final lower = value.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r"[^a-z0-9]+"), " ").trim();
    return cleaned.replaceAll(RegExp(r"\s+"), " ");
  }

  bool _isSurfaceDefectsCategory(String category) {
    final normalized = _normalizeCriteriaText(category);
    return normalized.contains("defects") && normalized.contains("surface");
  }

  Future<void> _fetchProgress() async {
    setState(() {
      _isLoading = true;
      _error = "";
    });
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/get_assessment_progress.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "batch_trainee_id": widget.trainee.id,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data["status"] != "success") {
        throw Exception(data is Map ? (data["message"] ?? "Load failed") : "Load failed");
      }
      final progress = (data["progress"] ?? {}) as Map;
      setState(() {
        _oralStatus = (progress["oral_status"] ?? "pending").toString();
        _writtenStatus = (progress["written_status"] ?? "pending").toString();
        _demoStatus = (progress["demo_status"] ?? "pending").toString();
        _oralDate = _formatDate(progress["oral_date_completed"]?.toString());
        _writtenDate = _formatDate(progress["written_date_completed"]?.toString());
        _demoDate = _formatDate(progress["demo_date_completed"]?.toString());
        final annotated = _resolveImageUrl((progress["demo_annotated_image_url"] ?? "").toString());
        final original = _resolveImageUrl((progress["demo_image_url"] ?? "").toString());
        _demoAnnotatedImageUrl = annotated;
        _demoOriginalImageUrl = original;
        _demoImageUrl = annotated.isNotEmpty ? annotated : original;
        _demoLabel = (progress["demo_label"] ?? "").toString();
        _demoConfidence = (progress["demo_confidence"] ?? "").toString();
        _demoReason = (progress["demo_reason"] ?? "").toString();
        final savedDetections = (progress["demo_detections_json"] ?? "").toString();
        _demoDetections = [];
        if (savedDetections.trim().isNotEmpty) {
          try {
            final decodedDetections = jsonDecode(savedDetections);
            if (decodedDetections is List) {
              _demoDetections = decodedDetections
                  .whereType<Map>()
                  .map(
                    (item) => _DemoDetection(
                      label: (item["label"] ?? "").toString(),
                      confidence: (item["confidence"] ?? "").toString(),
                    ),
                  )
                  .where((item) => item.label.trim().isNotEmpty)
                  .toList();
            }
          } catch (_) {}
        }
        final saved = (progress["performance_criteria_json"] ?? "").toString();
        if (saved.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(saved);
            if (decoded is Map) {
              _criteriaScores
                ..clear()
                ..addAll(decoded.map((key, value) => MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0)));
              _hasPerformanceAssessment = _criteriaScores.isNotEmpty;
            }
          } catch (_) {}
        }
      });
      await _syncBatchTraineeStatus();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAssessmentCriteria() async {
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/criteria_list.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({}),
      );
      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data["status"] != "success") {
        throw Exception("Load failed");
      }
      final list = data["criteria"];
      if (list is! List) {
        throw Exception("Load failed");
      }
      final items = <_CriteriaItem>[];
      for (final raw in list) {
        if (raw is Map) {
          items.add(_CriteriaItem.fromMap(raw));
        }
      }

      final assessmentItems = items.where((i) => i.type == "assessment").toList();
      if (assessmentItems.isEmpty) {
        setState(() {
          _assessmentSections = List<_CriteriaSection>.from(_fallbackSections);
          _criteriaLoaded = true;
        });
        return;
      }

      final Map<String, List<String>> grouped = {};
      for (final item in assessmentItems) {
        grouped.putIfAbsent(item.category, () => []).add(item.title);
      }

      final categoryOrder = [
        "Perform root pass",
        "Clean root pass",
        "Weld subsequent/filling passes",
        "Perform capping",
        "Defects (Surface Level)",
        "Defects (Non-Surface Level)",
      ];
      final sections = <_CriteriaSection>[];
      for (final category in categoryOrder) {
        final titles = grouped[category] ?? [];
        if (titles.isEmpty) continue;
        sections.add(
          _CriteriaSection(
            title: category,
            isSurfaceDefects: _isSurfaceDefectsCategory(category),
            items: titles,
          ),
        );
      }
      for (final entry in grouped.entries) {
        if (categoryOrder.contains(entry.key)) continue;
        sections.add(_CriteriaSection(title: entry.key, items: entry.value));
      }

      setState(() {
        _assessmentSections = sections.isEmpty
            ? List<_CriteriaSection>.from(_fallbackSections)
            : sections;
        _criteriaLoaded = true;
      });
      await _syncBatchTraineeStatus();
    } catch (_) {
      setState(() {
        _assessmentSections = List<_CriteriaSection>.from(_fallbackSections);
        _criteriaLoaded = true;
      });
      await _syncBatchTraineeStatus();
    }
  }

  Future<void> _updateAssessment({
    required String type,
    required String status,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/update_assessment_progress.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "batch_trainee_id": widget.trainee.id,
          "assessment_type": type.toLowerCase(),
          "status": status,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data["status"] != "success") {
        final message = data is Map ? (data["message"] ?? "Update failed") : "Update failed";
        throw Exception(message);
      }
      if (!mounted) return;
      await _fetchProgress();
      await _syncBatchTraineeStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncBatchTraineeStatus() async {
    if (!_criteriaLoaded) {
      return;
    }
    final allDone = _oralStatus != 'pending' &&
        _writtenStatus != 'pending' &&
        _demoStatus != 'pending';
    final summaryResult = allDone ? 'Assessed' : 'Pending';
    final summaryStatus = _totalPoints() >= 75 ? 'Competent' : 'Not Yet Competent';
    if (summaryStatus == _summaryStatus && summaryResult == _summaryResult) {
      return;
    }

    _summaryResult = summaryResult;
    _summaryStatus = summaryStatus;
    widget.trainee.result = summaryResult;
    widget.trainee.status = summaryStatus;

    try {
      final url = Uri.parse("${AppConfig.weldingApi}/update_trainee_status.php");
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "batch_trainee_id": widget.trainee.id,
          "status": summaryStatus,
          "result": summaryResult,
        }),
      );
    } catch (_) {
      // Ignore sync errors; will retry on next fetch.
    }

    final desiredDemo = _totalPoints() >= 75 ? 'competent' : 'not_yet_competent';
    final needsDemoDate = desiredDemo == 'competent' && (_demoDate == '-' || _demoDate.isEmpty);
    if (( _demoStatus != desiredDemo || needsDemoDate) && !_syncingDemoStatus) {
      _syncingDemoStatus = true;
      try {
        if (needsDemoDate && mounted) {
          setState(() {
            _demoDate = _formatDate(DateTime.now().toIso8601String());
          });
        }
        await _updateAssessment(type: 'Demo', status: desiredDemo);
      } finally {
        _syncingDemoStatus = false;
      }
    }
  }

  Future<void> _uploadAndAssessDemo(XFile imageFile) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final uri = Uri.parse("${AppConfig.weldingApi}/assess_demo_yolo.php");
      final request = http.MultipartRequest("POST", uri)
        ..fields["batch_trainee_id"] = widget.trainee.id.toString()
        ..files.add(await http.MultipartFile.fromPath("demo_image", imageFile.path));

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      final data = jsonDecode(body);
      if (data is! Map || data["status"] != "success") {
        final message = data is Map ? (data["message"] ?? "Assessment failed") : "Assessment failed";
        throw Exception(message);
      }
      _demoLabel = (data["label"] ?? "").toString();
      _demoConfidence = (data["confidence"] ?? "").toString();
      _demoReason = (data["reason"] ?? "").toString();
      final detectionsRaw = data["detections"];
      _demoDetections = detectionsRaw is List
          ? detectionsRaw
              .whereType<Map>()
              .map(
                (item) => _DemoDetection(
                  label: (item["label"] ?? "").toString(),
                  confidence: (item["confidence"] ?? "").toString(),
                ),
              )
              .where((item) => item.label.trim().isNotEmpty)
              .toList()
          : [];
      final annotated = _resolveImageUrl((data["annotated_image_url"] ?? "").toString());
      final original = _resolveImageUrl((data["original_image_url"] ?? "").toString());
      _demoAnnotatedImageUrl = annotated;
      _demoOriginalImageUrl = original;
      _demoImageUrl = annotated.isNotEmpty ? annotated : original;
      _resetCriteriaScores();
      if (_isGoodWeldingResult()) {
        _applySurfaceDefectsScore(0);
      } else {
        _applyDetectedSurfaceDefects();
      }

      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "YOLO: ${_demoHeadlineLabel().isEmpty ? "No defect label" : _demoHeadlineLabel()}",
          ),
        ),
      );
      if (!mounted) return;
      bool continueToCriteria = false;
      if ((_demoAnnotatedImageUrl.isNotEmpty || _demoOriginalImageUrl.isNotEmpty) && mounted) {
        continueToCriteria = await showDialog<bool>(
          context: context,
          builder: (context) {
            bool showAnnotation = _demoAnnotatedImageUrl.isNotEmpty;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                final screenSize = MediaQuery.of(context).size;
                final imageUrl = showAnnotation && _demoAnnotatedImageUrl.isNotEmpty
                    ? _demoAnnotatedImageUrl
                    : (_demoOriginalImageUrl.isNotEmpty ? _demoOriginalImageUrl : _demoImageUrl);
                final detectionLegend = _demoDetectionLegend();
                final fallbackDetectionLegend = _demoDetectionFallbackLegend();
                return AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  title: const Text("Weld Image with Annotation"),
                  content: SizedBox(
                    width: 320,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: screenSize.height * 0.72,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_demoAnnotatedImageUrl.isNotEmpty && _demoOriginalImageUrl.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("Annotation"),
                                  Switch(
                                    value: showAnnotation,
                                    onChanged: (value) => setDialogState(() => showAnnotation = value),
                                  ),
                                ],
                              ),
                            ),
                          GestureDetector(
                            onTap: () => _showDemoPreview(
                              originalImageUrl: _demoOriginalImageUrl,
                              annotatedImageUrl: _demoAnnotatedImageUrl,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: screenSize.height * 0.34,
                                ),
                                child: InteractiveViewer(
                                  minScale: 0.8,
                                  maxScale: 4.0,
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Text("Unable to load image."),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_demoConfidence.isNotEmpty ||
                              _demoReason.isNotEmpty ||
                              _demoDetectionsSummary().isNotEmpty ||
                              detectionLegend.isNotEmpty ||
                              fallbackDetectionLegend.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_demoOverallConfidence().isNotEmpty)
                                      Text(
                                        "Confidence: ${_demoOverallConfidence()}",
                                      ),
                                    if (detectionLegend.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      ...detectionLegend,
                                    ] else if (fallbackDetectionLegend.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      ...fallbackDetectionLegend,
                                    ] else if (_demoDetectionsSummary().isNotEmpty)
                                      Text("Detected defects: ${_demoDetectionsSummary()}"),
                                    if (_demoReason.isNotEmpty) Text("Reason: $_demoReason"),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Next"),
                    ),
                  ],
                );
              },
            );
          },
        ) ?? false;
      } else {
        continueToCriteria = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Weld Image with Annotation"),
            content: Text(
              _demoLabel.isEmpty ? "Result ready." : "${_demoLabel} detected.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Next"),
              ),
            ],
          ),
        ) ?? false;
      }
      if (!continueToCriteria || !mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showBlockingLoader("Opening assessment criteria...");
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      final updated = await _showPerformanceCriteriaDialog();
      if (updated) {
        await _savePerformanceCriteria();
        await _syncBatchTraineeStatus();
      }
      await _fetchProgress();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("YOLO failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _applyAllCriteriaScore(int score) {
    if (_assessmentSections.isEmpty) return;
    for (final section in _assessmentSections) {
      for (final item in section.items) {
        _criteriaScores[item] = score;
      }
    }
    _hasPerformanceAssessment = true;
  }

  void _applySurfaceDefectsScore(int score) {
    if (_assessmentSections.isEmpty) return;
    for (final section in _assessmentSections) {
      if (!section.isSurfaceDefects) continue;
      for (final item in section.items) {
        _criteriaScores[item] = score;
      }
    }
    _hasPerformanceAssessment = true;
  }

  bool _isGoodWeldingResult() {
    final labels = <String>{
      _demoLabel.trim().toLowerCase(),
      ..._demoDetections.map((detection) => detection.label.trim().toLowerCase()),
    }..remove("");
    if (labels.isEmpty) {
      return false;
    }
    return labels.every(
      (label) => label == "good welding" || label == "good" || label == "ok",
    );
  }

  String _normalizedDetectionKey(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.contains("good welding") || normalized == "good" || normalized == "ok") {
      return "good welding";
    }
    if (normalized.contains("porosity")) {
      return "porosity";
    }
    if (normalized.contains("misalignment")) {
      return "misalignment";
    }
    if (normalized.contains("spatter")) {
      return "spatter";
    }
    if (normalized.contains("blowhole") || normalized.contains("pinhole")) {
      return "blowhole";
    }
    return normalized;
  }

  String _displayDetectionLabel(String key, {int count = 1}) {
    return switch (key) {
      "good welding" => "Good Welding",
      "porosity" => "Porosity",
      "misalignment" => "Misalignment",
      "spatter" => count > 1 ? "Spatters" : "Spatter",
      "blowhole" => count > 1 ? "Blowholes" : "Blowhole",
      _ => key.isEmpty ? "" : "${key[0].toUpperCase()}${key.substring(1)}",
    };
  }

  String _demoHeadlineLabel() {
    final key = _normalizedDetectionKey(_demoLabel);
    if (key.isEmpty) return "";
    return _displayDetectionLabel(key);
  }

  String _demoDetectionsSummary() {
    final counts = <String, int>{};
    for (final detection in _demoDetections) {
      final key = _normalizedDetectionKey(detection.label);
      if (key.isEmpty || key == "good welding") continue;
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return "";

    final orderedKeys = ["misalignment", "blowhole", "porosity", "spatter"];
    final parts = <String>[];
    for (final key in orderedKeys) {
      final count = counts.remove(key);
      if (count == null) continue;
      final label = _displayDetectionLabel(key, count: count);
      parts.add(count > 1 ? "$label ($count)" : label);
    }
    for (final entry in counts.entries) {
      final label = _displayDetectionLabel(entry.key, count: entry.value);
      parts.add(entry.value > 1 ? "$label (${entry.value})" : label);
    }
    return parts.join(", ");
  }

  Color _detectionColor(String key) {
    return switch (key) {
      "spatter" => const Color(0xFF2DD4BF),
      "blowhole" => const Color(0xFFFACC15),
      "misalignment" => const Color(0xFFF97316),
      "porosity" => const Color(0xFF38BDF8),
      "good welding" => const Color(0xFF22C55E),
      _ => const Color(0xFF94A3B8),
    };
  }

  List<Widget> _demoDetectionLegend() {
    final grouped = <String, List<_DemoDetection>>{};
    for (final detection in _demoDetections) {
      final key = _normalizedDetectionKey(detection.label);
      if (key.isEmpty || key == "good welding") continue;
      grouped.putIfAbsent(key, () => []).add(detection);
    }
    if (grouped.isEmpty) return const [];

    final orderedKeys = ["spatter", "blowhole", "misalignment", "porosity"];
    final widgets = <Widget>[
      const Text(
        "Detected defects",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 6),
    ];

    for (final key in orderedKeys) {
      final items = grouped.remove(key);
      if (items == null || items.isEmpty) continue;
      widgets.add(_buildDetectionLegendRow(key, items));
      widgets.add(const SizedBox(height: 6));
    }
    for (final entry in grouped.entries) {
      if (entry.value.isEmpty) continue;
      widgets.add(_buildDetectionLegendRow(entry.key, entry.value));
      widgets.add(const SizedBox(height: 6));
    }

    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  List<String> _savedDetectedDefectKeys() {
    final keys = <String>[];
    for (final section in _assessmentSections) {
      if (!section.isSurfaceDefects && !_isSurfaceDefectsCategory(section.title)) {
        continue;
      }
      for (final item in section.items) {
        if ((_criteriaScores[item] ?? 0) != 1) continue;
        final key = _criterionForDetectionLabel(item);
        if (key != null && !keys.contains(key)) {
          keys.add(key);
        }
      }
    }
    return keys;
  }

  List<Widget> _demoDetectionFallbackLegend() {
    final keys = _savedDetectedDefectKeys();
    if (keys.isEmpty) return const [];

    final orderedKeys = ["spatter", "blowhole", "misalignment", "porosity"];
    final ordered = <String>[
      ...orderedKeys.where(keys.contains),
      ...keys.where((key) => !orderedKeys.contains(key)),
    ];

    final widgets = <Widget>[
      const Text(
        "Detected defects",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 6),
    ];

    for (final key in ordered) {
      widgets.add(_buildDetectionFallbackRow(key));
      widgets.add(const SizedBox(height: 6));
    }

    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  Widget _buildDetectionFallbackRow(String key) {
    final color = _detectionColor(key);
    final label = _displayDetectionLabel(key);
    final confidenceText = _demoOverallConfidence();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (confidenceText.isNotEmpty)
                  Text(
                    "Confidence: $confidenceText",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionLegendRow(String key, List<_DemoDetection> detections) {
    final color = _detectionColor(key);
    final label = _displayDetectionLabel(key, count: detections.length);
    final formattedConfidences = detections
        .map((detection) => _formatConfidencePercentage(detection.confidence))
        .where((confidence) => confidence.isNotEmpty)
        .toList();
    final confidenceText = formattedConfidences.isEmpty
        ? ""
        : formattedConfidences.toSet().length == 1
            ? formattedConfidences.first
            : formattedConfidences.join(", ");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (confidenceText.isNotEmpty)
                  Text(
                    "Confidence: $confidenceText",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "${detections.length}",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _criterionForDetectionLabel(String label) {
    final normalized = _normalizeCriteriaText(label);
    if (normalized.contains("porosity")) {
      return "porosity";
    }
    if (normalized.contains("misalignment")) {
      return "misalignment";
    }
    if (normalized.contains("spatter")) {
      return "spatter";
    }
    if (normalized.contains("blowhole") || normalized.contains("pinhole")) {
      return "blowhole";
    }
    return null;
  }

  bool _criterionMatchesItem(String criterionKey, String item) {
    final normalizedItem = _normalizeCriteriaText(item);
    return switch (criterionKey) {
      "porosity" =>
        normalizedItem.contains("porosity"),
      "misalignment" =>
        normalizedItem.contains("misalignment"),
      "spatter" =>
        normalizedItem.contains("spatter") || normalizedItem.contains("spatters"),
      "blowhole" =>
        normalizedItem.contains("blowhole") ||
        normalizedItem.contains("blowholes") ||
        normalizedItem.contains("pinhole") ||
        normalizedItem.contains("pinholes"),
      _ => false,
    };
  }

  void _applyDetectedSurfaceDefects() {
    if (_assessmentSections.isEmpty) return;
    _applySurfaceDefectsScore(0);
    final labels = <String>[
      _demoLabel,
      ..._demoDetections.map((detection) => detection.label),
    ];
    for (final label in labels) {
      final criterionKey = _criterionForDetectionLabel(label);
      if (criterionKey == null) continue;
      for (final section in _assessmentSections) {
        if (!section.isSurfaceDefects && !_isSurfaceDefectsCategory(section.title)) continue;
        for (final item in section.items) {
          if (_criterionMatchesItem(criterionKey, item)) {
            _criteriaScores[item] = 1;
          }
        }
      }
    }
    _hasPerformanceAssessment = true;
  }

  void _resetCriteriaScores() {
    _criteriaScores.clear();
    for (final section in _assessmentSections) {
      for (final item in section.items) {
        _criteriaScores[item] = 0;
      }
    }
    _hasPerformanceAssessment = true;
  }

  bool _isDefectItem(String item) {
    for (final section in _assessmentSections) {
      if (section.isSurfaceDefects || _isSurfaceDefectsCategory(section.title) || section.title.toLowerCase().contains("defects")) {
        if (section.items.contains(item)) return true;
      }
    }
    return false;
  }

  String _criteriaValueLabel(String item, int value) {
    final isDefect = _isDefectItem(item);
    if (isDefect) {
      return value == 1 ? "Seen" : "Not Seen";
    }
    return value == 1 ? "Performed" : "Not Performed";
  }

  Future<bool> _showPerformanceCriteriaDialog() async {
    final tempScores = Map<String, int>.from(_criteriaScores);
    for (final section in _assessmentSections) {
      for (final item in section.items) {
        tempScores.putIfAbsent(item, () => 0);
      }
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: const Text("Assessment Criteria"),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Select the appropriate result for each criteria.",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                ..._assessmentSections.map(
                  (section) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: section.title,
                            isDefect: section.title.toLowerCase().contains("defects"),
                          ),
                          const SizedBox(height: 8),
                          ...section.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: _CriteriaScoreField(
                                item: item,
                                initialValue: tempScores[item] ?? 0,
                                onChanged: (next) {
                                  tempScores[item] = next;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _criteriaScores
                  ..clear()
                  ..addAll(tempScores);
                _hasPerformanceAssessment = true;
              });
              _savePerformanceCriteria();
              Navigator.pop(context, true);
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _savePerformanceCriteria() async {
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/update_performance_criteria.php");
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "batch_trainee_id": widget.trainee.id,
          "criteria_scores": _criteriaScores,
        }),
      );
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _pickAndAssessDemoImage() async {
    await _openYoloInstructions();
    if (!mounted) return;
    final hasPriorDemo = _demoDate != '-' || _demoStatus != 'pending' || _demoImageUrl.isNotEmpty;
    if (hasPriorDemo) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reassess Demo'),
          content: const Text('A demo assessment already exists. Reassess and overwrite it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reassess'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Assess Demo with YOLO"),
        content: const Text("Choose image source"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text("Gallery"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text("Camera"),
          ),
        ],
      ),
    );

    if (source == null) return;
    final image = await _picker.pickImage(source: source, imageQuality: 90);
    if (image == null) return;
    if (!File(image.path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selected image file is unavailable.")),
      );
      return;
    }
    if (!_criteriaLoaded) {
      await _loadAssessmentCriteria();
    }
    await _showAssessingDialog();
    await _uploadAndAssessDemo(image);
  }

  Future<void> _showDemoPreview({
    required String originalImageUrl,
    required String annotatedImageUrl,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        bool showAnnotation = annotatedImageUrl.isNotEmpty;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenSize = MediaQuery.of(context).size;
            final imageUrl = showAnnotation && annotatedImageUrl.isNotEmpty
                ? annotatedImageUrl
                : (originalImageUrl.isNotEmpty ? originalImageUrl : annotatedImageUrl);
            final detectionLegend = _demoDetectionLegend();
            final fallbackDetectionLegend = _demoDetectionFallbackLegend();
            return AlertDialog(
              title: const Text("Demo Image Preview"),
              content: SizedBox(
                width: 360,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: screenSize.height * 0.78,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (annotatedImageUrl.isNotEmpty && originalImageUrl.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Annotation"),
                                Switch(
                                  value: showAnnotation,
                                  onChanged: (value) => setDialogState(() => showAnnotation = value),
                                ),
                              ],
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: screenSize.height * 0.46,
                              minHeight: 220,
                            ),
                            child: InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text("Unable to load demo image preview."),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_demoConfidence.isNotEmpty ||
                            _demoReason.isNotEmpty ||
                            _demoDetectionsSummary().isNotEmpty ||
                            detectionLegend.isNotEmpty ||
                            fallbackDetectionLegend.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          if (_demoOverallConfidence().isNotEmpty)
                            Text("Confidence: ${_demoOverallConfidence()}"),
                          if (detectionLegend.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...detectionLegend,
                          ] else if (fallbackDetectionLegend.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...fallbackDetectionLegend,
                          ] else if (_demoDetectionsSummary().isNotEmpty)
                            Text("Detected defects: ${_demoDetectionsSummary()}"),
                          if (_demoReason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text("Reason: $_demoReason"),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssessingDialog() async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text("Assessing weld with YOLO. Please wait..."),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockingLoader(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openYoloInstructions({
    bool forceShow = false,
    bool allowDontShowAgain = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hideYoloInstructionsKey);
    final trainerEmail = (await AuthSession.getEmail())?.trim().toLowerCase();
    final scopedHideKey = trainerEmail == null || trainerEmail.isEmpty
        ? _hideYoloInstructionsKey
        : "${_hideYoloInstructionsKey}_$trainerEmail";
    final hideInstructions = prefs.getBool(scopedHideKey) ?? false;
    if (allowDontShowAgain && hideInstructions && !forceShow) {
      return;
    }

    if (!mounted) return;
    var dontShowAgain = hideInstructions;
    var showPartTwo = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(showPartTwo ? "YOLO Assessment Guide" : "YOLO Capture Guide"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!showPartTwo) ...[
                  const Text(
                    "Part 1: For the best assessment results, follow these steps before taking the photo:",
                  ),
                  const SizedBox(height: 12),
                  const Text("1. Place the carbon steel weld plate flat on a stable surface."),
                  const SizedBox(height: 8),
                  const Text("2. Hold the camera directly above the weld to capture a clear top-view shot."),
                  const SizedBox(height: 8),
                  const Text("3. Keep the camera about 5 to 9 inches above the carbon weld plate."),
                  const SizedBox(height: 8),
                  const Text("4. Use a plain white background and keep the area around the plate free of extra objects."),
                  const SizedBox(height: 8),
                  const Text("5. Capture only one welding plate in each photo."),
                  const SizedBox(height: 8),
                  const Text("6. Make sure the lighting is bright and comes from above."),
                ] else ...[
                  const Text(
                    "Part 2: How the YOLO assessment works:",
                  ),
                  const SizedBox(height: 12),
                  const Text("1. YOLO analyzes the uploaded weld image and detects visible surface defects."),
                  const SizedBox(height: 8),
                  const Text("2. Confidence shows how certain the model is about a detected result."),
                  const SizedBox(height: 8),
                  const Text("3. A confidence score of 75% or higher should be treated as a strong detection."),
                  const SizedBox(height: 8),
                  const Text("4. Detected defects are applied to the surface-defect criteria for trainer review."),
                  const SizedBox(height: 8),
                  const Text("5. Demo assessment is only available after Oral and Written are both Competent."),
                  const SizedBox(height: 8),
                  const Text("6. The overall result is Competent when the total score is 75 points or higher."),
                  const SizedBox(height: 8),
                  const Text("7. The trainer should still review the YOLO result before finalizing the assessment."),
                  if (allowDontShowAgain) ...[
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      value: dontShowAgain,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text("Don't show again"),
                      onChanged: (value) {
                        setDialogState(() {
                          dontShowAgain = value ?? false;
                        });
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (showPartTwo) {
                  setDialogState(() {
                    showPartTwo = false;
                  });
                  return;
                }
                Navigator.pop(context);
              },
              child: Text(showPartTwo ? "Back" : "Close"),
            ),
            if (!showPartTwo)
              FilledButton(
                style: adminActionButtonStyle(),
                onPressed: () {
                  setDialogState(() {
                    showPartTwo = true;
                  });
                },
                child: const Text("Next"),
              )
            else if (allowDontShowAgain)
              FilledButton(
                style: adminActionButtonStyle(),
                onPressed: () async {
                  await prefs.setBool(scopedHideKey, dontShowAgain);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text("Done"),
              )
            else
              FilledButton(
                style: adminActionButtonStyle(),
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSetStatus({
    required String type,
    required String status,
  }) async {
    final currentStatus = switch (type) {
      'Oral' => _oralStatus,
      'Written' => _writtenStatus,
      _ => _demoStatus,
    };

    if (currentStatus == status) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type is already ${_labelFor(status)}.')),
      );
      return;
    }

    if (type == 'Demo' && !_canAssessDemo) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Demo is locked. Oral and Written must both be Competent."),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Change'),
        content: Text('Change $type to ${_labelFor(status)}?'),
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

    if (ok == true) {
      await _updateAssessment(type: type, status: status);
      await _syncBatchTraineeStatus();
    }
  }

  Widget _statusButton({
    required String type,
    required String status,
  }) {
    final isSelected = switch (type) {
      'Oral' => _oralStatus == status,
      'Written' => _writtenStatus == status,
      _ => _demoStatus == status,
    };
    final color = status == 'competent' ? Colors.green : Colors.red;
    return OutlinedButton(
      onPressed: _isSaving ? null : () => _confirmSetStatus(type: type, status: status),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? color.withOpacity(0.12) : null,
        side: BorderSide(color: isSelected ? color : Colors.grey.shade400),
      ),
      child: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? color : Colors.grey,
        size: 18,
      ),
    );
  }

  Widget _assessmentRow({
    required String label,
    required String date,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Center(child: _statusButton(type: label, status: 'competent')),
          ),
          Expanded(
            child: Center(child: _statusButton(type: label, status: 'not_yet_competent')),
          ),
          Expanded(
            flex: 2,
            child: Text(
              date,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.trainee.trainingCenter.isNotEmpty
        ? widget.trainee.trainingCenter
        : 'SMAW NC I';
    final traineeName =
        widget.trainee.name.isNotEmpty ? widget.trainee.name : 'Trainee';

    return AdminMobileScaffold(
      title: 'Trainee Progress',
      subtitle: '$className • $traineeName',
      actions: [
        if (_assessmentComplete)
          IconButton(
            onPressed: _exportTraineeReport,
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'Export report',
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  className,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Trainee: $traineeName'),
                                const Text('Email: trainee@email.com'),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Total Points',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_totalPoints()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                _totalCompetencyLabel(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _totalPoints() >= 75 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Assessment Result',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          _HeaderCell('Area', flex: 2),
                          _HeaderCell('Competent', flex: 3, allowWrap: false),
                          _HeaderCell('Not Yet\nCompetent', flex: 3),
                          _HeaderCell('Date\nCompleted', flex: 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _assessmentRow(label: 'Oral', date: _oralDate),
                    _assessmentRow(label: 'Written', date: _writtenDate),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Oral: ${_oralPoints()} pts',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Written: ${_writtenPoints()} pts',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Demo: ${_demoPoints()} pts',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '* Oral and Written must both be Competent before Demo can be accessed.',
                      style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Demo',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _openYoloInstructions(
                                  forceShow: true,
                                  allowDontShowAgain: false,
                                ),
                                icon: const Icon(Icons.info_outline),
                                tooltip: 'YOLO instructions',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!_canAssessDemo)
                            const Text(
                              'Demo is locked. Oral and Written must both be Competent.',
                              style: TextStyle(color: Colors.redAccent),
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Result: ${_labelFor(_effectiveDemoStatus())}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Date Completed: $_demoDate',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _isSaving ? null : _pickAndAssessDemoImage,
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text("Assess with YOLO"),
                              ),
                            ),
                          ],
                            const SizedBox(height: 8),
                            if (_demoImageUrl.isNotEmpty)
                              GestureDetector(
                                onTap: () => _showDemoPreview(
                                  originalImageUrl: _demoOriginalImageUrl,
                                  annotatedImageUrl: _demoAnnotatedImageUrl,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    _demoImageUrl,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 140,
                                      color: const Color(0xFFEFF3F9),
                                      alignment: Alignment.center,
                                      child: const Text('Unable to load demo image'),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 140,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF3F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Text('No demo image uploaded yet'),
                              ),
                        ],
                      ),
                    ),
                    if (_hasPerformanceAssessment) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Performance Criteria",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            ..._assessmentSections.map(
                              (section) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(section.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    ...section.items.map(
                                      (item) => Row(
                                        children: [
                                          Expanded(child: Text(item)),
                                          Text(
                                            _criteriaValueLabel(
                                              item,
                                              _criteriaScores[item] ?? 0,
                                            ),
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _CriteriaSection {
  const _CriteriaSection({
    required this.title,
    required this.items,
    this.isSurfaceDefects = false,
  });

  final String title;
  final List<String> items;
  final bool isSurfaceDefects;
}

class _CriteriaScoreField extends StatefulWidget {
  const _CriteriaScoreField({
    required this.item,
    required this.initialValue,
    required this.onChanged,
  });

  final String item;
  final int initialValue;
  final ValueChanged<int> onChanged;

  @override
  State<_CriteriaScoreField> createState() => _CriteriaScoreFieldState();
}

class _CriteriaScoreFieldState extends State<_CriteriaScoreField> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _CriteriaScoreField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _value = widget.initialValue;
    }
  }

  void _handleChanged(int next) {
    if (_value == next) return;
    setState(() => _value = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return _ScoreRadio(
      item: widget.item,
      value: _value,
      onChanged: _handleChanged,
    );
  }
}

class _ScoreRadio extends StatelessWidget {
  const _ScoreRadio({
    required this.item,
    required this.value,
    required this.onChanged,
  });

  final String item;
  final int value;
  final ValueChanged<int> onChanged;
  static const int _textFlex = 6;
  static const int _optionFlex = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        Widget buildChoice({
          required int optionValue,
          required String label,
        }) {
          final selected = value == optionValue;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(optionValue),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? AdminMobilePalette.primary
                        : const Color(0xFFD4DCEB),
                  ),
                  color: selected
                      ? const Color(0xFFEAF2FF)
                      : Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Radio<int>(
                        value: optionValue,
                        groupValue: value,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        activeColor: AdminMobilePalette.primary,
                        onChanged: (next) {
                          if (next != null) {
                            onChanged(next);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final positiveLabel = _isDefectItem(item) ? "Seen" : "Performed";
        final negativeLabel = _isDefectItem(item) ? "Not Seen" : "Not Performed";

        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item,
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 10),
              if (isNarrow)
                Column(
                  children: [
                    Row(
                      children: [
                        buildChoice(optionValue: 1, label: positiveLabel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        buildChoice(optionValue: 0, label: negativeLabel),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    buildChoice(optionValue: 1, label: positiveLabel),
                    const SizedBox(width: 10),
                    buildChoice(optionValue: 0, label: negativeLabel),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.isDefect,
  });

  final String title;
  final bool isDefect;

  @override
  Widget build(BuildContext context) {
    final positiveLabel = isDefect ? "Seen" : "Performed";
    final negativeLabel = isDefect ? "Not Seen" : "Not Performed";
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        Widget buildOptionLabel(String text) {
          return Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AdminMobilePalette.primary,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                buildOptionLabel(positiveLabel),
                SizedBox(width: isNarrow ? 8 : 10),
                buildOptionLabel(negativeLabel),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.text, {
    required this.flex,
    this.allowWrap = true,
  });

  final String text;
  final int flex;
  final bool allowWrap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: allowWrap ? 2 : 1,
          softWrap: allowWrap,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}

class _CriteriaItem {
  _CriteriaItem({
    required this.type,
    required this.category,
    required this.title,
  });

  final String type;
  final String category;
  final String title;

  factory _CriteriaItem.fromMap(Map<dynamic, dynamic> raw) {
    return _CriteriaItem(
      type: (raw["type"] ?? "").toString(),
      category: (raw["category"] ?? "").toString(),
      title: (raw["title"] ?? "").toString(),
    );
  }
}

class _DemoDetection {
  const _DemoDetection({
    required this.label,
    required this.confidence,
  });

  final String label;
  final String confidence;
}

enum _ExportAction { email, share }
