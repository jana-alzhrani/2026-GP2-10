# Madad – Outfit Recommendation Model

This folder contains the code used to build, evaluate and deploy the outfit recommendation model of the Madad application.

**Final model:** type-aware fashion-compatibility model (Vasileva et al., 2018) on FashionCLIP image and text features, trained on Polyvore Outfits (16 Madad item types).

| Metric (test set) | Final model (V4) | Random |
|---|---|---|
| FITB accuracy | 0.652 [95% CI 0.631–0.673] | 0.25 |
| HR@10 | 0.389 | 0.10 |
| MRR | 0.200 | 0.05 |
| AUC | 0.745 | 0.50 |

## Folders

| Folder | Content |
|---|---|
| `1_model_comparison/` | Pairwise MLP (V2) vs type-aware model (V4) on the same data and the same test questions, with 95% confidence intervals, McNemar and Wilcoxon tests, and the type co-occurrence list. |
| `2_final_model/` | One notebook from start to end: data preparation, training of the final model, evaluation, demo, export of the files used by the app, and a check that the app formula gives the same ranking as the model. |
| `3_recommendation_service/` | FastAPI service deployed on Google Cloud Run. `POST /embed` receives an image URL and a description and returns the 128-number item embedding. |
| `4_app_files/` | Files used by the Flutter app (`madad/assets/model/`): type-pair masks (`v4_masks.json`) and the types recommended for each type (`type_cooccurrence.json`). The ranking code is in `madad/lib/recommender.dart`. |
| `5_outputs/` | Comparison results (CSV), statistical tests, training curves and demo figures. Add the trained weights file `V4_typeaware_fashionclip.pt` here (about 2–3 MB). |

## How to run the notebooks

1. Open the notebook in Google Colab and choose **Runtime → Change runtime type → T4 GPU**.
2. Choose **Runtime → Run all**. The data (Polyvore Outfits, Hugging Face `Marqo/polyvore`) and FashionCLIP are downloaded automatically.
3. All notebooks use seed 42, so the results are reproducible.

## Deploying the recommendation service

```
gcloud run deploy madad-recommender --source . --region europe-west1 --memory 2Gi --allow-unauthenticated
```
The trained weights file `V4_typeaware_fashionclip.pt` must be placed next to `app.py` before deploying (it is produced by `2_final_model/madad_final_V4.ipynb`). The optional environment variable `APP_SECRET` protects the endpoint.

Trained model weights: `5_outputs/V4_typeaware_fashionclip.pt`
