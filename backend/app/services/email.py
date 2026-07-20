import logging
from brevo import AsyncBrevo
from brevo.transactional_emails import (
    SendTransacEmailRequestSender,
    SendTransacEmailRequestToItem,
)
from app.core.config import settings
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os

logger = logging.getLogger(__name__)

# Setup Jinja2 Environment
template_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "templates")
env = Environment(
    loader=FileSystemLoader(template_dir),
    autoescape=select_autoescape(['html', 'xml'])
)

def _get_brevo_client():
    return AsyncBrevo(api_key=settings.BREVO_API_KEY)

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
    template = env.get_template("emails/otp.html")
    html = template.render(
        to_name=to_name,
        reason=reason,
        otp_code=otp_code,
        expire_minutes=settings.OTP_EXPIRE_MINUTES
    )
    return await send_email(to_email, to_name, "Your PayAjo verification code", html)


async def send_welcome_email(to_email: str, to_name: str) -> bool:
    template = env.get_template("emails/welcome.html")
    html = template.render(to_name=to_name)
    return await send_email(to_email, to_name, "Welcome to PayAjo 🎉", html)


async def send_contribution_confirmed_email(
    to_email: str, to_name: str, amount: float, group_name: str, cycle: int
) -> bool:
    template = env.get_template("emails/contribution_confirmed.html")
    html = template.render(
        to_name=to_name,
        amount=amount,
        group_name=group_name,
        cycle=cycle
    )
    return await send_email(to_email, to_name, f"Contribution confirmed — {group_name}", html)


async def send_payout_received_email(
    to_email: str, to_name: str, amount: float, group_name: str
) -> bool:
    template = env.get_template("emails/payout_received.html")
    html = template.render(
        to_name=to_name,
        amount=amount,
        group_name=group_name
    )
    return await send_email(to_email, to_name, f"Payout received — {group_name} 🎉", html)


async def send_payout_pending_auth_email(
    to_email: str, to_name: str, amount: float, group_name: str, cycle: int
) -> bool:
    """Notifies the admin that a disbursement is awaiting OTP authorization."""
    template = env.get_template("emails/base.html")
    content = f"""
    <p>Hi {to_name},</p>
    <p>A payout of <strong>₦{amount:,.0f}</strong> for <strong>{group_name}</strong> 
       (Cycle {cycle}) is waiting for your authorization.</p>
    <p>Check your Monnify-registered email for the OTP, then approve it from the PayAjo admin dashboard.</p>
    """
    html = template.render()
    html = html.replace("{% block content %}{% endblock %}", content)
    return await send_email(to_email, to_name, f"Action required: Approve payout for {group_name}", html)

async def send_group_invite_email(
    to_email: str, to_name: str, group_name: str, inviter_name: str
) -> bool:
    """Notifies a user that they have been invited to join a group."""
    template = env.get_template("emails/base.html")
    content = f"""
    <p>Hi {to_name},</p>
    <p><strong>{inviter_name}</strong> has invited you to join the Ajo group <strong>{group_name}</strong>.</p>
    <p>Open the PayAjo app to review the group details and accept or reject this invitation.</p>
    """
    html = template.render()
    html = html.replace("{% block content %}{% endblock %}", content)
    return await send_email(to_email, to_name, f"You've been invited to join {group_name}", html)

async def send_group_join_approved_email(
    to_email: str, to_name: str, group_name: str
) -> bool:
    """Notifies a user that their request to join a group via invite code was approved."""
    template = env.get_template("emails/base.html")
    content = f"""
    <p>Hi {to_name},</p>
    <p>The admin of <strong>{group_name}</strong> has approved your join request.</p>
    <p>You are now a member of the group and can view the rotation and start making contributions.</p>
    """
    html = template.render()
    html = html.replace("{% block content %}{% endblock %}", content)
    return await send_email(to_email, to_name, f"Your request to join {group_name} was approved", html)

async def send_kyc_completed_email(to_email: str, to_name: str) -> bool:
    template = env.get_template("emails/kyc_completed.html")
    html = template.render(to_name=to_name)
    return await send_email(to_email, to_name, "KYC Completed", html)

async def send_wallet_funded_email(to_email: str, to_name: str, amount: float) -> bool:
    template = env.get_template("emails/wallet_funded.html")
    html = template.render(to_name=to_name, amount=amount)
    return await send_email(to_email, to_name, "Wallet Funded", html)

async def send_transfer_receipt_email(
    to_email: str, to_name: str, amount: float, recipient_name: str, date: str, reference: str
) -> bool:
    template = env.get_template("emails/transfer_receipt.html")
    html = template.render(
        to_name=to_name,
        amount=amount,
        recipient_name=recipient_name,
        date=date,
        reference=reference
    )
    return await send_email(to_email, to_name, "Transfer Receipt", html)
