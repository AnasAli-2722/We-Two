import "@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library";

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type NotificationType = "chat_message" | "new_request" | "request_accepted";

type NotificationIntent = {
  type: NotificationType;
  senderId: string;
  recipientId: string;
  itemId: string;
  title: string;
  body: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FCM_WEBHOOK_SECRET = Deno.env.get("FCM_WEBHOOK_SECRET") ?? "";

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function normalizeId(value: unknown): string {
  return String(value ?? "").trim();
}

function normalizeText(value: unknown, fallback = ""): string {
  const text = String(value ?? "").trim();
  return text.length == 0 ? fallback : text;
}

async function getSenderDisplayName(senderId: string): Promise<string> {
  if (!senderId) {
    return "Someone";
  }

  const { data, error } = await supabase
    .from("profiles")
    .select("first_name, username")
    .eq("id", senderId)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to fetch sender profile: ${error.message}`);
  }

  const firstName = normalizeText(data?.first_name);
  const username = normalizeText(data?.username);

  if (firstName) return firstName;
  if (username) return username;
  return "Someone";
}

async function getFcmTokenForUser(userId: string): Promise<string> {
  const { data, error } = await supabase
    .from("profiles")
    .select("fcm_token")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to fetch receiver profile: ${error.message}`);
  }

  return normalizeText(data?.fcm_token);
}

function parseServiceAccountSecret(): ServiceAccount {
  const rawSecret = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
  const trimmedSecret = rawSecret.trim();

  if (!trimmedSecret) {
    throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON");
  }

  const normalizedSecret =
    trimmedSecret.startsWith("'") && trimmedSecret.endsWith("'")
      ? trimmedSecret.slice(1, -1).trim()
      : trimmedSecret;

  let parsed: ServiceAccount;
  try {
    parsed = JSON.parse(normalizedSecret) as ServiceAccount;
  } catch (error) {
    throw new Error(
      `Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON: ${(error as Error).message}`,
    );
  }

  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error("Service account JSON missing required fields");
  }

  return {
    project_id: parsed.project_id,
    client_email: parsed.client_email,
    private_key: parsed.private_key.replace(/\\n/g, "\n"),
  };
}

async function buildNotificationIntent(payload: any): Promise<NotificationIntent | null> {
  const eventType = String(
    payload?.type ?? payload?.eventType ?? payload?.event ?? "",
  ).toUpperCase();

  const tableName = String(
    payload?.table ?? payload?.table_name ?? payload?.tableName ?? "",
  ).toLowerCase();

  const record = payload?.record ?? payload?.new ?? payload;
  const oldRecord = payload?.old_record ?? payload?.old ?? payload?.oldRecord ?? null;

  // 1) messages INSERT -> chat_message
  if (tableName === "messages") {
    if (eventType !== "INSERT") {
      return null;
    }

    const senderId = normalizeId(record?.sender_id);
    const recipientId = normalizeId(record?.receiver_id);
    const itemId = normalizeId(record?.id);
    const messageText = normalizeText(
      record?.content ?? record?.message_text ?? record?.message,
      "New message",
    );

    if (!senderId || !recipientId || !itemId) {
      return null;
    }

    const senderName = await getSenderDisplayName(senderId);

    return {
      type: "chat_message",
      senderId,
      recipientId,
      itemId,
      title: senderName,
      body: messageText,
    };
  }

  // 2/3) friend_requests or partner_requests
  const isRequestTable =
    tableName === "friend_requests" || tableName === "partner_requests";
  if (!isRequestTable) {
    return null;
  }

  const fromUserId = normalizeId(record?.from_user_id ?? record?.sender_id);
  const toUserId = normalizeId(record?.to_user_id ?? record?.receiver_id);
  const requestId = normalizeId(record?.id);
  const status = normalizeText(record?.status).toLowerCase();
  const oldStatus = normalizeText(oldRecord?.status).toLowerCase();

  if (!fromUserId || !toUserId || !requestId) {
    return null;
  }

  // INSERT pending -> new_request, recipient is to_user_id
  if (eventType === "INSERT" && status === "pending") {
    const senderName = await getSenderDisplayName(fromUserId);
    return {
      type: "new_request",
      senderId: fromUserId,
      recipientId: toUserId,
      itemId: requestId,
      title: "New Friend Request",
      body: `${senderName} wants to connect with you!`,
    };
  }

  // UPDATE accepted transition -> request_accepted, recipient is original requester
  if (eventType === "UPDATE" && status === "accepted" && oldStatus !== "accepted") {
    const acceptorName = await getSenderDisplayName(toUserId);
    return {
      type: "request_accepted",
      senderId: toUserId,
      recipientId: fromUserId,
      itemId: requestId,
      title: "Request Accepted",
      body: `${acceptorName} accepted your request. Say hi!`,
    };
  }

  return null;
}

async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const jwtClient = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const tokenResponse = await jwtClient.authorize();
  const accessToken = tokenResponse.access_token;

  if (!accessToken) {
    throw new Error("Failed to obtain Google access token");
  }

  return accessToken;
}

Deno.serve(async (req) => {
  try {
    if (FCM_WEBHOOK_SECRET) {
      const providedSecret = req.headers.get("x-webhook-secret") ?? "";
      if (providedSecret !== FCM_WEBHOOK_SECRET) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { "Content-Type": "application/json" },
        });
      }
    }

    const payload = await req.json();

    const intent = await buildNotificationIntent(payload);
    if (!intent) {
      // Non-actionable event, acknowledge to avoid retries.
      return json({ ok: true, skipped: "Event ignored by notification rules" }, 200);
    }

    const receiverToken = await getFcmTokenForUser(intent.recipientId);
    if (!receiverToken) {
      return json({ ok: true, skipped: "Receiver has no fcm_token" }, 200);
    }

    const serviceAccount = parseServiceAccountSecret();
    const accessToken = await getAccessToken(serviceAccount);

    const fcmPayload = {
      message: {
        token: receiverToken,
        data: {
          type: intent.type,
          sender_id: intent.senderId,
          item_id: intent.itemId,
          title: intent.title,
          body: intent.body,
        },
        android: {
          priority: "high",
        },
      },
    };

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmPayload),
      },
    );

    const responseBody = await fcmResponse.text();
    return new Response(responseBody, {
      status: fcmResponse.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error(error);
    return json({ error: (error as Error).message }, 500);
  }
});
