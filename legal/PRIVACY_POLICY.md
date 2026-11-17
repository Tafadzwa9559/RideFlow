# Trivia — Privacy Policy

Draft for legal and business review. Not approved for publication; effective date and marked details require confirmation.

Version: 2026-11-17-draft.1

Effective date: To be confirmed

Trivia is developed by MOrdec Solutions (Pvt) Ltd.

## 1. Introduction

Trivia is developed by MOrdec Solutions (Pvt) Ltd. This notice explains the personal information handled for Trivia passenger and driver services and the related website. It describes the reviewed implementation and identifies matters that must be verified before publication.

This is a draft with no effective date. It is a notice about processing, not a blanket request for consent or a waiver of privacy rights. Any processing that legally requires consent must use a specific, informed and separate choice. Accepting platform Terms does not automatically authorise optional marketing or every use of personal information.

## 2. Data Controller and Contact Details

The data controller is the entity that determines the purposes and means of the relevant processing. [TO BE CONFIRMED: whether MOrdec Solutions (Pvt) Ltd is also the operational data controller, and its legal/service address and verified privacy contact.] Development attribution alone does not establish the controller role.

[TO BE CONFIRMED: the appointed Data Protection Officer and published contact, if required, and the status and scope of any required data-controller licensing.] This notice does not assert regulatory registration, approval or compliance certification.

## 3. Information We Collect

Depending on the feature used, information can include account identifiers, names and phone numbers, optional email and supplied profile images, driver and vehicle records, selected or device-derived locations, ride requests and offers, trip history, preferences, reviews and support or safety reports.

Technical records can include authenticated session information, request and error metadata, device/browser information supplied by network requests, and notification registration details where that integration is active. We distinguish information actually submitted or generated from optional features and from providers that are only configurable. Do not send unrelated identity, medical or financial documents through support messages.

## 4. Account and Contact Information

Phone verification is used to register or sign in. Account profiles hold the supplied name, phone number and optional email. The backend supports a profile photograph if one is uploaded; the existence of that endpoint does not mean a photograph is automatically collected. Emergency-contact details and saved-place labels are collected only when supplied through the relevant feature.

Share another person's contact details only with appropriate authority and after informing them as required. Device-local storage holds session credentials and selected application state. When submitted with successful phone verification, the legal acknowledgement feature records the document version, content digest, acknowledgement type and server time against the authenticated account in the existing audit records. A device-local copy can also be stored securely; device time and a local copy alone are not authoritative server evidence. This record is not marketing consent or proof that every paragraph was read.

## 5. Driver Verification and Identity Documents

Driver onboarding uses legal/contact information, driving-licence details and expiry dates, vehicle information and requirement-driven document uploads. Photographs or scans can contain identifying details and other sensitive information. Collect only the documents actually required for the application and do not use a driver's materials for unrelated purposes.

The reviewed design limits document access to authorised operations or verification workflows rather than exposing scans to passengers. A stored image is not, by itself, evidence that facial recognition or biometric matching is performed; no such matching is identified in the current application flow. [TO BE CONFIRMED: the required document list, access roles, verification service providers, lawful basis for sensitive information and deletion schedule.]

## 6. Location Information

Passengers can search for places, select map pins or request a current device position. Pickup and destination coordinates and names are submitted for routing, quotes and rides. Drivers publish foreground location updates while online to support eligibility, matching and trip updates. Updates can be throttled, interrupted or out of date.

The current Flutter app requests foreground location permissions and does not request background location permission. It attempts to stop online updates when paused; this is not a promise of continuous tracking or instantaneous server removal. The website's map tool requests a browser location only when the relevant control is used. You can change operating-system or browser permissions and use manual location selection where supported, but driver eligibility depends on fresh location information.

## 7. Ride and Booking Information

The platform records pickup and destination details, route/quote information, proposed and agreed fares, selected category, driver offers, participant identifiers, booking and status times, payment preference, and related trip records. It can retain passenger notes, review scores/comments and complaints supplied through the implemented features.

Ride history and driver earnings summaries are operational records, not independently verified receipts. Trivia does not process, receive, hold or verify fare payments. Cash, EcoCash and OneMoney preferences do not require providing wallet PINs, bank-card details or external transaction credentials to Trivia.

## 8. Device and Technical Information

Services necessarily receive network request information such as source IP address and headers, with device or browser details where supplied. Application infrastructure can record request identifiers, endpoints, status codes, timing, authentication/security events and errors to operate and protect the service. The exact deployed logging fields, recipients and retention require confirmation.

The mobile app stores access/refresh credentials using the platform secure-storage facility and uses local preferences for application state. Backend notification functionality supports a device push token and platform identifier when registered; native push registration/delivery is not confirmed in the reviewed mobile flow. No advertising identifier, cross-app tracking SDK or general address-book upload was identified in that flow.

## 9. How We Use Personal Information

Information supports account verification and security, profile management, driver review, route and fare estimation, matching and ride coordination, trip updates and history, saved places, permitted notifications, support, complaints, safety investigations and maintaining reliable services.

Information may also be needed to prevent misuse, respond to lawful requests and establish or defend legal claims, subject to applicable safeguards. The operator must not repurpose information for unrelated marketing, profiling or disclosure merely because it is available. [TO BE CONFIRMED: a documented processing inventory and any additional actual uses before launch.]

## 10. Legal Bases for Processing

Each purpose needs an applicable lawful ground under Zimbabwean law. Depending on the circumstances, necessary processing may relate to a requested or existing service agreement, a legal obligation, protection of a vital interest, or another statutory ground whose conditions are met. Where consent is relied on, it must be informed, specific, freely given and capable of withdrawal as the law provides.

[LEGAL REVIEW REQUIRED: a purpose-by-purpose lawful-basis assessment, including sensitive driver-document information, optional communications, necessary disclosures and international transfers.] We do not assume that a contractual checkbox covers every purpose. Refusing optional consent should not prevent unrelated service use; declining essential information may make the requested feature unavailable. Withdrawal does not itself determine whether records must be retained under another applicable ground.

## 11. Information Shared Between Drivers and Passengers

Participants receive information needed for the relevant ride, such as pickup and destination details, agreed fare, selected category, relevant notes, ride state and the assigned driver's displayed name, vehicle/registration and rating where supplied. Authorised trip tracking may show the assigned driver's recent position. Displayed information can be unavailable where the backend response does not supply it.

The current serializers do not establish a general passenger/driver phone-directory or unrestricted document sharing feature. [TO BE CONFIRMED before any additional contact or communication feature is enabled: the precise fields, when they become visible, and the lawful purpose.] Recipients should use shared information only for legitimate ride or complaint needs and protect it against unrelated disclosure.

## 12. Sharing Information With Service Providers

Necessary recipients may include the actual hosting/database operators, configured SMS delivery service, map/routing/geocoding operators, authorised private-document storage provider and configured push provider. Staff or contractors require an appropriate operational role. Disclosure to authorities or professional advisers must have a lawful justification and be limited appropriately.

A library installed in the codebase is not automatically a recipient. Django, Flutter, React, Dio, Riverpod and similar local software dependencies are not described as receiving personal information merely because they are used. [TO BE CONFIRMED: the processor register, legal entities, services, processing instructions, safeguards and written arrangements for every deployed provider.] No sale of information or advertising-network disclosure is identified in the reviewed application flow; additional use would need its own assessment and notice.

## 13. Maps and Third-Party Services

The Flutter map defaults to OpenStreetMap tiles. Tile requests can disclose IP/network information and the area being viewed to the tile service. Place search and route estimation send necessary place queries or coordinates to the configured backend mapping providers. The backend supports compatible routing/geocoding interfaces; their actual operators must be identified before publication rather than inferred from software names.

Opening an external policy, store or other website subjects that visit to the external site's own information practices. A user-triggered trip share hands a text summary to the recipient application chosen through the device share interface. Cash, EcoCash and OneMoney payments happen outside Trivia; their providers receive transaction information through the separate payment activity, not through a Trivia payment gateway.

## 14. Cloud Infrastructure and Database Storage

Repository deployment configuration supports Render application hosting and MongoDB Atlas database hosting. Production private-document storage is configurable through an S3-compatible service; the actual storage vendor is not identified by compatibility alone. Local development and test arrangements are separate from production deployment claims.

[TO BE CONFIRMED BEFORE PUBLICATION: which providers are actually deployed, their contracting entities and hosting/back-up regions, access arrangements and sub-processors.] This notice deliberately does not disclose connection strings, credentials, private network addresses, database names or internal security configuration. The identified deployment options do not prove that every option currently handles user information.

## 15. International Data Transfers

A provider or support arrangement may involve access to or storage of information outside Zimbabwe. The controller must establish where each relevant service operates and assess the applicable transfer conditions, safeguards and regulatory requirements before the transfer occurs.

[LEGAL AND OPERATIONAL REVIEW REQUIRED: actual destination countries, provider/sub-processor access, applicable transfer grounds and any notification or authorisation required by Zimbabwean law.] Accepting Terms or reading this notice is not blanket consent to unknown international transfers. Ask the confirmed privacy contact for the applicable information and safeguards once supplied.

## 16. Data Security

The reviewed implementation uses authenticated API access, role/participant checks, hashed expiring verification challenges, token revocation controls, secure device credential storage and restricted document-access paths. These measures describe code features, not a certification that every deployed system is secure. Live configuration, staff practices and provider safeguards require verification.

No system or transmission can be guaranteed risk-free. Protect your device and credentials and report suspected misuse through the confirmed channel. The operator must assess incidents, contain them and make any notifications required by applicable law. [TO BE CONFIRMED: responsible incident contacts, operational response procedures, access reviews and assurance testing.]

## 17. Data Retention

Records should be kept only as long as justified by the relevant purpose, applicable obligations and legitimate complaint or legal needs, with appropriate deletion or anonymisation thereafter. Different categories, such as driver documents, ride history, support reports and security logs and legal acknowledgements, need different reviewed schedules.

The code has configurable cleanup for location-update records and location-event payloads and separate cleanup for expired verification challenges. This is not evidence that deletion jobs run in production or that associated coordinates in quotes, ride records, logs, notifications or backups are all removed at the same time. No general account/document/history retention period has been confirmed. [TO BE CONFIRMED: category-specific periods, triggers, scheduled-job operation, backups, legal holds and how deletion is verified.]

## 18. Account Deletion

The current mobile app does not provide a completed self-service account-deletion endpoint. Do not treat logging out, uninstalling the app or disabling an account as deletion of backend information. A confirmed privacy-request channel and a workable manual procedure must be supplied before publication.

[TO BE CONFIRMED: the verified request contact, identity-check process, applicable response period and deletion/retention exceptions.] We do not promise immediate erasure or invent a response deadline. The controller should explain what can be removed, what must remain and why, subject to applicable rights and obligations. In-app support may be used where connected, but no deletion completion is represented by submitting a general support ticket.

## 19. User Privacy Rights

Under applicable Zimbabwean law, you may have rights to information about use, access, objection, correction and deletion in the circumstances the law permits. A request may require proportionate identity verification; one user should not obtain another person's information by making a request.

Use the confirmed privacy contact to explain the information or processing concerned. If a request cannot be fulfilled in full, the controller should give a lawful explanation and identify available complaint routes. [TO BE CONFIRMED: the operational request procedure and statutory time limits applicable to each request.] This notice does not promise an unlimited erasure right or a portability right that has not been established under the applicable law.

## 20. Children's Privacy

The reviewed workflow does not implement a verified guardian-consent or child-account process. [POLICY REQUIRING CONFIRMATION: minimum account-holder age, accompanied child travel and any collection concerning children.] Do not represent the service as approved for independent use by children while these matters remain unresolved.

If children's information is involved, the controller must assess the applicable consent, safeguarding and other legal requirements rather than relying on an adult's Terms checkbox. Report a suspected child account or inappropriate disclosure to the confirmed privacy contact. Any removal or restriction should consider lawful safety and evidence-retention needs.

## 21. Cookies and Similar Technologies, Where Applicable

The website and app can use local storage or local preferences for application state. The web code supports persisted preview/workspace state and administrator session handling; the deployed website must be assessed for the actual storage keys and cookie behaviour. Hosting and third-party services may generate their own necessary technical requests.

No general analytics or advertising-cookie integration was identified in the reviewed public website flow. This is not a guarantee about infrastructure injected outside the repository. [TO BE CONFIRMED: a live cookie/storage inventory, purposes, recipients and durations.] Do not deploy non-essential tracking without the assessment, notice and choice required by applicable law. Browser settings may remove local state but do not delete server records.

## 22. Push Notifications and Communication Preferences

Essential account verification, trip information and security messages support the requested service. The backend stores notification preferences and supports push-token registration; handset push permission, registration and provider delivery still require operational verification. An in-app preference is not proof that push is enabled or that every message will arrive.

Optional marketing must be assessed separately and, where consent is required, use an unselected, specific choice with an effective withdrawal route. Accepting Terms is not marketing consent. You can change available in-app settings and operating-system notification permissions, but turning off notifications may reduce timely trip updates and does not erase existing records.

## 23. Changes to This Privacy Policy

An approved notice should show a version and effective date. Material changes in collection, purposes, recipients or transfers should be communicated appropriately before the changed processing where required. New consent must be obtained separately when the law requires it; publication alone is not a substitute.

[TO BE CONFIRMED: the final effective date, approval owner, version archive and notification procedure.] This draft is a review document and does not retrospectively authorise processing.

## 24. Complaints and Contact Details

Trivia is developed by MOrdec Solutions (Pvt) Ltd. [TO BE CONFIRMED BEFORE PUBLICATION: the operational data controller, service address, privacy/support contact and DPO contact where applicable.] We have not invented a telephone number, email address or named officer.

Raise a privacy concern through the confirmed channel when available. You may also approach Zimbabwe's competent Data Protection Authority, POTRAZ, using its verified official channels; an internal complaint is not a waiver of that right. The Cyber and Data Protection Act [Chapter 12:07] and SI 155 of 2024 are relevant to the controller's review. No regulatory licensing, registration, approval or complete legal compliance is asserted by this notice.
