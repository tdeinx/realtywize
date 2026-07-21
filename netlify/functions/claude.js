// Realtywize — Anthropic Claude API proxy.
// Keeps ANTHROPIC_API_KEY server-side. Set it in Netlify:
// Site configuration → Environment variables → ANTHROPIC_API_KEY.

const { createClient } = require('@supabase/supabase-js');

// Admin client for verifying user JWTs. Uses the service-role key
// (server-side only). SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY come
// from Netlify env — same vars supabase-data.js already relies on.
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
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

  // Verify the caller's Supabase JWT before spending any Anthropic
  // tokens. Without this, anyone who finds the endpoint URL can
  // pump requests through it and rack up the bill.
  const authHeader = event.headers.authorization || event.headers.Authorization || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!token) {
    return json(401, { error: "Missing Authorization header." });
  }
  try {
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
    if (authError || !user) {
      return json(401, { error: "Invalid or expired token." });
    }
  } catch (err) {
    return json(401, { error: "Auth check failed: " + (err && err.message || err) });
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
  let finalMessages = Array.isArray(messages) && messages.length
    ? messages
    : typeof prompt === "string" && prompt.length
      ? [{ role: "user", content: prompt }]
      : null;

  if (!finalMessages) {
    return json(400, { error: "Request must include 'messages' array or 'prompt' string." });
  }

  // Optional vision-mode: if the request includes a non-empty `images` array,
  // replace the synthesized user content with an array of image blocks followed
  // by a text block. Requires a `prompt` string to accompany the images.
  // Text-only requests (no `images` key, or empty array) take the path above
  // unchanged — byte-for-byte identical upstream payload.
  const images = Array.isArray(payload.images) && payload.images.length ? payload.images : null;
  if (images) {
    if (typeof prompt !== "string" || !prompt.length) {
      return json(400, { error: "Vision requests must include a 'prompt' string alongside 'images'." });
    }
    finalMessages = [{
      role: "user",
      content: [
        ...images.map(img => ({
          type: "image",
          source: { type: "base64", media_type: img.media_type, data: img.data }
        })),
        { type: "text", text: prompt }
      ]
    }];
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
        model: payload.model || "claude-sonnet-4-6",
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
