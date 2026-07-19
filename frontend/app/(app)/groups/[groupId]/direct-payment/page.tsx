"use client";

import { CheckCircle2, Copy, Lock } from "lucide-react";
import { useRouter } from "next/navigation";
import QRCode from "qrcode";
import { use, useEffect, useRef, useState } from "react";
import { api, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import { formatAmount } from "@/lib/format";
import { useWalletTransactions } from "@/lib/hooks/use-wallet-transactions";
import type { DirectPaymentDetails } from "@/lib/types";

export default function DirectPaymentPage({ params }: { params: Promise<{ groupId: string }> }) {
  const { groupId } = use(params);
  const router = useRouter();
  const { refresh: refreshTransactions } = useWalletTransactions();

  const [details, setDetails] = useState<DirectPaymentDetails | null>(null);
  const [qrDataUrl, setQrDataUrl] = useState<string | null>(null);
  const [remaining, setRemaining] = useState(0);
  const [expired, setExpired] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    const stored = sessionStorage.getItem(`direct-payment-${groupId}`);
    if (!stored) {
      router.replace(`/groups/${groupId}/contribute`);
      return;
    }
    const parsed: DirectPaymentDetails = JSON.parse(stored);
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time hydration from sessionStorage/route data, not a render-loop concern
    setDetails(parsed);
    setRemaining(Math.max(0, new Date(parsed.expiresOn).getTime() - Date.now()));
    if (parsed.checkoutUrl) {
      QRCode.toDataURL(parsed.checkoutUrl, { width: 200, margin: 1, color: { dark: "#1D3108", light: "#FFFFFF" } })
        .then(setQrDataUrl)
        .catch(() => {});
    }
  }, [groupId, router]);

  useEffect(() => {
    if (!details) return;

    countdownRef.current = setInterval(() => {
      const left = new Date(details.expiresOn).getTime() - Date.now();
      setRemaining(Math.max(0, left));
      if (left <= 0) setExpired(true);
    }, 1000);

    pollRef.current = setInterval(async () => {
      try {
        const res = await api.get(endpoints.transactionStatus(details.paymentReference), authHeaders());
        const status = (res.data as { status?: string } | undefined)?.status;
        if (status === "successful") {
          setConfirmed(true);
          await refreshTransactions();
          if (pollRef.current) clearInterval(pollRef.current);
          if (countdownRef.current) clearInterval(countdownRef.current);
        }
      } catch {
        // transient network error — next poll tick will retry
      }
    }, 5000);

    return () => {
      if (pollRef.current) clearInterval(pollRef.current);
      if (countdownRef.current) clearInterval(countdownRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [details]);

  if (!details) return null;

  if (confirmed) {
    return (
      <div className="mx-auto flex max-w-md flex-col items-center px-6 py-16 text-center">
        <span className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-pale">
          <CheckCircle2 size={30} className="text-brand-accent" />
        </span>
        <h1 className="mt-5 font-display text-xl font-bold text-brand-dark">Contribution Received</h1>
        <p className="mt-2 text-sm text-brand-dark/55">₦{formatAmount(details.amount)} has been added to your group&apos;s pool.</p>
        <button
          type="button"
          onClick={() => {
            sessionStorage.removeItem(`direct-payment-${groupId}`);
            router.push(`/groups/${groupId}`);
          }}
          className="mt-8 w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark"
        >
          Done
        </button>
      </div>
    );
  }

  const minutes = Math.floor(remaining / 60000)
    .toString()
    .padStart(2, "0");
  const seconds = Math.floor((remaining % 60000) / 1000)
    .toString()
    .padStart(2, "0");

  return (
    <div className="mx-auto max-w-md px-6 py-8 sm:py-10">
      <h1 className="font-display text-xl font-bold text-brand-dark">Pay by Bank Transfer</h1>

      <div className={`mt-6 rounded-2xl py-3.5 text-center text-sm font-bold ${expired ? "bg-red-50 text-red-500" : "bg-brand-pale text-brand-accent"}`}>
        {expired ? "This account has expired" : `Expires in ${minutes}:${seconds}`}
      </div>

      <div className="mt-5 rounded-card bg-white p-5 shadow-sm">
        <p className="text-xs font-semibold text-brand-dark/50">Transfer exactly</p>
        <p className="mt-1 font-display text-3xl font-extrabold text-brand-dark">₦{formatAmount(details.amount)}</p>

        <div className="mt-5 space-y-3.5">
          <DetailRow label="Bank" value={details.bankName} />
          <DetailRow
            label="Account Number"
            value={details.accountNumber}
            onCopy={() => navigator.clipboard.writeText(details.accountNumber)}
          />
          <DetailRow label="Account Name" value={details.accountName} />
        </div>
      </div>

      {qrDataUrl && (
        <div className="mt-5 rounded-card bg-white p-5 text-center shadow-sm">
          <p className="text-xs font-semibold text-brand-dark/50">Or scan to pay another way</p>
          <p className="mt-1 text-[11px] text-brand-dark/40">Card, USSD, or transfer via Monnify checkout</p>
          <div className="mt-4 inline-block rounded-2xl border border-brand-dark/10 p-3">
            {/* eslint-disable-next-line @next/next/no-img-element -- data: URI from client-side QR generation, not an optimizable remote/static asset */}
            <img src={qrDataUrl} alt="Scan to pay" width={160} height={160} />
          </div>
        </div>
      )}

      <p className="mt-5 text-sm leading-relaxed text-brand-dark/55">
        This account is generated just for this contribution and can only be used once. Send exactly ₦{formatAmount(details.amount)} from any bank app
        before it expires. We&apos;ll confirm automatically once it lands.
      </p>

      <div className="mt-6 flex items-center gap-2.5">
        <div className="h-4 w-4 animate-spin rounded-full border-2 border-brand-accent border-t-transparent" />
        <p className="text-sm font-semibold text-brand-dark/50">Waiting for payment…</p>
      </div>

      <div className="mt-8 flex items-center justify-center gap-1.5 text-brand-dark/40">
        <Lock size={12} />
        <p className="text-[11px] font-semibold">Secured & powered by Monnify</p>
      </div>
    </div>
  );
}

function DetailRow({ label, value, onCopy }: { label: string; value: string; onCopy?: () => void }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-xs font-semibold text-brand-dark/50">{label}</span>
      <div className="flex items-center gap-1.5">
        <span className="font-display text-sm font-bold text-brand-dark">{value}</span>
        {onCopy && (
          <button type="button" onClick={onCopy} className="text-brand-accent">
            <Copy size={14} />
          </button>
        )}
      </div>
    </div>
  );
}
