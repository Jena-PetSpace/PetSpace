import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── 타입 ──────────────────────────────────────────────────────────────────────

interface PushPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, string>
}

interface FcmMessage {
  message: {
    token: string
    notification: { title: string; body: string }
    data?: Record<string, string>
    android?: { priority: 'HIGH' | 'NORMAL' }
    apns?: { payload: { aps: { badge?: number; sound?: string } } }
  }
}

// ── Google OAuth2 액세스 토큰 발급 (서비스 계정 키 사용) ────────────────────

async function getAccessToken(serviceAccountKey: string): Promise<string> {
  const sa = JSON.parse(serviceAccountKey)

  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const signingInput = `${encode(header)}.${encode(payload)}`

  // RSA-SHA256 서명
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', privateKey, new TextEncoder().encode(signingInput))

  const jwt = `${signingInput}.${arrayBufferToBase64Url(signature)}`

  // 토큰 교환
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  const tokenData = await tokenRes.json()
  return tokenData.access_token
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const binary = atob(b64)
  const buf = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i)
  return buf.buffer
}

function arrayBufferToBase64Url(buffer: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

// ── FCM v1 API 발송 ───────────────────────────────────────────────────────────

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  message: FcmMessage,
): Promise<{ success: boolean; error?: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message),
  })

  if (!res.ok) {
    const err = await res.text()
    return { success: false, error: err }
  }
  return { success: true }
}

// ── Edge Function 진입점 ──────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  try {
    const payload: PushPayload = await req.json()
    const { user_id, title, body, data } = payload

    if (!user_id || !title || !body) {
      return new Response(JSON.stringify({ error: 'user_id, title, body 필수' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // 환경변수 로드
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const serviceAccountKey = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')!
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')!

    // 활성 FCM 토큰 조회
    const supabase = createClient(supabaseUrl, supabaseKey)
    const { data: devices, error: dbError } = await supabase
      .from('user_devices')
      .select('fcm_token, platform')
      .eq('user_id', user_id)
      .eq('is_active', true)

    if (dbError) throw dbError
    if (!devices || devices.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: '활성 기기 없음' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // 액세스 토큰 1회 발급 후 모든 기기에 재사용
    const accessToken = await getAccessToken(serviceAccountKey)

    const results = await Promise.allSettled(
      devices.map((device: { fcm_token: string; platform: string }) => {
        const msg: FcmMessage = {
          message: {
            token: device.fcm_token,
            notification: { title, body },
            ...(data ? { data } : {}),
            android: { priority: 'HIGH' },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }
        return sendFcmMessage(projectId, accessToken, msg)
      }),
    )

    const sent = results.filter((r) => r.status === 'fulfilled' && (r.value as { success: boolean }).success).length
    const failed = results.length - sent

    console.log(`푸시 발송: ${sent}성공 / ${failed}실패 → user_id=${user_id}`)

    return new Response(JSON.stringify({ sent, failed }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('send-push-notification 오류:', e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
