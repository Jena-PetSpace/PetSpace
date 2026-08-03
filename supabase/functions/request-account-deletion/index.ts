// Account deletion: Apple credential revoke (when linked) → 30-day soft delete
// → global session invalidation. The purge-deleted-accounts batch permanently
// removes Storage, auth.users and public.users after the grace period.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.111.0";
import {
  createRemoteJWKSet,
  importPKCS8,
  jwtVerify,
  SignJWT,
} from "npm:jose@5.9.6";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_TOKEN_URL = `${APPLE_ISSUER}/auth/token`;
const APPLE_REVOKE_URL = `${APPLE_ISSUER}/auth/revoke`;
const APPLE_JWKS = createRemoteJWKSet(
  new URL(`${APPLE_ISSUER}/auth/keys`),
  { timeoutDuration: 5_000, cooldownDuration: 30_000 },
);
const REQUEST_TIMEOUT_MS = 8_000;
const MAX_BODY_BYTES = 4_096;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type DeletionRequest = {
  appleAuthorizationCode?: unknown;
  appleNonce?: unknown;
};

class SafeError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, "METHOD_NOT_ALLOWED");
  }

  try {
    const jwt = readBearerToken(req.headers.get("Authorization"));
    const body = await readRequestBody(req);
    const admin = createClient(
      requireEnvironment("SUPABASE_URL"),
      requireEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // The authenticated JWT is the only source of the deletion target.
    // No user id supplied by the caller is accepted.
    const {
      data: { user },
      error: userError,
    } = await admin.auth.getUser(jwt);
    if (userError || !user || user.role !== "authenticated") {
      throw new SafeError(401, "INVALID_SESSION");
    }

    const metadataProviders = Array.isArray(user.app_metadata?.providers)
      ? user.app_metadata.providers.filter(
        (provider: unknown): provider is string => typeof provider === "string",
      )
      : [];
    if (typeof user.app_metadata?.provider === "string") {
      metadataProviders.push(user.app_metadata.provider);
    }
    const identities = user.identities ?? [];
    const hasAppleProvider = metadataProviders.includes("apple") ||
      identities.some((identity) => identity.provider === "apple");
    const appleIdentity = identities.find(
      (identity) => identity.provider === "apple",
    );

    const { data: profile, error: profileError } = await admin
      .from("users")
      .select("deleted_at")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw new SafeError(503, "PROFILE_LOOKUP_FAILED");
    if (!profile) throw new SafeError(409, "PROFILE_NOT_FOUND");

    if (hasAppleProvider) {
      // Supabase UserIdentity.id is the provider id (Apple `sub`).
      // identity_id is the internal Supabase identity-row UUID and must never
      // be compared with the Apple token subject.
      if (!appleIdentity?.id) {
        throw new SafeError(409, "APPLE_IDENTITY_MISSING");
      }
      const authorizationCode = requireEphemeralString(
        body.appleAuthorizationCode,
        "APPLE_REAUTH_REQUIRED",
        2_048,
      );
      const rawNonce = requireEphemeralString(
        body.appleNonce,
        "APPLE_REAUTH_REQUIRED",
        256,
      );
      await revokeAppleCredential({
        authorizationCode,
        rawNonce,
        expectedSubject: appleIdentity.id,
      });
    } else if (
      body.appleAuthorizationCode !== undefined ||
      body.appleNonce !== undefined
    ) {
      // Unexpected provider credentials are rejected rather than ignored.
      throw new SafeError(400, "UNEXPECTED_APPLE_CREDENTIAL");
    }

    // Apple credential revocation succeeded, so record the user's deletion
    // request before attempting session cleanup. A transient auth-admin
    // sign-out failure must not leave an Apple-revoked account active.
    if (profile.deleted_at == null) {
      const { error: updateError } = await admin
        .from("users")
        .update({ deleted_at: new Date().toISOString() })
        .eq("id", user.id)
        .is("deleted_at", null);
      if (updateError) throw new SafeError(503, "SOFT_DELETE_FAILED");
    }

    // The L2 restrictive RLS contract blocks a deleted user's remaining
    // access token from every user-owned table. Global sign-out is therefore
    // defense in depth; the client also clears its local session on success.
    await admin.auth.admin.signOut(jwt, "global");

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    if (error instanceof SafeError) {
      return jsonResponse(error.status, error.code);
    }
    // Never return provider payloads, tokens, nonce, environment values, or
    // raw exception strings to callers.
    return jsonResponse(500, "ACCOUNT_DELETION_FAILED");
  }
});

function readBearerToken(header: string | null): string {
  const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(header ?? "");
  if (!match) throw new SafeError(401, "INVALID_SESSION");
  return match[1];
}

async function readRequestBody(req: Request): Promise<DeletionRequest> {
  const text = await req.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) {
    throw new SafeError(413, "REQUEST_TOO_LARGE");
  }
  if (text.trim().length === 0) return {};

  try {
    const value: unknown = JSON.parse(text);
    if (!value || Array.isArray(value) || typeof value !== "object") {
      throw new SafeError(400, "INVALID_REQUEST");
    }
    return value as DeletionRequest;
  } catch (error) {
    if (error instanceof SafeError) throw error;
    throw new SafeError(400, "INVALID_REQUEST");
  }
}

function requireEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new SafeError(503, "SERVICE_NOT_CONFIGURED");
  return value;
}

function requireEphemeralString(
  value: unknown,
  code: string,
  maxLength: number,
): string {
  if (typeof value !== "string") throw new SafeError(400, code);
  const result = value.trim();
  if (!result || result.length > maxLength) throw new SafeError(400, code);
  return result;
}

async function revokeAppleCredential({
  authorizationCode,
  rawNonce,
  expectedSubject,
}: {
  authorizationCode: string;
  rawNonce: string;
  expectedSubject: string;
}): Promise<void> {
  const teamId = requireEnvironment("APPLE_TEAM_ID");
  const keyId = requireEnvironment("APPLE_KEY_ID");
  const clientId = requireEnvironment("APPLE_CLIENT_ID");
  const privateKey = requireEnvironment("APPLE_PRIVATE_KEY").replace(
    /\\n/g,
    "\n",
  );
  if (clientId !== "com.jena.petspace") {
    throw new SafeError(503, "APPLE_CLIENT_ID_MISMATCH");
  }

  let signingKey: Awaited<ReturnType<typeof importPKCS8>>;
  try {
    signingKey = await importPKCS8(privateKey, "ES256");
  } catch (_) {
    throw new SafeError(503, "SERVICE_NOT_CONFIGURED");
  }

  const issuedAt = Math.floor(Date.now() / 1_000);
  const clientSecret = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setSubject(clientId)
    .setAudience(APPLE_ISSUER)
    .setIssuedAt(issuedAt)
    .setExpirationTime(issuedAt + 300)
    .sign(signingKey);

  const tokenResponse = await fetchWithTimeout(
    APPLE_TOKEN_URL,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code: authorizationCode,
        client_id: clientId,
        client_secret: clientSecret,
      }),
    },
  );
  if (!tokenResponse.ok) {
    throw new SafeError(409, "APPLE_REAUTH_REQUIRED");
  }

  const tokenPayload = await readAppleTokenResponse(tokenResponse);
  const expectedNonce = await sha256Hex(rawNonce);
  try {
    const { payload, protectedHeader } = await jwtVerify(
      tokenPayload.id_token,
      APPLE_JWKS,
      {
        issuer: APPLE_ISSUER,
        audience: clientId,
        algorithms: ["RS256"],
      },
    );
    if (
      protectedHeader.alg !== "RS256" ||
      payload.sub !== expectedSubject ||
      payload.nonce !== expectedNonce
    ) {
      throw new SafeError(409, "APPLE_REAUTH_REQUIRED");
    }
  } catch (error) {
    if (error instanceof SafeError) throw error;
    throw new SafeError(409, "APPLE_REAUTH_REQUIRED");
  }

  const revokeResponse = await fetchWithTimeout(
    APPLE_REVOKE_URL,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        token: tokenPayload.refresh_token,
        token_type_hint: "refresh_token",
      }),
    },
  );
  if (!revokeResponse.ok) {
    throw new SafeError(503, "APPLE_REVOKE_FAILED");
  }
}

async function readAppleTokenResponse(
  response: Response,
): Promise<{ id_token: string; refresh_token: string }> {
  let value: unknown;
  try {
    value = await response.json();
  } catch (_) {
    throw new SafeError(409, "APPLE_REAUTH_REQUIRED");
  }
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new SafeError(409, "APPLE_REAUTH_REQUIRED");
  }
  const record = value as Record<string, unknown>;
  if (
    typeof record.id_token !== "string" ||
    !record.id_token ||
    typeof record.refresh_token !== "string" ||
    !record.refresh_token
  ) {
    throw new SafeError(409, "APPLE_REAUTH_REQUIRED");
  }
  return {
    id_token: record.id_token,
    refresh_token: record.refresh_token,
  };
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function fetchWithTimeout(
  input: string,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (_) {
    throw new SafeError(503, "APPLE_PROVIDER_UNAVAILABLE");
  } finally {
    clearTimeout(timeout);
  }
}

function jsonResponse(status: number, code: string): Response {
  return new Response(JSON.stringify({ error: "request_failed", code }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
