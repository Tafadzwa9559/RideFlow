import { projectConfig } from "../config/project";

/** Formatting validation only; account verification remains a backend responsibility.
 * Zimbabwe mobile prefixes follow POTRAZ's plan (71, 73, 77, 78).
 * Other countries accept E.164 structure without pretending to verify assignment.
 * Reference: https://www.ituob.org/issues/1108-en/#zimbabwe-263
 */
export function normalisePhone(value: string): string | null {
  let phone = value.trim().replace(/[\s().-]/g, "");
  if (phone.startsWith("00")) phone = `+${phone.slice(2)}`;
  if (/^263\d+$/.test(phone)) phone = `+${phone}`;
  if (!phone.startsWith("+")) {
    const national = phone.replace(/^0/, "");
    if (!/^(?:7[1378]\d{7}|2\d{8,9})$/.test(national)) return null;
    phone = `${projectConfig.dialCode}${national}`;
  }
  if (!/^\+[1-9]\d{7,14}$/.test(phone)) return null;
  if (
    phone.startsWith(projectConfig.dialCode) &&
    !/^(?:7[1378]\d{7}|2\d{8,9})$/.test(
      phone.slice(projectConfig.dialCode.length),
    )
  )
    return null;
  return phone;
}

function instant(value: string | number | Date): Date | null {
  // Never interpret backend timestamps in the browser's host timezone.
  if (typeof value === "string" && !/(?:Z|[+-]\d{2}:\d{2})$/i.test(value))
    return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}
export function formatDate(
  value: string | number | Date,
  options: Intl.DateTimeFormatOptions = {},
): string {
  const date = instant(value);
  return date
    ? new Intl.DateTimeFormat(projectConfig.locale, {
        day: "2-digit",
        month: "short",
        year: "numeric",
        ...options,
        timeZone: projectConfig.timezone,
      }).format(date)
    : "Date unavailable";
}
export function formatDateTime(value: string | number | Date): string {
  return formatDate(value, {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZoneName: "short",
  });
}
export function currentYear(): number {
  return Number(
    new Intl.DateTimeFormat(projectConfig.locale, {
      year: "numeric",
      timeZone: projectConfig.timezone,
    }).format(new Date()),
  );
}
