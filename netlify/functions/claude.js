// Realtywize — Anthropic Claude API proxy.
// Keeps ANTHROPIC_API_KEY server-side. Set it in Netlify:
// Site configuration → Environment variables → ANTHROPIC_API_KEY.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const json = (statusCode, body) => ({
  statusCode,
  headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  body: JSON.stringify(body),
});

exports.handler = async (event) => {
  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 204, headers: CORS_HEADERS, body: "" };
  }
  if (event.httpMethod !== "POST") {
    return json(405, { error: "Method not allowed. Use POST." });
  }

  const apiKey = event.headers["x-api-key"] || process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return json(500, {
      error:
        "Server is missing ANTHROPIC_API_KEY. Set it in Netlify → Site configuration → Environment variables, or provide one in Settings.",
    });
  }

  let payload;
  try {
    payload = JSON.parse(event.body || "{}");
  } catch (e) {
    return json(400, { error: "Invalid JSON body." });
  }

  const { messages, prompt, max_tokens } = payload;
  const finalMessages = Array.isArray(messages) && messages.length
    ? messages
    : typeof prompt === "string" && prompt.length
      ? [{ role: "user", content: prompt }]
      : null;

  if (!finalMessages) {
    return json(400, { error: "Request must include 'messages' array or 'prompt' string." });
  }

  const maxTokens = Number.isFinite(max_tokens) && max_tokens > 0 ? max_tokens : 1000;

  try {
    const upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: payload.model || "claude-3-5-sonnet-20241022",
        max_tokens: maxTokens,
        messages: finalMessages,
      }),
    });

    const text = await upstream.text();
    if (!upstream.ok) {
      return {
        statusCode: upstream.status,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        body: JSON.stringify({
          error: `Anthropic API error (${upstream.status})`,
          detail: text,
        }),
      };
    }

    return {
      statusCode: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      body: text,
    };
  } catch (err) {
    return json(502, { error: "Failed to reach Anthropic API.", detail: String(err && err.message || err) });
  }
};
