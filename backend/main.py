"""O.B.R.A. inference backend: receives a drawing, returns the recognized creature.

Run:
    uvicorn main:app --reload --port 8000

Then open http://127.0.0.1:8000/docs to try it interactively.
Requires model/model.onnx and model/labels.json (produced by model/train_quickdraw.py).
"""

import base64
import json
import os
from pathlib import Path

import numpy as np
import onnxruntime
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from preprocess import EmptyCanvasError, preprocess_image

REPO_ROOT = Path(__file__).resolve().parent.parent
MODEL_PATH = Path(os.environ.get("OBRA_MODEL", REPO_ROOT / "model" / "model.onnx"))
LABELS_PATH = Path(os.environ.get("OBRA_LABELS", REPO_ROOT / "model" / "labels.json"))

if not MODEL_PATH.exists():
    raise SystemExit(
        f"Model not found at {MODEL_PATH}.\n"
        "Train it first (see model/train_quickdraw.py) and place model.onnx + "
        "labels.json in the model/ folder, or set OBRA_MODEL / OBRA_LABELS."
    )

LABELS: list[str] = json.loads(LABELS_PATH.read_text())
SESSION = onnxruntime.InferenceSession(str(MODEL_PATH))

app = FastAPI(title="O.B.R.A. Sketch Classifier")
app.add_middleware(  # required so a Godot (web) client may call us
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class DrawingPayload(BaseModel):
    image_data: str  # base64-encoded PNG/JPEG; a data-URL prefix is tolerated


def softmax(logits: np.ndarray) -> np.ndarray:
    exps = np.exp(logits - logits.max())
    return exps / exps.sum()


@app.get("/")
def health() -> dict:
    return {"status": "ok", "classes": LABELS}


@app.post("/predict")
def predict(payload: DrawingPayload) -> dict:
    encoded = payload.image_data.split(",")[-1]  # strip "data:image/png;base64," if present
    try:
        image_bytes = base64.b64decode(encoded)
    except Exception:
        raise HTTPException(status_code=400, detail="image_data is not valid base64")

    try:
        tensor = preprocess_image(image_bytes)
    except EmptyCanvasError:
        raise HTTPException(status_code=422, detail="the canvas appears to be empty")
    except Exception:
        raise HTTPException(status_code=400, detail="could not decode the image")

    logits = SESSION.run(["logits"], {"input": tensor})[0][0]
    probabilities = softmax(logits)
    best = int(probabilities.argmax())
    return {
        "creature": LABELS[best],
        "confidence": float(probabilities[best]),
        "probabilities": {label: float(p) for label, p in zip(LABELS, probabilities)},
    }
