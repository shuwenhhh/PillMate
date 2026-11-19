"""Public, self-contained support pages. No authentication or health-data access."""

from html import escape
from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from .config import settings

router = APIRouter()


def contact() -> str:
    email = settings.support_email.strip()
    if not email:
        return '<p>Support contact details will be published before public release.</p>'
    safe_email = escape(email, quote=True)
    return f'<p>Email <a href="mailto:{safe_email}">{safe_email}</a> for support or privacy questions. Please do not include medical records, passwords, or Apple sign-in credentials.</p>'


def page(title: str, body: str) -> HTMLResponse:
    return HTMLResponse(f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="MediStar {escape(title)}">
<title>{escape(title)} · MediStar</title>
<style>
:root {{color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color:#24203f; background:#f6f3ff;}}
body {{margin:0; line-height:1.7;}} header,main,footer {{max-width:760px; margin:auto; padding:24px;}}
header {{display:flex; justify-content:space-between; flex-wrap:wrap; gap:16px;}} nav {{display:flex;gap:20px;}}
a {{color:#5940c5; text-underline-offset:4px; overflow-wrap:anywhere;}} a:focus-visible {{outline:3px solid #7151df;outline-offset:4px;}}
main {{background:#fff;border-radius:24px;box-sizing:border-box;}} h1 {{font-size:clamp(28px,6vw,40px);line-height:1.2;}} h2 {{font-size:21px;margin-top:32px;}}
.meta,footer {{color:#645e77;font-size:14px;}} .intro {{font-size:18px;}} li {{margin-bottom:8px;}}
@media(max-width:800px) {{main {{margin:0 16px;}}}}
</style></head><body>
<header><strong>MediStar</strong><nav aria-label="Main"><a href="/privacy">Privacy Policy</a><a href="/support">Support</a></nav></header>
<main><h1>{escape(title)}</h1>{body}</main>
<footer>MediStar helps organize personal records. It does not provide diagnosis or treatment recommendations.</footer>
</body></html>''', headers={
        "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
    })


@router.get('/privacy', response_class=HTMLResponse, include_in_schema=False)
async def privacy() -> HTMLResponse:
    return page('Privacy Policy', '''
<p class="meta">Last updated November 3, 2026</p>
<p class="intro">This policy explains how MediStar handles your information when you use the app and these support pages.</p>
<h2>Records on your device</h2>
<p>Your medicines, dose history, health journal and profile are stored locally. The app does not sync this database with CloudKit and excludes its application-support storage from device backups. Guest mode uses the same local records on that device. Signing out does not delete those records.</p>
<h2>Optional AI summaries</h2>
<p>AI summaries require Sign in with Apple and your explicit consent. When you ask a question, relevant records from your selected date range and your question are sent to the MediStar backend hosted on Render and processed using the OpenAI API. Depending on your request, this may include medicine names, dose schedules, check-in dates and times, symptoms, notes and vital readings.</p>
<p>The app excludes profile name and email from the health-data payload and replaces local record identifiers with temporary request identifiers. Text you type may itself contain personal information, so only include what is needed for your question.</p>
<h2>Authentication</h2>
<p>Apple may provide an account identifier, name and email when you sign in. Credentials are stored in the iOS Keychain. An Apple identity token and nonce go to our backend to verify AI requests; they are not sent to OpenAI. MediStar does not receive your Apple password.</p>
<h2>Processing and retention</h2>
<p>The backend does not save the health request body, question or generated answer to a database. It keeps per-user request metadata and rate-limit counters in server memory. Operational logs contain request identifiers, durations, status codes and error types, without health request bodies. Generated conversations may be stored locally by the app.</p>
<p>Server-memory metadata is associated with your Apple account identifier and includes request identifiers, timestamps, response status and error types. These entries may remain until the server process restarts or you delete your account; there is currently no automatic retention deadline. Operational logs also include question categories, payload sizes and processing timings. Request identifiers can link logs to account metadata. We use this information for authentication, request limits, troubleshooting and service security, not advertising or tracking.</p>
<p>Under OpenAI's default API controls, prompts and responses may be retained in abuse-monitoring logs for up to 30 days, or longer when legally required or reasonably necessary to prevent harm. The app does not assume Zero Data Retention is enabled. API content is not used for model training by default.</p>
<p>OpenAI processing is subject to its service data controls; disabling response storage does not eliminate all provider retention. Hosting and AI providers may process technical information necessary to deliver and secure their services. See <a href="https://platform.openai.com/docs/guides/your-data">OpenAI data controls</a> and <a href="https://render.com/privacy">Render’s privacy policy</a> for their practices. Data may be processed outside your country.</p>
<h2>Reminders and tracking</h2>
<p>Medication reminders are scheduled on your device with notification permission. You can change that permission in iOS Settings. These public pages use no analytics scripts, advertising trackers or cookies. MediStar does not sell health information or use it for advertising.</p>
<h2>Your choices and deletion</h2>
<p>You can use local features as a guest without AI. Withdraw AI consent in Profile → AI analysis &amp; data. In Profile → Privacy &amp; data, signed-in users can choose Delete account &amp; data and authenticate with Apple again. After Apple authorization is revoked, the backend removes your in-memory request metadata and usage counters, and the app removes local medicines, journal entries, conversation history, profile, credentials and reminders. Guests can choose Delete all data to remove local data. This action cannot be undone. Signing out alone keeps local health records. Deletion does not retroactively erase provider logs subject to their retention policies.</p>
<h2>Support correspondence</h2>
<p>If you email support, your address and message will be handled to respond to your request. Avoid including sensitive health information.</p>
<h2>Changes and contact</h2>
<p>Policy updates will appear here with a revised date. Contact us for questions about this policy or your data.</p>
''' + contact())


@router.get('/support', response_class=HTMLResponse, include_in_schema=False)
async def support() -> HTMLResponse:
    return page('Support', '''
<p class="intro">Help with medicines, reminders, records and optional AI summaries in MediStar.</p>
<h2>Contact support</h2>
''' + contact() + '''
<p>For a technical issue, include your app version, iOS version and steps to reproduce it. Remove personal information from screenshots before sharing them.</p>
<h2>Getting started</h2>
<p>Choose Maybe later to use guest mode, then open Medicines and tap + to add a medicine and its schedule. Log taken doses from Today. Review dose history and your health journal in Records.</p>
<h2>Reminders are missing</h2>
<p>Check notification permission for MediStar in iOS Settings, your Focus settings, and the medicine’s reminder schedule. Reminders depend on device settings and operating-system behavior.</p>
<h2>AI summaries are unavailable</h2>
<p>Check your internet connection, sign in with Apple and review the AI consent prompt. If the service is temporarily unavailable, try again later. AI summarizes entered records and does not provide medical advice.</p>
<h2>Why does guest mode show old records?</h2>
<p>Records belong to the app’s local storage on this device. Signing out or updating the app does not erase them.</p>
<h2>Delete your data</h2>
<p>Open Profile → Privacy &amp; data → Delete all data and confirm. This permanently clears the app’s local records, profile, sign-in details, conversations and reminders. Save anything you need before doing this.</p>
<h2>Privacy</h2>
<p>Read our <a href="/privacy">Privacy Policy</a> for details about local storage, optional AI processing and your choices.</p>
''')
