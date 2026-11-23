# Madad – Clothing Donation Application
Graduation Project – Group 10
King Saud University

## 1. Project Overview
Madad is an Android mobile application designed to connect donors with verified beneficiaries through a secure and organized clothing donation platform. The application enables donors to list clothing items with detailed information and images, while allowing beneficiaries to browse available donations and request suitable items based on their needs.

The main goal of Madad is to improve the clothing donation process in Saudi Arabia by providing a fair, transparent, and user-friendly digital solution. The platform helps reduce unorganized distribution and enhances communication between donors, beneficiaries, and administrators.

Madad includes features such as donation tracking, delivery method selection, beneficiary verification, and AI-powered image verification to ensure uploaded items meet quality standards before being published. The system also supports privacy-focused delivery options and promotes efficient distribution of donations within the community.

By combining digital transformation with charitable work, Madad aims to support social responsibility and contribute to a more sustainable and connected community in alignment with Saudi Vision 2030.
___________________________________________________________________

## 2. Key Features
### 1. Donor
- Add donation boxes and items with images (saved as drafts first)
- AI image verification with Google Gemini: checks the image, detects the item type and writes a short description
- Choose the delivery method: self-delivery to the warehouse or pickup from the donor's location
- Confirm the delivery by scanning the warehouse barcode and track the donation status

### 2. Beneficiary
- Registration with social security proof, reviewed by the administrator
- Browse and filter the available items
- "Matching items": AI outfit recommendations on the item details page
- Cart and requests with a quota of 30 items every 90 days
- Pickup from the warehouse or delivery, and receipt confirmation by scanning the request barcode

### 3. Courier
- View available donor and beneficiary tasks
- Accept, complete or abandon a task

### 4. Administrator
- Review beneficiary registration requests (accept / reject with a reason)
- Manage beneficiaries and couriers (add, edit, delete)
- Approve or reject phone number change requests

### 5. AI Outfit Recommendation
- Type-aware embedding model trained on FashionCLIP image and text features
- Recommendation service on Google Cloud Run that computes the embedding of each new item
- Real-time ranking of the available items inside the application
- Details in [`Madad_Model/README.md`](Madad_Model/README.md)

___________________________________________________________________

## 3. Repository Structure
```
2026-GP2-10/
│
├── madad/                          # Flutter application (Release 2)
│   ├── lib/                        # Application pages and services
│   │   └── recommender.dart        # Scoring and ranking of matching items
│   └── assets/model/               # v4_masks.json, type_cooccurrence.json
│
├── Madad_Model/                    # AI outfit recommendation model
│   ├── madad_final_V4.ipynb        # Data → training → evaluation → export
│   ├── recommendation_service/     # FastAPI service deployed on Cloud Run
│   └── README.md                   # Model documentation and results
│
├── README.md                       # Project documentation
└── AUTHORS.md                      # Contributors
```
Release 1 of the project: https://github.com/jana-alzhrani/2025-GP1-10

___________________________________________________________________

## 4. Technologies Used
- Frontend:
    Flutter (Dart)
    Material Design
    Firebase SDK

- Backend & Database:
    Firebase Firestore
    Firebase Authentication
    Firebase Storage
    Google Cloud Run

- Artificial Intelligence:
    Google Gemini API (image verification and description)
    Python, PyTorch
    FashionCLIP
    FastAPI, Docker

- Other Tools:
    GitHub
    Jira
    Google Colab

___________________________________________________________________

## 5. AI Models Included (Release-2)

Inside Madad_Model:
- Type-aware outfit recommendation model (FashionCLIP features)
- Training and evaluation notebook (madad_final_V4.ipynb)
- Recommendation service for Google Cloud Run (FastAPI)
- Exported files for the application (type-pair masks and type co-occurrence)

Inside the application:
- Google Gemini image verification, item type detection and description

___________________________________________________________________

## 6. Application Screens

Includes:
- Welcome & Role Selection
- Login & OTP Verification
- Beneficiary Registration
- Donor Home Page
- Add Donation & Drafts
- My Donations
- Delivery Method
- Beneficiary Home Page
- Item Details & Matching Items
- Cart
- My Requests
- Courier Home Page
- Courier Tasks
- Admin Home Page
- Beneficiaries Management
- Couriers Management
- Phone Change Requests
- More & Profile

___________________________________________________________________

## 7. Installation & Run Instructions
Prerequisites:
- Flutter SDK
- Android Studio or VS Code
- Connected Android device or emulator

Steps to run:
```
git clone https://github.com/jana-alzhrani/2026-GP2-10.git
cd 2026-GP2-10/madad
flutter pub get
flutter run
```
The Gemini API key and the recommendation service key are not included in the repository and must be provided separately.

___________________________________________________________________

## 8. Contributors
- Riyam Alrashed
- Sarah Alotaibi
- Lena Binfares
- Raghad Mohsen
- Jana Alzhrani

Supervised by
- Dr. Arwa Alhussain
