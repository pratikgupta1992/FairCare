# Instructions for Gemini — FairCare Firebase setup (project already created)

Paste everything below the line into the Gemini assistant inside the Firebase Console.

---

You are helping me finish setting up Firebase for my app "FairCare" (a Flutter baby-care tracker for two parents). I have ALREADY created the Firebase project. Guide me step by step, ONE step at a time, and adapt if the console UI labels differ from what you expect. HARD RULES — do not break these for any reason:

1. This project must stay on the FREE plan (Spark) at $0 forever. I must never pay for anything.
2. NEVER upgrade to the Blaze plan, NEVER add a billing account, NEVER enter any payment method, and never enable anything that requires Blaze. If any step appears to need billing or an upgrade, STOP immediately and tell me — do not proceed with it.
3. Do not enable Google Analytics, Vertex AI, Gemini/AI features, Cloud Functions, Cloud Storage file uploads beyond free defaults, extensions, or any add-on — skip anything not on my list below.
4. Whenever the console shows a plan name, a price, or a "requires billing" message, tell me exactly what it says before I click anything.

Here is exactly what I need, in order:

STEP 1 — Confirm the project: Tell me how to check which plan the project is on (Project settings / Usage and billing) and confirm it says the free Spark plan. Also tell me the exact Project ID and Project Number shown in Project settings → General — I need to copy both.

STEP 2 — Firestore database: Guide me to create the Firestore database in this project. Location: a United States location (nam5 or us-central). Mode: PRODUCTION mode (not test mode). If it asks about editions, choose the default free option.

STEP 3 — Firestore security rules: Guide me to the Rules tab and have me replace ALL the rules text with the exact rules below, then click Publish. Do not change a single character of this rules text:

rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() {
      return request.auth != null;
    }

    function isMember(babyId) {
      return signedIn()
        && request.auth.uid in
             get(/databases/$(database)/documents/babies/$(babyId)).data.memberUids;
    }

    match /connectCodes/{code} {
      allow get: if signedIn();
      allow list: if false;
      allow create: if signedIn()
        && request.resource.data.keys().hasOnly(['babyId', 'createdAt'])
        && request.auth.uid in
             get(/databases/$(database)/documents/babies/$(request.resource.data.babyId)).data.memberUids;
      allow update: if false;
      allow delete: if signedIn()
        && request.auth.uid in
             get(/databases/$(database)/documents/babies/$(resource.data.babyId)).data.memberUids;
    }

    match /babies/{babyId} {
      allow get, list: if signedIn()
        && request.auth.uid in resource.data.memberUids;

      allow create: if signedIn()
        && request.auth.uid in request.resource.data.memberUids
        && request.resource.data.createdBy == request.auth.uid;

      allow update: if signedIn() && (
        request.auth.uid in resource.data.memberUids
        || (
          request.resource.data.memberUids.size()
              == resource.data.memberUids.size() + 1
          && request.auth.uid in request.resource.data.memberUids
          && !(request.auth.uid in resource.data.memberUids)
          && request.resource.data.diff(resource.data)
               .affectedKeys().hasOnly(['memberUids', 'updatedAt'])
        )
      );

      allow delete: if signedIn()
        && request.auth.uid in resource.data.memberUids;

      match /caregivers/{docId} {
        allow read, write: if isMember(babyId);
      }
      match /tasks/{docId} {
        allow read, write: if isMember(babyId);
      }
      match /entries/{docId} {
        allow read, write: if isMember(babyId);
      }
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}

STEP 4 — Authentication: Guide me to enable the Email/Password sign-in provider (Authentication → Sign-in method). Enable ONLY the first toggle ("Email/Password"). Do NOT enable "Email link (passwordless sign-in)". Do not enable any other provider.

STEP 5 — Register the Android app: In Project settings → General → Your apps, add an Android app with package name EXACTLY: com.faircare.faircare — nickname "FairCare Android", no SHA certificate (leave blank). Then tell me where to download the google-services.json file — I will download it and send it to my developer assistant.

STEP 6 — Register the iOS app: Add another app, iOS, with Apple bundle ID EXACTLY: com.faircare.faircare — nickname "FairCare iOS". Then tell me where to download the GoogleService-Info.plist file — I will download it too.

AT THE END, summarize for me in a short list: (a) Project ID, (b) Project number, (c) plan name shown for the project, (d) confirmation that the Firestore rules were published, (e) confirmation Email/Password is enabled, (f) the two files I downloaded. Remind me of anything that tried to charge me or ask for billing along the way, if anything did.
