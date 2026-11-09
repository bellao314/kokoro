# Privacy Policy for Kokoro

Last Updated: November 9, 2026
Effective Date: November 9, 2026

At Kokoro ("we", "our", or "the App"), we believe that your health and symptom data belongs solely to you. Kokoro is designed as a privacy-first, on-device companion for tracking autonomic, meteoropathic, and hypermobility symptoms (including POTS, Dysautonomia, and Ehlers-Danlos Syndrome).

This Privacy Policy explains what information Kokoro accesses, how it is processed on your device, and how your privacy is protected.

⸻

## At a Glance

Do we sell or rent your personal data? No. Never.
Do we track you across other apps or websites? No. (NSPrivacyTracking is set to false).
Do we have user accounts or login systems? No. You do not need to register or create an account.
Where is your health data stored? Locally on your device using encrypted Apple storage.
Do we use third-party analytics or ad SDKs? No. There are zero advertising or behavioral tracking libraries.

⸻

## 1. Information We Access and Collect

Kokoro accesses only the minimum data required to deliver core health tracking, posture analysis, and flare forecasting features:

A. Health and Biometric Data (Apple HealthKit)
With your explicit consent, Kokoro interfaces with Apple HealthKit via HealthKitManager to read:
• Heart Rate & Heart Rate Variability (SDNN): To evaluate orthostatic tachycardia events, resting trends, and physiological stress.
• Resting Heart Rate & Walking Heart Rate Average: To establish adaptive circadian baselines.
• Oxygen Saturation ($SpO_2$): To monitor respiratory and circulatory levels.
• Apple Walking Steadiness & Sleep Analysis: To provide longitudinal context for symptom flares.

[!IMPORTANT]
HealthKit Privacy Commitment:
In compliance with Apple developer guidelines, health data acquired through HealthKit is never used for marketing, advertising, or data-mining, and is never transmitted to third parties or data brokers.

B. Motion and Activity Data (Apple CoreMotion)
With permission, Kokoro uses MotionManager to access:
• Locomotion and Activity State: Stationary, walking, or running classifications via CMMotionActivityManager.
• Step Cadence & Elevation Changes: Low-power pedometer and altimeter samples to differentiate true postural/orthostatic transitions from physical exertion and to suppress false POTS alerts.

Motion data is processed strictly on-device in real time and is not stored or shared as a continuous motion log.

C. Approximate Location and Environmental Data
With your permission, Kokoro accesses your coarse (approximate) location (kCLLocationAccuracyKilometer) via WeatherManager solely to retrieve local barometric pressure, temperature, and humidity forecasts to calculate meteoropathy flare risk:
• Apple WeatherKit: If available, weather queries are routed securely through Apple WeatherKit.
• Fallback Weather Service (Open-Meteo): If WeatherKit is unavailable, approximate coordinates (latitude and longitude rounded to town/city level) are transmitted to Open-Meteo to fetch atmospheric pressure curves. No personal identifiers or health records are included.
• IP-Based Geolocation Fallback: If location permissions are undetermined or in simulator environments, a lookup via ipwho.is may determine your approximate city region without transmitting health data.

D. User-Logged Symptom & Intervention Records
Data you manually record is stored locally in SwiftData structures (SymptomLog, InterventionLog, and DailyCheckIn):
• Selected symptom categories and severity (dizziness, blood pooling, brain fog, subluxations).
• Affected joint locations (e.g., cervical spine, shoulders, hips, fingers).
• Daily interventions (sodium/fluid intake, compression garments, braces, medications).
• Personal check-in notes.

⸻

## 2. How Your Data Is Processed and Stored

1. Local-Only Storage (SwiftData):
All symptom logs, vital snapshots, and intervention records are stored directly on your iPhone and protected by iOS Data Protection (hardware-level encryption).
2. Apple Watch Synchronization:
If you use the paired Apple Watch app, communication occurs exclusively over local, encrypted Bluetooth and Wi-Fi channels managed by Apple’s WatchConnectivityService.
3. No Proprietary Cloud Servers:
Kokoro operates without dedicated application backend servers. We do not store your data on external databases.

⸻

## 3. Data Sharing and Export

• User-Initiated PDF Clinical Reports:
Kokoro includes ClinicalReportGenerator, an on-device engine that synthesizes your symptom frequency, vitals, and barometric correlations into a printable clinical report.
• Your Explicit Control:
Reports are generated entirely on your device. Any sharing of this document (via AirDrop, Messages, Mail, or patient portals) occurs solely when you invoke the native iOS Share Sheet.

⸻

## 4. Notifications

Local alerts (such as rapid barometric pressure plunge warnings and daily check-in reminders) are scheduled on-device via Apple's UserNotifications framework through NotificationManager. No push notification tokens or device IDs are tracked or sent to remote servers.

⸻

## 5. Your Rights and Data Control

You maintain complete sovereignty over your information:
• Revoke Permissions Anytime: You can grant or revoke HealthKit, CoreMotion, Notification, and Location permissions at any time via iOS Settings > Privacy & Security.
• Data Deletion: You can delete individual symptom records or check-ins directly within the App. Uninstalling Kokoro removes all locally persisted application databases from your device.
• Regulatory Compliance (GDPR & CCPA/CPRA): Because Kokoro does not collect identifiable personal information or maintain remote user profiles, we do not monetize, profile, or sell "Personal Information" as defined under CCPA/CPRA and GDPR.

⸻

## 6. Medical Disclaimer

[!NOTE]
Kokoro is designed for self-tracking, lifestyle management, and supporting consultations with qualified medical professionals. Kokoro is not an FDA-cleared diagnostic device and is not intended to diagnose, treat, prevent, or cure any disease or medical condition. Always seek the advice of your physician or qualified healthcare provider regarding symptoms or treatment regimens.

⸻

## 7. Contact & Updates

We may update this Privacy Policy periodically to reflect enhancements to the App or regulatory updates. Continued use of Kokoro signifies your agreement to any revisions.

If you have questions, feedback, or privacy concerns:
• Contact Support / Developer: [Feedback form](https://forms.gle/Td7GZ96fn4ZiaP8B7)
