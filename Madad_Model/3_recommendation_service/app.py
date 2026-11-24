"""
Madad recommendation server (V4 type-aware + FashionCLIP).

One job: POST /embed {imageUrl, description} -> {"embedding": [128 numbers]}
The app calls it once per item when the item is saved, stores the embedding in
Firestore (items.embedding), and ranks items itself with v4_masks.json.

The encoder below is copied from the training notebook (madad_final_V4.ipynb,
sections 5 and 6) so the server gives exactly the same embedding as training.
"""
import io
import os

import requests
import torch
import torch.nn as nn
import torch.nn.functional as F
from fastapi import FastAPI, Header, HTTPException
from PIL import Image
from pydantic import BaseModel
from transformers import CLIPModel, CLIPProcessor

CLIP_NAME = "patrickjohncyh/fashion-clip"
MODEL_PATH = os.environ.get("MODEL_PATH", "V4_typeaware_fashionclip.pt")
APP_SECRET = os.environ.get("APP_SECRET", "")      # set in the Space settings (Secrets)
torch.set_grad_enabled(False)

# ---------- FashionCLIP (same calls as the notebook's Encoder, backend "hf") ----------
clip = CLIPModel.from_pretrained(CLIP_NAME).eval()
processor = CLIPProcessor.from_pretrained(CLIP_NAME)


def _t(out):
    return out if isinstance(out, torch.Tensor) else out.pooler_output


def clip_features(image, text):
    im_in = processor(images=[image], return_tensors="pt")
    tx_in = processor(text=[text], return_tensors="pt", padding=True, truncation=True, max_length=77)
    im_f = F.normalize(_t(clip.get_image_features(**im_in)).float(), dim=-1)
    tx_f = F.normalize(_t(clip.get_text_features(**tx_in)).float(), dim=-1)
    return torch.cat([im_f, tx_f], 1)                # [1, 1024], USE_TEXT = True


# ---------- V4 encoder (same layer names as TypeAwareNet in the notebook) ----------
class V4Encoder(nn.Module):
    def __init__(self, in_dim, d):
        super().__init__()
        self.enc = nn.Sequential(nn.Linear(in_dim, 512), nn.GELU(), nn.Dropout(0.1), nn.Linear(512, d))

    def forward(self, x):
        return F.normalize(self.enc(x), dim=-1)


ck = torch.load(MODEL_PATH, map_location="cpu", weights_only=False)
sd = {k: v for k, v in ck["state_dict"].items() if k.startswith("enc.")}
in_dim, dim = sd["enc.0.weight"].shape[1], sd["enc.3.weight"].shape[0]
encoder = V4Encoder(in_dim, dim)
encoder.load_state_dict(sd)
encoder.eval()
TYPES = ck["types"]

# ---------- API ----------
app = FastAPI(title="Madad recommender")
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


class EmbedRequest(BaseModel):
    imageUrl: str
    description: str = ""


@app.get("/")
def health():
    return {"ok": True, "model": "V4", "dim": dim, "types": TYPES}


@app.post("/embed")
def embed(req: EmbedRequest, x_app_secret: str = Header(default="")):
    if APP_SECRET and x_app_secret != APP_SECRET:
        raise HTTPException(401, "bad secret")
    try:
        r = requests.get(req.imageUrl, timeout=20)
        r.raise_for_status()
        image = Image.open(io.BytesIO(r.content)).convert("RGB")
    except Exception as e:
        raise HTTPException(400, f"could not load image: {e}")
    e = encoder(clip_features(image, req.description.strip()))[0]
    return {"embedding": [round(float(v), 6) for v in e], "dim": dim}
