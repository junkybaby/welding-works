# welding_works

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## YOLO Training

The repo includes PowerShell helpers for training on the latest dataset:

- Dataset: `YOLO DATASET\welding2026C.v3i.yolo26`
- Classes: `Good Welding`, `Spatter`, `blowhole`, `misalignment`, `porosity`

From `welding_works`, run detection training:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\train_yolo.ps1
```

You can override settings if needed:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\train_yolo.ps1 -Model yolov8s.pt -Epochs 150 -Img 640 -Name welding2026C-v3-s
```

Default output path:

```text
.\runs\yolo_runs\welding2026C-v3\
```

Best weights are typically written to:

```text
.\runs\yolo_runs\welding2026C-v3\weights\best.pt
```
