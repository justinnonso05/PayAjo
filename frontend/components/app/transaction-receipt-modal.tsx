"use client";

import { Copy, Download } from "lucide-react";
import { useEffect, useState } from "react";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import { formatAmount, formatShortDate, formatTime } from "@/lib/format";
import { downloadReceiptPdf } from "@/lib/receipt-pdf";
import type { TransactionReceipt } from "@/lib/types";
import { Modal } from "./modal";
import { StatusPill } from "./status-pill";

const CREDIT_KEYWORDS = ["deposit", "topup", "payout", "refund", "credit", "received", "reversal"];
const DEBIT_KEYWORDS = ["withdraw", "contribution", "debit", "payment"];

function isCreditType(type: string) {
  const t = type.toLowerCase().replace(/[_-]/g, "");
  if (DEBIT_KEYWORDS.some((k) => t.includes(k))) return false;
  return CREDIT_KEYWORDS.some((k) => t.includes(k));
}

function friendlyType(type: string) {
  return type
    .replace(/_/g, " ")
    .split(" ")
    .map((w) => (w ? w[0].toUpperCase() + w.slice(1).toLowerCase() : w))
    .join(" ");
}

function toneForStatus(status: string): "success" | "warning" | "danger" | "neutral" {
  switch (status.toLowerCase()) {
    case "success":
    case "successful":
    case "completed":
      return "success";
    case "pending":
    case "processing":
      return "warning";
    case "failed":
    case "reversed":
      return "danger";
    default:
      return "neutral";
  }
}

/** Tapping a transaction opens this — fetches `GET /users/me/wallet/transactions/{id}` and renders it as a receipt. */
export function TransactionReceiptModal({ transactionId, onClose }: { transactionId: string; onClose: () => void }) {
  const [receipt, setReceipt] = useState<TransactionReceipt | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .get(endpoints.walletTransactionReceipt(transactionId), authHeaders())
      .then((res) => setReceipt(res.data as TransactionReceipt))
      .catch((err) => setError(err instanceof ApiError ? err.message : "Could not load this receipt."))
      .finally(() => setIsLoading(false));
  }, [transactionId]);

  return (
    <Modal title="Transaction Receipt" onClose={onClose}>
      {isLoading ? (
        <div className="flex h-40 items-center justify-center">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-brand-accent border-t-transparent" />
        </div>
      ) : error || !receipt ? (
        <div className="flex h-32 items-center justify-center text-center text-sm text-brand-dark/50">{error || "Could not load this receipt."}</div>
      ) : (
        <ReceiptBody receipt={receipt} />
      )}
    </Modal>
  );
}

function ReceiptBody({ receipt }: { receipt: TransactionReceipt }) {
  const credit = isCreditType(receipt.type);
  const [isDownloading, setIsDownloading] = useState(false);
  const [downloadError, setDownloadError] = useState<string | null>(null);

  const handleDownload = async () => {
    setIsDownloading(true);
    setDownloadError(null);
    try {
      await downloadReceiptPdf(receipt);
    } catch {
      setDownloadError("Could not generate the PDF. Please try again.");
    } finally {
      setIsDownloading(false);
    }
  };

  return (
    <div>
      <div className="flex flex-col items-center gap-2 py-2">
        <p className={`font-display text-3xl font-bold ${credit ? "text-brand-accent" : "text-brand-dark"}`}>
          {credit ? "+" : "-"}₦{formatAmount(Math.abs(receipt.amount))}
        </p>
        <StatusPill label={receipt.status} tone={toneForStatus(receipt.status)} />
      </div>

      <div className="mt-4 divide-y divide-brand-dark/5 rounded-2xl bg-soft-gray px-4">
        <Row label="Type" value={friendlyType(receipt.type)} />
        <Row label="Date" value={formatShortDate(receipt.date)} />
        <Row label="Time" value={formatTime(receipt.date)} />
        {receipt.sender_name && <Row label="From" value={receipt.sender_name} />}
        {receipt.recipient_name && <Row label="To" value={receipt.recipient_name} />}
        {receipt.narration && <Row label="Narration" value={receipt.narration} />}
        {receipt.reference && (
          <div className="flex items-center justify-between gap-3 py-3">
            <span className="shrink-0 text-xs font-semibold text-brand-dark/50">Reference</span>
            <button
              type="button"
              onClick={() => navigator.clipboard.writeText(receipt.reference!)}
              className="flex min-w-0 items-center gap-1.5 font-display text-sm font-bold text-brand-dark"
            >
              <span className="truncate">{receipt.reference}</span>
              <Copy size={13} className="shrink-0 text-brand-dark/40" />
            </button>
          </div>
        )}
      </div>

      {downloadError && <p className="mt-3 text-xs font-semibold text-red-500">{downloadError}</p>}

      <button
        type="button"
        onClick={handleDownload}
        disabled={isDownloading}
        className="mt-5 flex w-full items-center justify-center gap-2 rounded-full border border-brand-dark/15 py-3 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.01] active:scale-95 disabled:opacity-60"
      >
        {isDownloading ? (
          <span className="h-4 w-4 animate-spin rounded-full border-2 border-brand-dark/30 border-t-brand-dark" />
        ) : (
          <Download size={15} />
        )}
        {isDownloading ? "Preparing…" : "Download as PDF"}
      </button>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-3">
      <span className="text-xs font-semibold text-brand-dark/50">{label}</span>
      <span className="max-w-[65%] text-right font-display text-sm font-bold text-brand-dark">{value}</span>
    </div>
  );
}
