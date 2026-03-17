import type { VercelRequest, VercelResponse } from '@vercel/node';

// ─────────────────────────────────────────────────────────────────────────────
// fermion-redirect.ts
//
// IMPORTANT POLICY: This endpoint NEVER generates an SSO token.
// Fermion must always show its own login / sign-up screen so users
// authenticate manually every single time. No auto-login, no cached sessions.
// ─────────────────────────────────────────────────────────────────────────────

const ENVIRONMENTS = {
  vivek: {
    productId: '68d24a4a1295f90e0e22a041',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/situation-needs'
  },
  fe1: {
    productId: '68d24a4a1295f90e0e22a041',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/generally-dull'
  },
  fe2: {
    productId: '68d24a57d03833130b007f2c',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/weak-practice'
  },
  be1: {
    productId: '68d24a4a1295f90e0e22a041',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/be1-contest'
  },
  be2: {
    productId: '68d24a4a1295f90e0e22a041',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/be2-contest'
  },
  be3: {
    productId: '68d24a4a1295f90e0e22a041',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/be3-contest'
  },
  aml1: {
    productId: '68df98d58c6253ef47a720c3',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/pond-pound'
  },
  aml3: {
    productId: '691c6ce659f2b0a289b65a5f',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/sunlight-back'
  },
  da1: {
    productId: '69132c01c37ccc70afb5687d',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/actually-equipment'
  },
  da2: {
    productId: '690c7a799f7fb845155d31e7',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/new-pig'
  },
  de2: {
    productId: '690c7b0a9f7fb845155d33d9',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/return-paragraph'
  },
  bie2: {
    productId: '690c7f90d114064589ca7c1b',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/military-seed'
  },
  sde1: {
    productId: '68d24a735824ea0d74588d2e',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/thou-under'
  },
  sde2: {
    productId: '68d24a7f9fd1dab5a920e877',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/chemical-rhythm'
  },
  ba2: {
    productId: '68dfa749141229ed7fc97e87',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/hurry-seeing'
  },
  ds1: {
    productId: '691acb48a0afbf8f08573758',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/history-several'
  },
  wda2: {
    productId: '69269b0e7d219b8d2cce7178',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/some-independent'
  },
  pd1: {
    productId: '693faedf90cc0a5e90e21e8b',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/air-service'
  },
  pd2: {
    productId: '693faf1c16d9f25e2f4eca34',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/favorite-nearly'
  },
  genai1: {
    productId: '693f8aadcd77085e3bd8c0d8',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/recognize-wave'
  },
  genai2: {
    productId: '693fae41a4288e869068c16f',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/remember-completely'
  },
  medc1: {
    productId: '693bca9bc8e583aa89f94463',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/cream-pitch'
  },
  medc2: {
    productId: '693f8402c09a185e41e9f376',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/take-writing'
  },
  cs1: {
    productId: '693fa8652c57495ea16276d9',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/split-party'
  },
  cs2: {
    productId: '693facd14bcdf0868f9a277a',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/wide-government'
  },
  aiml1: {
    productId: '693f9c61dd85328693f85641',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/come-cabin'
  },
  aiml2: {
    productId: '693f9fa2a4288e869068ac5c',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/shoulder-curve'
  },
  default: {
    productId: '68d24a4a1295f90e0e22a041',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/situation-needs'
  }
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    const env = (req.query.env as string) || 'default';
    const skill = req.query.skill as string | undefined;

    const config = ENVIRONMENTS[env as keyof typeof ENVIRONMENTS] || ENVIRONMENTS.default;

    // ── Resolve school host ──────────────────────────────────────────────────
    const schoolHost = process.env.FERMION_SCHOOL_HOST || 'careerbadge.apply-wizz.com';
    
    // Redirect to the root home page only, allowing users to choose any contest
    const contestUrl = '/';

    // ── POLICY: FORCE LOGOUT + MANUALLY LOGIN ──────────────────────────────
    // To ensure the user is NEVER automatically logged in with a cached session,
    // we first send them to the /logout endpoint. The logout process is
    // configured to redirect back to the /login page, with the final
    // contest destination passed as a redirect_uri.
    const logonGateUrl = `https://${schoolHost}/logout?next=${encodeURIComponent(`/login?redirect_uri=${contestUrl}`)}`;

    console.log(`[fermion-redirect] env=${env} → Forced Logout Gateway: ${logonGateUrl}`);

    // Prevent any intermediate caching from storing a stale redirect target.
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');

    return res.redirect(302, logonGateUrl);

  } catch (e: any) {
    console.error('fermion-redirect error:', e);
    return res.status(500).send(`Unexpected server error: ${e?.message || e}`);
  }
}
