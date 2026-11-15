import { projectConfig } from "../config/project";
export const money = (
  value: number,
  currency: string = projectConfig.defaultCurrency,
) =>
  new Intl.NumberFormat(projectConfig.locale, {
    style: "currency",
    currency,
  }).format(value);
export function downloadReceipt(text: string, name = "trivia-receipt.txt") {
  const url = URL.createObjectURL(
    new Blob(
      [
        `${projectConfig.productName.toUpperCase()} — DEMONSTRATION RECEIPT\nNot proof of payment\n\n${text}`,
      ],
      { type: "text/plain" },
    ),
  );
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}
