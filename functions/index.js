/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

/* ===================== Added: AI chat proxy (v1 onRequest) ===================== */

const admin = require("firebase-admin");
try {
  admin.initializeApp();
} catch (_) {
  // ignore if already initialized
}

// Simple CORS helper for web/mobile clients.
// Tighten `Access-Control-Allow-Origin` to your app origins in production.
function setCors(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "authorization, content-type");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return true;
  }
  return false;
}

exports.chat = onRequest(async (req, res) => {
  try {
    if (setCors(req, res)) return;
    if (req.method !== "POST") {
      return res.status(405).send("Method not allowed");
    }

    // ---- Auth guard (expects Firebase ID token from the app) ----
    const authz = req.headers.authorization || "";
    if (!authz.startsWith("Bearer ")) {
      return res.status(401).send("Missing auth");
    }
    const idToken = authz.slice(7);
    await admin.auth().verifyIdToken(idToken); // throws if invalid

    // ---- Validate input ----
    const {messages, model = "gpt-4o-mini", temperature = 0.8} = req.body || {};
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({error: "messages required"});
    }

    // Keep payload small
    const safeMessages = messages.slice(-40);

    // ---- Call OpenAI (Chat Completions) ----
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({error: "OPENAI_API_KEY not set"});
    }

    // Node 18+/20+ has global fetch in Cloud Functions gen2; v1 runtime on Node 22 also includes fetch.
    const upstream = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature,
        messages: [
          {
            role: "system",
            content:
              "You are a warm, empathetic, conversational mental-health companion. " +
              "Reflect what you heard in 1–2 sentences, ask ONE short follow-up question, " +
              "and suggest coping ideas only when fitting. Avoid diagnoses. " +
              "If crisis/self-harm appears, advise contacting local emergency services immediately.",
          },
          ...safeMessages,
        ],
      }),
    });

    if (!upstream.ok) {
      const text = await upstream.text();
      logger.error("OpenAI error", {status: upstream.status, text});
      return res.status(502).json({error: "upstream error"});
    }

    const data = await upstream.json();
    const content = data?.choices?.[0]?.message?.content ?? "";
    return res.json({content, usage: data.usage ?? null});
  } catch (e) {
    logger.error(e);
    return res.status(500).json({error: "server error"});
  }
});
