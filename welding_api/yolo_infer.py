import argparse
import json
import os
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

try:
    from ultralytics import YOLO
except Exception as exc:  # pragma: no cover
    raise SystemExit(f"Ultralytics not available: {exc}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--name", required=True)
    args = parser.parse_args()

    os.environ.setdefault("ULTRALYTICS_VERBOSE", "False")

    model = YOLO(args.model)
    with open(os.devnull, "w") as devnull:
        with redirect_stdout(devnull), redirect_stderr(devnull):
            results = model.predict(
                source=args.source,
                save=False,
                imgsz=640,
                conf=0.15,
                verbose=False,
                retina_masks=True,
            )

    label = ""
    confidence = ""
    masks_present = False
    reason = ""
    detections = []
    if results and len(results) > 0:
        res = results[0]
        if res.boxes is not None and len(res.boxes) > 0:
            names = res.names or {}
            boxes = res.boxes
            for i in range(len(boxes)):
                box = boxes[i]
                det_conf = ""
                det_label = ""
                if hasattr(box, "conf") and box.conf is not None:
                    det_conf = f"{float(box.conf):.4f}"
                if hasattr(box, "cls") and box.cls is not None:
                    cls_id = int(box.cls)
                    det_label = names.get(cls_id, str(cls_id))
                detections.append({
                    "label": det_label,
                    "confidence": det_conf,
                })
            detections.sort(
                key=lambda item: float(item["confidence"] or 0),
                reverse=True,
            )
            best = detections[0]
            label = best["label"]
            confidence = best["confidence"]
        masks = getattr(res, "masks", None)
        if masks is not None and masks.data is not None and len(masks.data) > 0:
            masks_present = True

    output_dir = Path(args.project) / args.name
    output_dir.mkdir(parents=True, exist_ok=True)
    output_image = output_dir / "annotated.png"

    # Render segmentation-first overlays using class-colored mask outlines.
    try:
        import numpy as np
        from PIL import Image, ImageDraw

        img = Image.open(args.source)
        try:
            from PIL import ImageOps
            img = ImageOps.exif_transpose(img)
        except Exception:
            pass
        img = img.convert("RGBA")
        draw = ImageDraw.Draw(img)
        class_colors = {
            "spatter": (45, 212, 191),
            "blowhole": (250, 204, 21),
            "pinhole": (250, 204, 21),
            "misalignment": (249, 115, 22),
            "porosity": (56, 189, 248),
            "good welding": (34, 197, 94),
        }

        if results and len(results) > 0:
            res = results[0]
            names = res.names or {}
            masks = getattr(res, "masks", None)
            if masks is not None and masks.data is not None and len(masks.data) > 0:
                classes = []
                if res.boxes is not None and getattr(res.boxes, "cls", None) is not None:
                    classes = [int(cls_id) for cls_id in res.boxes.cls.tolist()]

                for index, mask_tensor in enumerate(masks.data):
                    mask = mask_tensor.cpu().numpy()
                    if mask.shape[:2] != (img.height, img.width):
                        mask_img = Image.fromarray((mask * 255).astype(np.uint8))
                        mask_img = mask_img.resize((img.width, img.height))
                        mask = np.array(mask_img) / 255.0

                    class_name = ""
                    if index < len(classes):
                        class_name = str(names.get(classes[index], classes[index])).strip().lower()
                    color = class_colors.get(class_name, (255, 140, 0))
                    fill_rgba = (color[0], color[1], color[2], 90)

                    mask_bool = mask > 0.5
                    overlay = np.zeros((img.height, img.width, 4), dtype=np.uint8)
                    overlay[mask_bool] = fill_rgba
                    overlay_img = Image.fromarray(overlay, mode="RGBA")
                    img = Image.alpha_composite(img, overlay_img)
                    draw = ImageDraw.Draw(img)

                    # Draw a colored contour by tracing mask boundary pixels.
                    boundary = np.zeros_like(mask_bool, dtype=bool)
                    boundary[1:, :] |= mask_bool[1:, :] != mask_bool[:-1, :]
                    boundary[:-1, :] |= mask_bool[:-1, :] != mask_bool[1:, :]
                    boundary[:, 1:] |= mask_bool[:, 1:] != mask_bool[:, :-1]
                    boundary[:, :-1] |= mask_bool[:, :-1] != mask_bool[:, 1:]

                    ys, xs = np.where(boundary)
                    for x, y in zip(xs, ys):
                        x = int(x)
                        y = int(y)
                        draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=color)

            elif res.boxes is not None and len(res.boxes) > 0:
                for box in res.boxes:
                    coords = box.xyxy[0].tolist()
                    x1, y1, x2, y2 = [int(v) for v in coords]
                    draw.rectangle((x1, y1, x2, y2), outline=(255, 215, 0), width=2)

        img.convert("RGB").save(output_image)

        if not masks_present and not detections:
            reason = "No defects detected."
        elif not masks_present:
            reason = "Bounding boxes detected, but no segmentation masks were returned by the model."
    except Exception:
        # Last-resort fallback to raw image.
        try:
            from PIL import Image
            img = Image.open(args.source)
            try:
                from PIL import ImageOps
                img = ImageOps.exif_transpose(img)
            except Exception:
                pass
            img = img.convert("RGB")
            img.save(output_image)
        except Exception:
            pass

    payload = {
        "label": label,
        "confidence": confidence,
        "detections": detections,
        "output_image": str(output_image),
        "masks_present": masks_present,
        "reason": reason,
    }
    print(json.dumps(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
