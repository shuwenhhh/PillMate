# MediStar AI Assistant: Privacy, Consent, and Deletion Draft

**Status:** Product and legal draft; not approved for production publication

**Version:** 0.2

**Last updated:** 2026-09-15

**Scope:** data processed specifically to provide the MediStar AI Assistant

This draft defines implementation requirements and proposed user-facing language. It does not claim that unfinished controls already exist. Before launch, the operator must replace every bracketed placeholder, verify actual infrastructure and retention behavior, complete jurisdiction-specific legal review, and make the published notice match the shipped product.

## Plain-language user notice draft

### What the AI Assistant does

The AI Assistant summarizes the MediStar records you select. It can describe counts, dates, intervals, recorded co-occurrences, and text you entered. It does not diagnose conditions or recommend treatment or medication changes, and it is not an emergency service.

### What is sent when you use it

Only after you choose to run the AI Assistant, MediStar sends the minimum information needed for that request to MediStar's backend and its AI service provider. Depending on your selection, this may include:

- the requested date range, time zone, language, question, request identifier, and consent version;
- only medicines referenced by a selected medication event, with the medicine name and, when relevant to the question, its dose label, schedule window, or frequency;
- recorded dose/check-in dates and times and, when relevant to the question, feelings, heart rate, blood pressure, and check-in notes; and
- when relevant to the question, journal mood, symptoms, severity, heart rate, blood pressure, and record times. Journal notes are excluded.

Persistent local record identifiers are replaced with temporary, request-only identifiers before transmission. Preset questions further minimize the payload: consistency excludes journal and subjective fields, symptoms excludes unrelated journal/vital fields, and vitals excludes subjective fields. A free-text question or doctor summary can use all allowlisted fields in the selected period because the user-defined scope may require them.

Medicine names, dose information, symptoms, vital readings, and notes are sensitive health information.

The AI health-data payload does not include your name, email address, street address, GPS location, device identifier, contacts, photos, or entire local database by default. A Sign in with Apple identity token and the one-time nonce used to obtain it are sent separately to MediStar's backend to authenticate an AI request. The backend verifies this credential and does not send it to OpenAI. An Apple identity token may contain Apple account claims such as a private account identifier and, when provided by Apple, an email address. Do not put identifying information about yourself or another person in a free-text question or note that you choose to send.

### Why the data is used

The selected data is used only to validate the request, calculate factual record summaries, check the input and output for safety, generate the requested response, protect the service from abuse, and operate or troubleshoot the service using content-free technical logs. It is not used by MediStar for advertising or sale.

MediStar must configure the API account not to opt in to model training. OpenAI states that API inputs and outputs are not used to train its models by default unless the organization explicitly opts in. See [OpenAI's data-use statement](https://openai.com/policies/how-your-data-is-used-to-improve-model-performance/).

### Who processes the data

The selected data is processed by:

- **MediStar operator:** [legal entity and address], acting as the service operator/data controller where applicable;
- **MediStar hosting provider:** [provider, processing region, and privacy link]; and
- **OpenAI:** the API provider used for safety moderation and response generation. See [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data) and the applicable OpenAI business terms/data processing addendum.

MediStar must not add another processor or move processing to a materially different region without updating the processor list and, where required, obtaining renewed consent.

### Retention

The intended MediStar-side retention schedule is:

| Data | Proposed retention rule |
| --- | --- |
| Health records stored locally in the app | Remain on the device until the user edits/deletes them or removes app data. Using or deleting AI Assistant data does not silently delete local health records. |
| Raw AI request payload and generated response on MediStar servers | Process in memory for the request and do not persist to an application database, analytics system, or log. Clear transient copies when the request completes or fails. |
| Cache, queue, or temporary file containing health content | Prohibited by default. If later required, it needs a new documented retention period, encryption, access control, and renewed consent before release. |
| Operational log | Request ID, duration, status code, coarse safety outcome, and error type only; no question, note, medicine name, vital value, prompt, or model response. Delete within 30 days. |
| Consent receipt | Account/pseudonymous user ID, notice version, decision, locale, and timestamp only. Keep while consent is active; after withdrawal or account deletion, delete from active systems within 30 days and encrypted backups within 90 days, unless a documented legal obligation requires a minimal record for longer. |

The OpenAI API request must set `store=false` and must not use conversations, threads, files, background mode, hosted tools, or another feature that creates persistent application state for this use case. OpenAI's current documentation says API data is not used for training by default, but default abuse-monitoring logs may retain customer content for up to 30 days unless approved retention controls apply. `store=false` does not by itself remove those abuse-monitoring logs. The operator must disclose the actual configured OpenAI retention mode and re-check it before every production release.

### Your choices and rights

You can use MediStar's local record features without consenting to the AI Assistant. You may withdraw AI consent or request deletion of AI-service data from the AI Privacy controls described below. Withdrawal stops new AI requests immediately and does not affect earlier lawful processing.

Depending on where you live, you may also have rights to access, correct, export, restrict, object to, or complain about processing. Contact [privacy email] or [postal address]. Identity verification must request no more information than necessary.

### Safety and security

MediStar uses data minimization, transport encryption, access controls, content-free operational logs, and separation of the mobile app from the API credential. No system can guarantee absolute security. Report privacy or security concerns to [security/privacy contact].

### Children and regulated use

The operator must set and publish an age policy before launch. The AI Assistant must not be offered to children below the applicable digital-consent age without a reviewed parental-consent flow. If the service will process regulated protected health information, the operator must complete the required contracts and compliance review, including an appropriate business associate agreement where applicable, before that processing begins.

## Consent requirements

Consent must be specific, informed, freely given where the law requires consent, and separate from acceptance of general app terms.

### When to ask

Show a just-in-time consent screen immediately before the first AI request. Ask again when the purpose, sensitive data categories, provider, retention behavior, processing region, or product boundary changes materially. A changed notice version alone does not require renewed consent unless the change is material.

### Interaction rules

- The consent control starts off unchecked/off; scrolling or continuing to use local app features is not consent.
- “Agree and use AI Assistant” and “Not now” receive comparable visual weight.
- Declining keeps local medication and journal features usable and sends no AI request.
- Consent is not bundled with analytics, marketing, training opt-in, or unrelated data sharing.
- The screen links to the full notice and shows the notice version.
- The server rejects an AI request if its `consentVersion` is missing, unknown, outdated, withdrawn, or does not belong to the authenticated user.

### Required consent copy

The localized screen must communicate all of the following before opt-in:

1. “AI Assistant summarizes selected records; it does not diagnose or recommend treatment or medication changes.”
2. “Your selected medicine details, dose records, symptoms, vital readings, notes, and question may be sent to MediStar's server and OpenAI.”
3. “The health-data payload excludes your name, email, profile, location, device ID, and full local database. An Apple token and one-time nonce go only to MediStar's server for request authentication and are not sent to OpenAI.”
4. “OpenAI does not train on API data by default, but content may be retained in abuse-monitoring logs for up to 30 days under the configured service terms.”
5. “You can use local MediStar features without AI, withdraw consent at any time, and request deletion from AI Privacy controls.”
6. “For a possible emergency, contact local emergency services; MediStar cannot contact them for you.”

### Consent receipt

Store only:

- authenticated account or pseudonymous user ID;
- notice/consent version;
- `accepted` or `declined`/`withdrawn` state;
- UTC timestamp; and
- presented locale.

Never store a health-record snapshot with the receipt. Every server request must be auditable back to an active receipt without placing health content in logs.

## Withdrawal and deletion rules

The product must provide two separate controls so their effects are clear:

1. **Turn off AI Assistant:** withdraws consent and blocks future transmissions immediately; it does not delete local records.
2. **Delete my AI data:** deletes any MediStar-held AI content and operational linkage as described below; the user may separately choose whether to keep AI consent active for future requests.

Account deletion must include “Delete my AI data” and revoke AI consent.

### Deletion workflow

1. Authenticate the requester without collecting unnecessary identity documents.
2. Immediately block new AI processing when the request also withdraws consent or deletes the account.
3. Delete any persisted raw request, response, cache, queue item, or derived content associated with the user. The intended architecture stores none; the deletion job must still be idempotent and verify all registered stores.
4. Break the link between the user and content-free operational logs. Security records already irreversibly de-identified may finish their 30-day retention.
5. Delete the consent receipt from active systems within 30 days and encrypted backups within 90 days, subject only to a documented legal hold or mandatory retention rule.
6. Submit provider-side deletion when the provider exposes a deletion mechanism for the data type. If a provider abuse-monitoring copy cannot be individually deleted, disclose that limitation and its maximum applicable retention rather than claiming immediate deletion.
7. Return an in-app confirmation stating what was deleted, what was not deleted (especially on-device health records), the request date, and any lawful exception or provider expiry still pending.

Deletion must be safe to retry, scoped to the authenticated user, and tested so one user can never delete or discover another user's data.

### Exceptions

Retain data after a valid deletion request only when required by law, a documented legal hold, fraud/security investigation, or defense of legal claims. Isolate and restrict the minimum retained data, prevent all other use, record the reason and expiry, and tell the user unless legally prohibited.

## Engineering invariants

- SwiftData remains the source of truth for local records; AI use never uploads the whole database.
- No API key or provider credential is shipped in the iOS app.
- Free-text health content never appears in analytics, crash reports, traces, alerts, or support tickets by default.
- Production and development data are isolated. Real user health data is prohibited in fixtures, screenshots, demos, and automated tests.
- Access to production operational systems uses least privilege and is audited.
- Backups, caches, dead-letter queues, observability tools, and support exports are included in the data inventory and deletion audit.
- A processor/retention configuration change fails closed until the notice and consent version are reviewed.

## Pre-launch checklist

- [ ] Replace operator, hosting, region, age, and contact placeholders.
- [ ] Obtain privacy/legal review for every launch jurisdiction and App Store disclosure.
- [ ] Verify the production OpenAI project has training opt-in disabled, `store=false` is enforced, and the documented retention mode matches the consent screen.
- [ ] Decide whether the available provider controls and contracts are appropriate for sensitive health data; do not launch regulated processing without required agreements.
- [ ] Implement and test consent versioning, withdrawal, deletion, authentication, and per-user isolation.
- [ ] Confirm logs and monitoring contain no questions, notes, medicine data, vital readings, prompts, or responses.
- [ ] Publish the final privacy notice in every supported locale and keep a version history.
- [ ] Run a deletion drill covering active stores, backups, processors, and user confirmation.

## Reference basis

External facts in this draft were checked on 2026-09-14 against:

- [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data)
- [How OpenAI uses data to improve model performance](https://openai.com/policies/how-your-data-is-used-to-improve-model-performance/)
- [OpenAI Data Processing Addendum](https://openai.com/policies/data-processing-addendum/)

These provider documents can change. They must be re-verified before publication rather than copied into a permanent promise.
