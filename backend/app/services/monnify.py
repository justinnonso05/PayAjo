import httpx
import time
import logging
from typing import Optional
from app.core.config import settings
from app.core.security import monnify_basic_auth_header

logger = logging.getLogger(__name__)

class MonnifyClient:
    """
    Async HTTP client for Monnify Sandbox API.
    Handles authentication token caching and error logging.
    """

    def __init__(self):
        self.base_url = settings.MONNIFY_BASE_URL
        self.api_key = settings.MONNIFY_API_KEY
        self.secret_key = settings.MONNIFY_SECRET_KEY
        self.contract_code = settings.MONNIFY_CONTRACT_CODE

        # Token cache
        self._access_token: Optional[str] = None
        self._token_expires_at: float = 0.0

    async def _make_request(self, method: str, endpoint: str, auth_required: bool = True, **kwargs) -> dict:
        url = f"{self.base_url}{endpoint}"
        
        if auth_required:
            headers = kwargs.pop("headers", {})
            headers.update(await self._headers())
            kwargs["headers"] = headers
            
        async with httpx.AsyncClient() as client:
            try:
                response = await client.request(method, url, **kwargs)
                response.raise_for_status()
            except httpx.HTTPStatusError as e:
                logger.error(f"[Monnify HTTP Error] {method} {endpoint} - Status: {e.response.status_code} - Body: {e.response.text}")
                raise
            except Exception as e:
                logger.error(f"[Monnify Request Error] {method} {endpoint} - {str(e)}")
                raise

        body = response.json()
        if not body.get("requestSuccessful"):
            logger.error(f"[Monnify Logic Error] {method} {endpoint} - Payload: {body}")
            raise Exception(f"Monnify {endpoint} failed: {body.get('responseMessage')}")
            
        return body

    # -----------------------------------------------------------------------
    # Authentication
    # -----------------------------------------------------------------------

    async def _authenticate(self) -> str:
        """
        Fetch a Bearer token from Monnify using Basic Auth.
        Tokens are cached for their full lifetime (3600s) minus a 60s safety buffer.
        """
        if self._access_token and time.time() < self._token_expires_at:
            return self._access_token

        body = await self._make_request(
            "POST",
            "/api/v1/auth/login",
            auth_required=False,
            headers={
                "Authorization": monnify_basic_auth_header(self.api_key, self.secret_key),
                "Content-Type": "application/json",
            }
        )

        self._access_token = body["responseBody"]["accessToken"]
        expires_in = body["responseBody"].get("expiresIn", 3600)
        self._token_expires_at = time.time() + expires_in - 60

        return self._access_token

    async def _headers(self) -> dict:
        token = await self._authenticate()
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    # -----------------------------------------------------------------------
    # Reserved Accounts — Personal Wallet creation at signup
    # -----------------------------------------------------------------------

    async def create_reserved_account(
        self,
        account_reference: str,
        account_name: str,
        customer_email: str,
        customer_name: str,
        bvn: str = "22222222222",  # stubbed for sandbox (BVN verification is live-only)
    ) -> dict:
        """
        Create a Monnify Reserved Account for a user.
        Each user gets one at signup as their Personal Wallet funding account.
        """
        body = await self._make_request(
            "POST",
            "/api/v2/bank-transfer/reserved-accounts",
            json={
                "accountReference": account_reference,
                "accountName": account_name,
                "currencyCode": "NGN",
                "contractCode": self.contract_code,
                "customerEmail": customer_email,
                "customerName": customer_name,
                "getAllAvailableBanks": True,
                "bvn": bvn,
            },
            timeout=30.0,
        )
        return body["responseBody"]

    # -----------------------------------------------------------------------
    # Name Enquiry — validate a member's payout bank account
    # -----------------------------------------------------------------------

    async def validate_bank_account(self, account_number: str, bank_code: str) -> dict:
        """
        Calls Monnify Name Enquiry to validate an external payout account.
        Returns the resolved account name so the user can confirm before saving.
        """
        body = await self._make_request(
            "GET",
            "/api/v1/disbursements/account/validate",
            params={"accountNumber": account_number, "bankCode": bank_code},
            timeout=30.0,
        )
        return body["responseBody"]

    # -----------------------------------------------------------------------
    # Banks list — for frontend bank picker dropdown
    # -----------------------------------------------------------------------

    async def get_banks(self) -> list:
        """Returns Monnify's full list of bank names and codes."""
        body = await self._make_request(
            "GET",
            "/api/v1/banks",
            timeout=30.0,
        )
        return body["responseBody"]

    # -----------------------------------------------------------------------
    # Dynamic Virtual Accounts — Direct to Group (Path B)
    # -----------------------------------------------------------------------

    async def initialize_transaction(
        self,
        amount: float,
        customer_name: str,
        customer_email: str,
        payment_reference: str,
        payment_description: str,
    ) -> dict:
        """
        Step 1 for DVA: Create transaction intent.
        """
        body = await self._make_request(
            "POST",
            "/api/v1/merchant/transactions/init-transaction",
            json={
                "amount": amount,
                "customerName": customer_name,
                "customerEmail": customer_email,
                "paymentReference": payment_reference,
                "paymentDescription": payment_description,
                "currencyCode": "NGN",
                "contractCode": self.contract_code,
                "redirectUrl": "https://payajo.app/contribute/confirm",
                "paymentMethods": ["ACCOUNT_TRANSFER"]
            },
            timeout=30.0,
        )
        return body["responseBody"]

    async def init_bank_transfer(self, transaction_reference: str) -> dict:
        """
        Step 2 for DVA: Get actual payable account details.
        """
        body = await self._make_request(
            "POST",
            "/api/v1/merchant/bank-transfer/init-payment",
            json={
                "transactionReference": transaction_reference
            },
            timeout=30.0,
        )
        return body["responseBody"]

    # -----------------------------------------------------------------------
    # Disbursement — automatic payout to a rotation beneficiary
    # -----------------------------------------------------------------------

    async def initiate_transfer(
        self,
        reference: str,
        amount: float,
        narration: str,
        destination_bank_code: str,
        destination_account_number: str,
        destination_account_name: str,
        source_account_number: str = None,
    ) -> dict:
        """
        Initiates a Single Transfer (Disbursement) on Monnify.
        Expect status PENDING_AUTHORIZATION in sandbox (MFA is on by default).
        """
        source_account = source_account_number or settings.MONNIFY_WALLET_ACCOUNT or "9999999999"
        body = await self._make_request(
            "POST",
            "/api/v2/disbursements/single",
            json={
                "amount": amount,
                "reference": reference,
                "narration": narration,
                "destinationBankCode": destination_bank_code,
                "destinationAccountNumber": destination_account_number,
                "destinationAccountName": destination_account_name,
                "currency": "NGN",
                "sourceAccountNumber": source_account,
            },
            timeout=30.0,
        )
        return body["responseBody"]

    # -----------------------------------------------------------------------
    # OTP Authorization — Admin approves a PENDING_AUTHORIZATION payout
    # -----------------------------------------------------------------------

    async def authorize_transfer(self, reference: str, otp: str) -> dict:
        """Submit the admin's OTP to authorize a pending disbursement."""
        body = await self._make_request(
            "POST",
            "/api/v2/disbursements/single/validate-otp",
            json={"reference": reference, "authorizationCode": otp},
            timeout=30.0,
        )
        return body["responseBody"]

    # -----------------------------------------------------------------------
    # Resend OTP
    # -----------------------------------------------------------------------

    async def resend_otp(self, reference: str) -> dict:
        """Request Monnify to resend the OTP for a pending disbursement."""
        body = await self._make_request(
            "POST",
            "/api/v2/disbursements/single/resend-otp",
            json={"reference": reference},
            timeout=30.0,
        )
        return body["responseBody"]


# Singleton — imported everywhere by `from app.services.monnify import monnify_client`
monnify_client = MonnifyClient()
