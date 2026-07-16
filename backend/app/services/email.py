from brevo import AsyncBrevo
from brevo.transactional_emails import (
    SendTransacEmailRequestSender,
    SendTransacEmailRequestToItem,
)
from app.core.config import settings


def _get_brevo_client():
    return AsyncBrevo(api_key=settings.BREVO_API_KEY)


import logging

logger = logging.getLogger(__name__)

async def send_email(to_email: str, to_name: str, subject: str, html_content: str) -> bool:
    """
    Send a transactional email via Brevo.
    Returns True on success, False on failure (non-fatal).
    """
    try:
        client = _get_brevo_client()
        await client.transactional_emails.send_transac_email(
            subject=subject,
            html_content=html_content,
            sender=SendTransacEmailRequestSender(
                name=settings.EMAIL_FROM_NAME,
                email=settings.EMAIL_FROM_ADDRESS,
            ),
            to=[
                SendTransacEmailRequestToItem(
                    email=to_email,
                    name=to_name,
                )
            ],
        )
        return True
    except Exception as e:
        # Log but never crash the main flow over an email failure
        logger.error(f"[EMAIL ERROR] Failed to send to {to_email}: {e}")
        if hasattr(e, 'body'):
             logger.error(f"[EMAIL ERROR BODY] {e.body}")
        elif hasattr(e, 'response') and hasattr(e.response, 'text'):
             logger.error(f"[EMAIL ERROR RESPONSE] {e.response.text}")
        return False



# ---------------------------------------------------------------------------
# Email templates
# ---------------------------------------------------------------------------

async def send_otp_email(to_email: str, to_name: str, otp_code: str, reason: str) -> bool:
    """Send a one-time PIN for sensitive actions (PIN reset, payout bank change)."""
    subject = f"Your AjoPay verification code"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color: #1a1a2e;">Your AjoPay Code</h2>
      <p>Hi {to_name},</p>
      <p>You requested a verification code to <strong>{reason}</strong>.</p>
      <div style="background: #f4f4f4; border-radius: 8px; padding: 24px; text-align: center; margin: 24px 0;">
        <span style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #1a1a2e;">{otp_code}</span>
      </div>
      <p>This code expires in <strong>{settings.OTP_EXPIRE_MINUTES} minutes</strong>.</p>
      <p style="color: #888; font-size: 13px;">
        If you didn't request this, please ignore this email and ensure your account is secure.
      </p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
      <p style="color: #888; font-size: 12px;">AjoPay — Rotating savings, reimagined.</p>
    </div>
    """
    return await send_email(to_email, to_name, subject, html)


async def send_welcome_email(to_email: str, to_name: str) -> bool:
    """Welcome email sent after successful signup."""
    subject = "Welcome to AjoPay 🎉"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color: #1a1a2e;">Welcome to AjoPay, {to_name}!</h2>
      <p>Your account is ready. Your personal wallet has been created — 
         fund it by transferring to your reserved account number in the app.</p>
      <p>Next steps:</p>
      <ul>
        <li>Set up your 4-digit transaction PIN</li>
        <li>Add your payout bank account</li>
        <li>Join or create an Ajo group</li>
      </ul>
      <p style="color: #888; font-size: 12px;">AjoPay — Rotating savings, reimagined.</p>
    </div>
    """
    return await send_email(to_email, to_name, subject, html)


async def send_contribution_confirmed_email(
    to_email: str, to_name: str, amount: float, group_name: str, cycle: int
) -> bool:
    subject = f"Contribution confirmed — {group_name}"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color: #1a1a2e;">Contribution Received ✅</h2>
      <p>Hi {to_name},</p>
      <p>Your contribution of <strong>₦{amount:,.0f}</strong> to <strong>{group_name}</strong> 
         (Cycle {cycle}) has been confirmed.</p>
      <p style="color: #888; font-size: 12px;">AjoPay — Rotating savings, reimagined.</p>
    </div>
    """
    return await send_email(to_email, to_name, subject, html)


async def send_payout_received_email(
    to_email: str, to_name: str, amount: float, group_name: str
) -> bool:
    subject = f"Payout received — {group_name} 🎉"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color: #1a1a2e;">Your Payout is In! 🎉</h2>
      <p>Hi {to_name},</p>
      <p><strong>₦{amount:,.0f}</strong> from <strong>{group_name}</strong> has been added to your AjoPay wallet.</p>
      <p>You can withdraw to your registered bank account from the app at any time.</p>
      <p style="color: #888; font-size: 12px;">AjoPay — Rotating savings, reimagined.</p>
    </div>
    """
    return await send_email(to_email, to_name, subject, html)


async def send_payout_pending_auth_email(
    to_email: str, to_name: str, amount: float, group_name: str, cycle: int
) -> bool:
    """Notifies the admin that a disbursement is awaiting OTP authorization."""
    subject = f"Action required: Approve payout for {group_name}"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color: #e65c00;">Payout Awaiting Your Approval</h2>
      <p>Hi {to_name},</p>
      <p>A payout of <strong>₦{amount:,.0f}</strong> for <strong>{group_name}</strong> 
         (Cycle {cycle}) is waiting for your authorization.</p>
      <p>Check your Monnify-registered email for the OTP, then approve it from the AjoPay admin dashboard.</p>
      <p style="color: #888; font-size: 12px;">AjoPay — Rotating savings, reimagined.</p>
    </div>
    """
    return await send_email(to_email, to_name, subject, html)
