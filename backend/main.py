"""O.B.R.A. inference backend: receives a drawing, returns the recognized entity.

Run:
    uvicorn main:app --reload --port 8000

Then open http://127.0.0.1:8000/docs to try it interactively.
Requires model/model.onnx and model/labels.json (produced by model/train_quickdraw.py).
"""

import base64
import json
import os
import sys
import time
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
REPO_ROOT = BACKEND_DIR.parent
sys.path.insert(0, str(BACKEND_DIR))
sys.path.insert(0, str(REPO_ROOT))

import numpy as np
import onnxruntime
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from preprocess import EmptyCanvasError, preprocess_image

from shared.entities import (  # noqa: E402
    entities_by_source_label,
    load_abilities,
    load_entities,
    validate_model_labels,
)

MODEL_PATH = Path(os.environ.get("OBRA_MODEL", REPO_ROOT / "model" / "model.onnx"))
LABELS_PATH = Path(os.environ.get("OBRA_LABELS", REPO_ROOT / "model" / "labels.json"))
MODEL_METADATA_PATH = Path(
    os.environ.get("OBRA_MODEL_METADATA", REPO_ROOT / "model" / "model_metadata.json")
)

if not MODEL_PATH.exists():
    raise SystemExit(
        f"Model not found at {MODEL_PATH}.\n"
        "Train it first (see model/train_quickdraw.py) and place model.onnx + "
        "labels.json in the model/ folder, or set OBRA_MODEL / OBRA_LABELS."
    )
if not LABELS_PATH.exists():
    raise SystemExit(
        f"Labels not found at {LABELS_PATH}.\n"
        "Train/export the model so labels.json is created beside model.onnx."
    )

ENTITIES = load_entities(validate_scene_paths=True)
ENTITY_BY_SOURCE_LABEL = entities_by_source_label(ENTITIES)
ABILITIES = load_abilities(entities=ENTITIES)  # ConceptNet-grounded, validated on load
LABELS: list[str] = json.loads(LABELS_PATH.read_text())
validate_model_labels(LABELS, ENTITIES, source=str(LABELS_PATH))
SESSION = onnxruntime.InferenceSession(str(MODEL_PATH))
OUTPUT_NAME = SESSION.get_outputs()[0].name
OUTPUT_SHAPE = SESSION.get_outputs()[0].shape
if OUTPUT_SHAPE and isinstance(OUTPUT_SHAPE[-1], int) and OUTPUT_SHAPE[-1] != len(LABELS):
    raise SystemExit(
        f"Model output width is {OUTPUT_SHAPE[-1]}, but labels.json has {len(LABELS)} labels."
    )
MODEL_METADATA = (
    json.loads(MODEL_METADATA_PATH.read_text()) if MODEL_METADATA_PATH.exists() else {}
)
DEBUG_TIMING = os.environ.get("OBRA_DEBUG_TIMING", "").lower() in {"1", "true", "yes", "on"}

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
    return {
        "status": "ok",
        "source_labels": LABELS,
        "entities": [entity.to_public_dict() for entity in ENTITIES],
        "abilities": {eid: ability.to_public_dict() for eid, ability in ABILITIES.items()},
        "model_metadata": MODEL_METADATA,
    }


@app.post("/predict")
def predict(payload: DrawingPayload) -> dict:
    started = time.perf_counter()
    encoded = payload.image_data.split(",")[-1]  # strip "data:image/png;base64," if present
    try:
        image_bytes = base64.b64decode(encoded, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="image_data is not valid base64")

    try:
        preprocess_started = time.perf_counter()
        tensor = preprocess_image(image_bytes)
    except EmptyCanvasError:
        raise HTTPException(status_code=422, detail="the canvas appears to be empty")
    except Exception:
        raise HTTPException(status_code=400, detail="could not decode the image")
    preprocessed = time.perf_counter()

    logits = SESSION.run([OUTPUT_NAME], {"input": tensor})[0][0]
    inferred = time.perf_counter()
    probabilities = softmax(logits)
    best = int(probabilities.argmax())
    sorted_indices = np.argsort(probabilities)[::-1]
    runner_up = int(sorted_indices[1]) if len(sorted_indices) > 1 else best
    margin = float(probabilities[best] - probabilities[runner_up])
    source_label = LABELS[best]
    entity = ENTITY_BY_SOURCE_LABEL[source_label]
    if DEBUG_TIMING:
        print(
            "predict timing decode+queue={:.2f}ms preprocess={:.2f}ms infer={:.2f}ms total={:.2f}ms".format(
                (preprocess_started - started) * 1000.0,
                (preprocessed - preprocess_started) * 1000.0,
                (inferred - preprocessed) * 1000.0,
                (time.perf_counter() - started) * 1000.0,
            )
        )
    return {
        "entity": entity.id,
        "creature": entity.id,  # temporary legacy alias for older Godot scripts
        "display_name": entity.display_name,
        "source_label": source_label,
        "kind": entity.kind,
        "spawn_mode": entity.spawn_mode,
        "movement_type": entity.movement_type,
        "scene_path": entity.scene_path,
        "rig_profile": entity.rig_profile,
        "rig_type": entity.rig_type,
        "runtime_role": entity.runtime_role,
        "utility_behavior": entity.utility_behavior,
        "required_medium": entity.required_medium,
        "ability": ABILITIES[entity.id].ability,
        "ability_relation": ABILITIES[entity.id].ability_relation,
        "ability_weight": ABILITIES[entity.id].ability_weight,
        "confidence": float(probabilities[best]),
        "margin": margin,
        "runner_up": {
            "entity": ENTITY_BY_SOURCE_LABEL[LABELS[runner_up]].id,
            "source_label": LABELS[runner_up],
            "confidence": float(probabilities[runner_up]),
        },
        "probabilities": {
            ENTITY_BY_SOURCE_LABEL[label].id: float(p) for label, p in zip(LABELS, probabilities)
        },
        "source_probabilities": {label: float(p) for label, p in zip(LABELS, probabilities)},
    }
