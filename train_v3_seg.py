from ultralytics import YOLO
from multiprocessing import freeze_support

def main():
    model = YOLO(r".\yolov8n-seg.pt")
    model.train(
        data=r".\YOLO DATASET\welding2026C.v3i.yolo26\data.yaml",
        epochs=100,
        imgsz=640,
        device=0,
        workers=0,
        project=r".\runs\yolo_runs",
        name=r"welding2026C-v3-seg",
    )

if __name__ == "__main__":
    freeze_support()
    main()
