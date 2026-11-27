/**
 * OpenCode Go usage
 *
 * `/usage` queries the OpenCode Zen usage endpoint for the OpenCode Go provider
 * and writes the rolling, weekly and monthly windows into the transcript.
 *
 * It never calls ctx.ui.setStatus(), so nothing is added to the footer.
 * Press Ctrl+O on the card to expand bars and the raw response data.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

const PROVIDER_ID = "opencode-go";
const USAGE_URL = "https://opencode.ai/zen/go/v1/usage";
const OFFICIAL_HOST = "opencode.ai";
const FETCH_TIMEOUT_MS = 15_000;
const MAX_BODY_BYTES = 64 * 1024;
const ENTRY_TYPE = "opencode-usage";

const WINDOW_DEFS = [
	{ key: "rolling", label: "Rolling" },
	{ key: "weekly", label: "Weekly" },
	{ key: "monthly", label: "Monthly" },
] as const;

type WindowKey = (typeof WINDOW_DEFS)[number]["key"];

interface UsageWindow {
	key: WindowKey;
	label: string;
	status: string;
	usedPercent: number;
	/** Epoch milliseconds. */
	resetsAt?: number;
}

interface UsageData {
	checkedAt: number;
	source?: string;
	windows: UsageWindow[];
	notes: string[];
}

export default function opencodeUsageExtension(pi: ExtensionAPI) {
	pi.registerEntryRenderer<UsageData>(ENTRY_TYPE, (entry, { expanded }, theme) => {
		const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
		const data = entry.data;
		if (!data || !Array.isArray(data.windows)) {
			box.addChild(new Text(theme.fg("dim", "OpenCode Go usage unavailable."), 0, 0));
			return box;
		}

		const source = data.source ? ` ${theme.fg("dim", `via ${data.source}`)}` : "";
		box.addChild(
			new Text(
				`${theme.fg("accent", "OpenCode Go usage")} ${theme.fg("dim", `checked ${clock(data.checkedAt)}`)}${source}`,
				0,
				0,
			),
		);

		const labelWidth = Math.max(...data.windows.map((window) => window.label.length));
		for (const window of data.windows) {
			const parts = [
				theme.fg("muted", window.label.padEnd(labelWidth)),
				"  ",
				theme.bold(`${window.usedPercent.toFixed(0)}% used`),
			];
			const reset = countdown(window.resetsAt, data.checkedAt);
			if (reset) parts.push("  ", theme.fg("dim", reset));
			if (expanded) parts.push("  ", theme.fg("dim", bar(window.usedPercent)));
			if (window.status !== "ok") parts.push("  ", theme.fg("warning", window.status));
			box.addChild(new Text(parts.join(""), 0, 0));
		}

		for (const note of data.notes) box.addChild(new Text(theme.fg("warning", note), 0, 0));
		if (expanded) box.addChild(new Text(theme.fg("dim", JSON.stringify(data, null, 2)), 0, 0));

		return box;
	});

	pi.registerCommand("usage", {
		description: "Show OpenCode Go usage limits",
		handler: async (args, ctx) => {
			if (args.trim()) {
				ctx.ui.notify("/usage takes no arguments.", "warning");
				return;
			}
			try {
				pi.appendEntry<UsageData>(ENTRY_TYPE, await fetchUsage(ctx));
			} catch (error) {
				ctx.ui.notify(`OpenCode Go usage failed: ${errorMessage(error)}`, "error");
			}
		},
	});
}

async function fetchUsage(ctx: ExtensionContext): Promise<UsageData> {
	const resolved = await ctx.modelRegistry.getProviderAuth(PROVIDER_ID);
	if (!resolved) {
		throw new Error(`no ${PROVIDER_ID} credentials configured; run "pi auth login ${PROVIDER_ID}"`);
	}

	// Never send the credential to a non-official origin.
	const origins = [resolved.auth.baseUrl, ctx.modelRegistry.getProvider(PROVIDER_ID)?.baseUrl];
	for (const baseUrl of origins) {
		if (!baseUrl) continue;
		const host = hostOf(baseUrl);
		if (host !== OFFICIAL_HOST) {
			throw new Error(`refusing to send credentials to ${baseUrl}; ${PROVIDER_ID} auth must use ${OFFICIAL_HOST}`);
		}
	}

	const headers: Record<string, string> = {};
	for (const [name, value] of Object.entries(resolved.auth.headers ?? {})) {
		if (typeof value === "string") headers[name] = value;
	}
	const authorization =
		headerValue(headers, "authorization") ?? (resolved.auth.apiKey ? `Bearer ${resolved.auth.apiKey}` : undefined);
	if (!authorization) throw new Error(`${PROVIDER_ID} credentials resolved without an API key or Authorization header`);
	if (!headerValue(headers, "authorization")) headers.Authorization = authorization;
	if (!headerValue(headers, "user-agent")) headers["User-Agent"] = "pi-opencode-usage";

	const response = await fetch(USAGE_URL, {
		headers,
		signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
	});
	const text = (await response.text()).slice(0, MAX_BODY_BYTES);
	if (!response.ok) {
		throw new Error(`usage endpoint returned ${response.status} ${response.statusText}: ${firstLine(text)}`);
	}

	let body: unknown;
	try {
		body = JSON.parse(text);
	} catch {
		throw new Error("usage endpoint returned invalid JSON");
	}

	const usage = asRecord(asRecord(body)?.usage);
	if (!usage) throw new Error("usage endpoint response has no usage object");

	const windows: UsageWindow[] = [];
	const notes: string[] = [];
	for (const def of WINDOW_DEFS) {
		const raw = asRecord(usage[def.key]);
		if (!raw) continue;
		const status = typeof raw.status === "string" && raw.status.trim() ? raw.status.trim() : "unknown";
		if (status !== "ok" && status !== "rate-limited") {
			notes.push(`${def.label} window unavailable (${status} status).`);
			continue;
		}
		const percent = asPercent(raw.percent);
		if (percent === undefined) {
			notes.push(`${def.label} window returned no usable percentage.`);
			continue;
		}
		const resetsAt = asTimestamp(raw.resetsAt);
		windows.push({
			key: def.key,
			label: def.label,
			status,
			usedPercent: percent,
			...(resetsAt !== undefined ? { resetsAt } : {}),
		});
	}
	if (windows.length === 0) {
		throw new Error(`no displayable usage windows. ${notes.join(" ") || "Retry later."}`);
	}

	return {
		checkedAt: Date.now(),
		...(resolved.source ? { source: resolved.source } : {}),
		windows,
		notes,
	};
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
	if (!value || typeof value !== "object" || Array.isArray(value)) return undefined;
	return value as Record<string, unknown>;
}

function asPercent(value: unknown): number | undefined {
	if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return undefined;
	return Math.min(100, value);
}

function asTimestamp(value: unknown): number | undefined {
	if (typeof value === "number" && Number.isFinite(value)) return value > 1e12 ? value : value * 1_000;
	if (typeof value !== "string" || !value.trim()) return undefined;
	const parsed = Date.parse(value);
	return Number.isNaN(parsed) ? undefined : parsed;
}

function hostOf(baseUrl: string): string | undefined {
	try {
		return new URL(baseUrl).hostname.toLowerCase();
	} catch {
		return undefined;
	}
}

function headerValue(headers: Record<string, string>, name: string): string | undefined {
	for (const [key, value] of Object.entries(headers)) {
		if (key.toLowerCase() === name.toLowerCase() && value) return value;
	}
	return undefined;
}

function firstLine(text: string): string {
	const line = text.split("\n", 1)[0]?.trim() ?? "";
	return line.length > 120 ? `${line.slice(0, 117)}...` : line || "(empty body)";
}

function clock(epochMs: number): string {
	return new Date(epochMs).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
}

function countdown(resetsAt: number | undefined, now: number): string | undefined {
	if (resetsAt === undefined || !Number.isFinite(resetsAt)) return undefined;
	const totalMinutes = Math.ceil((resetsAt - now) / 60_000);
	if (totalMinutes <= 0) return "resets due";
	const days = Math.floor(totalMinutes / 1_440);
	const hours = Math.floor((totalMinutes % 1_440) / 60);
	const minutes = totalMinutes % 60;
	if (days > 0) return `resets in ${days}d${hours > 0 ? ` ${hours}h` : ""}`;
	if (hours > 0) return `resets in ${hours}h${minutes > 0 ? ` ${minutes}m` : ""}`;
	return `resets in ${minutes}m`;
}

function bar(usedPercent: number): string {
	const segments = 12;
	const filled = Math.round(((100 - usedPercent) / 100) * segments);
	return `${"█".repeat(filled)}${"░".repeat(segments - filled)} ${(100 - usedPercent).toFixed(0)}% left`;
}

function errorMessage(error: unknown): string {
	if (error instanceof Error) {
		return error.name === "TimeoutError" ? `timed out after ${FETCH_TIMEOUT_MS / 1_000}s` : error.message;
	}
	return String(error);
}
