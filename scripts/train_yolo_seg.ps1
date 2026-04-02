param(
  [string]$DatasetDir = ".\\YOLO DATASET\\welding2026C.v3i.yolo26",
  [string]$Model = "yolov8n-seg.pt",
  [int]$Epochs = 100,
  [int]$Img = 640,
  [string]$Project = ".\\runs\\yolo_runs",
  [string]$Name = "welding2026C-v3-seg"
)

$ErrorActionPreference = "Stop"

$datasetPath = Resolve-Path $DatasetDir
$dataYaml = Join-Path $datasetPath "data.yaml"

if (-not (Test-Path $dataYaml)) {
  throw "data.yaml not found at $dataYaml"
}

python -c "import ultralytics" 2>$null
if ($LASTEXITCODE -ne 0) {
  python -m pip install ultralytics
}

$pythonCode = @"
from ultralytics import YOLO

model = YOLO(r"$Model")
model.train(
    data=r"$dataYaml",
    epochs=$Epochs,
    imgsz=$Img,
    device=0,
    project=r"$Project",
    name=r"$Name",
)
"@

$pythonCode | python -
