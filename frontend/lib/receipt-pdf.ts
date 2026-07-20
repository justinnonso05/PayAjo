import { jsPDF } from "jspdf";
import { formatAmount, formatShortDate, formatTime } from "./format";
import type { TransactionReceipt } from "./types";

function friendlyType(type: string) {
  return type
    .replace(/_/g, " ")
    .split(" ")
    .map((w) => (w ? w[0].toUpperCase() + w.slice(1).toLowerCase() : w))
    .join(" ");
}

function isCreditType(type: string) {
  const t = type.toLowerCase().replace(/[_-]/g, "");
  const credit = ["deposit", "topup", "payout", "refund", "credit", "received", "reversal"];
  const debit = ["withdraw", "contribution", "debit", "payment"];
  if (debit.some((k) => t.includes(k))) return false;
  return credit.some((k) => t.includes(k));
}

async function arrayBufferToBase64(buffer: ArrayBuffer): Promise<string> {
  const blob = new Blob([buffer]);
  const dataUrl = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
  return dataUrl.split(",")[1];
}

let cachedFonts: { plusJakarta: string; spaceGrotesk: string; logo: string } | null = null;

// Lazily fetched and cached — only paid for the first time someone actually
// downloads a receipt, not on every page load. The base14 PDF fonts jsPDF
// ships with have no ₦ or • glyphs, hence embedding our own.
async function loadAssets() {
  if (cachedFonts) return cachedFonts;
  const [plusJakartaBuf, spaceGroteskBuf, logoBuf] = await Promise.all([
    fetch("/fonts/PlusJakartaSans-Variable.ttf").then((r) => r.arrayBuffer()),
    fetch("/fonts/SpaceGrotesk-Variable.ttf").then((r) => r.arrayBuffer()),
    fetch("/images/logo.png").then((r) => r.arrayBuffer()),
  ]);
  cachedFonts = {
    plusJakarta: await arrayBufferToBase64(plusJakartaBuf),
    spaceGrotesk: await arrayBufferToBase64(spaceGroteskBuf),
    logo: await arrayBufferToBase64(logoBuf),
  };
  return cachedFonts;
}

/** Renders a transaction receipt as a one-page PDF and triggers a browser download — entirely client-side, no backend call. */
export async function downloadReceiptPdf(receipt: TransactionReceipt) {
  const assets = await loadAssets();

  const doc = new jsPDF({ unit: "pt", format: "a4" });
  doc.addFileToVFS("PlusJakartaSans.ttf", assets.plusJakarta);
  doc.addFont("PlusJakartaSans.ttf", "PlusJakartaSans", "normal");
  doc.addFileToVFS("SpaceGrotesk.ttf", assets.spaceGrotesk);
  doc.addFont("SpaceGrotesk.ttf", "SpaceGrotesk", "normal");

  const pageWidth = doc.internal.pageSize.getWidth();
  const marginX = 48;

  const brandDark = "#1D3108";
  const brandAccent = "#5BA72D";
  const brandPale = "#E8F6E0";
  const muted = "#8A9182";
  const border = "#EDEFEA";

  // Header band
  doc.setFillColor(brandPale);
  doc.rect(0, 0, pageWidth, 110, "F");
  doc.addImage(`data:image/png;base64,${assets.logo}`, "PNG", marginX, 28, 40, 40);

  doc.setFont("SpaceGrotesk", "normal");
  doc.setFontSize(18);
  doc.setTextColor(brandDark);
  doc.text("PayAjo", marginX + 52, 46);

  doc.setFont("PlusJakartaSans", "normal");
  doc.setFontSize(9);
  doc.setTextColor(muted);
  doc.text("Save together. Grow together.", marginX + 52, 62);

  doc.setFont("SpaceGrotesk", "normal");
  doc.setFontSize(12);
  doc.setTextColor(brandDark);
  doc.text("Transaction Receipt", pageWidth - marginX, 46, { align: "right" });

  let y = 170;

  // Amount + status, centered
  const credit = isCreditType(receipt.type);
  doc.setFont("SpaceGrotesk", "normal");
  doc.setFontSize(30);
  doc.setTextColor(credit ? brandAccent : brandDark);
  const amountText = `${credit ? "+" : "-"} ₦${formatAmount(Math.abs(receipt.amount))}`;
  doc.text(amountText, pageWidth / 2, y, { align: "center" });

  y += 26;
  doc.setFillColor(brandPale);
  const statusText = receipt.status.toUpperCase();
  const statusWidth = doc.getTextWidth(statusText) + 24;
  doc.roundedRect(pageWidth / 2 - statusWidth / 2, y - 12, statusWidth, 20, 10, 10, "F");
  doc.setFont("PlusJakartaSans", "normal");
  doc.setFontSize(9);
  doc.setTextColor(brandAccent);
  doc.text(statusText, pageWidth / 2, y + 2, { align: "center" });

  y += 50;
  doc.setDrawColor(border);
  doc.line(marginX, y, pageWidth - marginX, y);
  y += 34;

  const rows: [string, string][] = [
    ["Type", friendlyType(receipt.type)],
    ["Date", formatShortDate(receipt.date)],
    ["Time", formatTime(receipt.date)],
  ];
  if (receipt.sender_name) rows.push(["From", receipt.sender_name]);
  if (receipt.recipient_name) rows.push(["To", receipt.recipient_name]);
  if (receipt.narration) rows.push(["Narration", receipt.narration]);
  if (receipt.reference) rows.push(["Reference", receipt.reference]);
  rows.push(["Transaction ID", receipt.transaction_id]);

  doc.setFontSize(11);
  for (const [label, value] of rows) {
    doc.setFont("PlusJakartaSans", "normal");
    doc.setTextColor(muted);
    doc.text(label, marginX, y);

    doc.setFont("SpaceGrotesk", "normal");
    doc.setTextColor(brandDark);
    const wrapped = doc.splitTextToSize(value, pageWidth - marginX * 2 - 140) as string[];
    doc.text(wrapped, pageWidth - marginX, y, { align: "right" });

    y += 18 * wrapped.length + 10;
    doc.setDrawColor(border);
    doc.line(marginX, y - 16, pageWidth - marginX, y - 16);
  }

  // Footer
  const pageHeight = doc.internal.pageSize.getHeight();
  doc.setDrawColor(border);
  doc.line(marginX, pageHeight - 70, pageWidth - marginX, pageHeight - 70);
  doc.setFont("PlusJakartaSans", "normal");
  doc.setFontSize(9);
  doc.setTextColor(muted);
  const now = new Date();
  doc.text(`Generated ${formatShortDate(now.toISOString())} · ${formatTime(now.toISOString())}`, marginX, pageHeight - 48);
  doc.text("This receipt was generated by PayAjo and is valid without a signature.", marginX, pageHeight - 34);

  doc.save(`payajo-receipt-${receipt.transaction_id.slice(0, 8)}.pdf`);
}
