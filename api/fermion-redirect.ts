import type { VercelRequest, VercelResponse } from '@vercel/node';

// ─────────────────────────────────────────────────────────────────────────────
// fermion-redirect.ts
//
// POLICY: FORCE MANUAL LOGOUT -> WARNING SPLASH -> LOGIN
// ─────────────────────────────────────────────────────────────────────────────

const ENVIRONMENTS = {
  vivek: { productId: '68d24a4a1295f90e0e22a041', contestUrl: 'https://careerbadge.apply-wizz.com/contest/situation-needs' },
  fe1: { productId: '68d24a4a1295f90e0e22a041', contestUrl: 'https://careerbadge.apply-wizz.com/contest/generally-dull' },
  fe2: { productId: '68d24a57d03833130b007f2c', contestUrl: 'https://careerbadge.apply-wizz.com/contest/weak-practice' },
  be1: { productId: '68d24a4a1295f90e0e22a041', contestUrl: 'https://careerbadge.apply-wizz.com/contest/be1-contest' },
  be2: { productId: '68d24a4a1295f90e0e22a041', contestUrl: 'https://careerbadge.apply-wizz.com/contest/be2-contest' },
  be3: { productId: '68d24a4a1295f90e0e22a041', contestUrl: 'https://careerbadge.apply-wizz.com/contest/be3-contest' },
  aml1: { productId: '68df98d58c6253ef47a720c3', contestUrl: 'https://careerbadge.apply-wizz.com/contest/pond-pound' },
  aml3: { productId: '691c6ce659f2b0a289b65a5f', contestUrl: 'https://careerbadge.apply-wizz.com/contest/sunlight-back' },
  da1: { productId: '69132c01c37ccc70afb5687d', contestUrl: 'https://careerbadge.apply-wizz.com/contest/actually-equipment' },
  da2: { productId: '690c7a799f7fb845155d31e7', contestUrl: 'https://careerbadge.apply-wizz.com/contest/new-pig' },
  de2: { productId: '690c7b0a9f7fb845155d33d9', contestUrl: 'https://careerbadge.apply-wizz.com/contest/return-paragraph' },
  bie2: { productId: '690c7f90d114064589ca7c1b', contestUrl: 'https://careerbadge.apply-wizz.com/contest/military-seed' },
  sde1: { productId: '68d24a735824ea0d74588d2e', contestUrl: 'https://careerbadge.apply-wizz.com/contest/thou-under' },
  sde2: { productId: '68d24a7f9fd1dab5a920e877', contestUrl: 'https://careerbadge.apply-wizz.com/contest/chemical-rhythm' },
  ba2: { productId: '68dfa749141229ed7fc97e87', contestUrl: 'https://careerbadge.apply-wizz.com/contest/hurry-seeing' },
  ds1: { productId: '691acb48a0afbf8f08573758', contestUrl: 'https://careerbadge.apply-wizz.com/contest/history-several' },
  wda2: { productId: '69269b0e7d219b8d2cce7178', contestUrl: 'https://careerbadge.apply-wizz.com/contest/some-independent' },
  pd1: { productId: '693faedf90cc0a5e90e21e8b', contestUrl: 'https://careerbadge.apply-wizz.com/contest/air-service' },
  pd2: { productId: '693faf1c16d9f25e2f4eca34', contestUrl: 'https://careerbadge.apply-wizz.com/contest/favorite-nearly' },
  genai1: { productId: '693f8aadcd77085e3bd8c0d8', contestUrl: 'https://careerbadge.apply-wizz.com/contest/recognize-wave' },
  genai2: { productId: '693fae41a4288e869068c16f', contestUrl: 'https://careerbadge.apply-wizz.com/contest/remember-completely' },
  medc1: { productId: '693bca9bc8e583aa89f94463', contestUrl: 'https://careerbadge.apply-wizz.com/contest/cream-pitch' },
  medc2: { productId: '693f8402c09a185e41e9f376', contestUrl: 'https://careerbadge.apply-wizz.com/contest/take-writing' },
  cs1: { productId: '693fa8652c57495ea16276d9', contestUrl: 'https://careerbadge.apply-wizz.com/contest/split-party' },
  cs2: { productId: '693facd14bcdf0868f9a277a', contestUrl: 'https://careerbadge.apply-wizz.com/contest/wide-government' },
  aiml1: { productId: '693f9c61dd85328693f85641', contestUrl: 'https://careerbadge.apply-wizz.com/contest/come-cabin' },
  aiml2: { productId: '693f9fa2a4288e869068ac5c', contestUrl: 'https://careerbadge.apply-wizz.com/contest/shoulder-curve' },
  default: { productId: '68d24a4a1295f90e0e22a041', contestUrl: 'https://careerbadge.apply-wizz.com/contest/situation-needs' }
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    const env = (req.query.env as string) || 'default';
    const skill = req.query.skill as string | undefined;
    const email = (req.query.email as string) || '';
    const userId = (req.query.uid as string) || 'anon';
    const confirm = req.query.confirm === 'true';

    const config = ENVIRONMENTS[env as keyof typeof ENVIRONMENTS] || ENVIRONMENTS.default;
    const schoolHost = process.env.FERMION_SCHOOL_HOST || 'careerbadge.apply-wizz.com';
    let contestUrl = config.contestUrl.replace('careerbadge.apply-wizz.com', schoolHost);

    if (skill) {
      contestUrl += (contestUrl.includes('?') ? '&' : '?') + `skill=${encodeURIComponent(skill)}`;
    }

    // ── STEP 1: If not confirmed yet, show the Splash Page Warning ─────────────
    if (!confirm && email) {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      return res.status(200).send(`
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Verification Requirement</title>
          <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
          <style>
            body { font-family: 'Inter', sans-serif; background-color: #f4f7f6; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .card { background: white; padding: 2.5rem; border-radius: 1.5rem; box-shadow: 0 10px 25px rgba(0,0,0,0.05); text-align: center; max-width: 450px; width: 90%; }
            h1 { color: #1a2740; margin-bottom: 1.5rem; font-size: 1.5rem; }
            p { color: #555; line-height: 1.6; margin-bottom: 1.5rem; }
            .warning-box { background: #fee2e2; border: 1px solid #fecaca; color: #b91c1c; padding: 1rem; border-radius: 1rem; margin-bottom: 1.5rem; }
            .email-display { font-weight: bold; font-size: 1.2rem; color: #2563eb; display: block; margin-top: 0.5rem; padding: 0.5rem; background: #eff6ff; border-radius: 0.5rem; }
            .btn { background: #2563eb; color: white; padding: 0.8rem 1.8rem; border-radius: 0.8rem; text-decoration: none; font-weight: 600; display: inline-block; transition: background 0.2s; border: none; cursor: pointer; }
            .btn:hover { background: #1d4ed8; }
            .cancel { display: block; margin-top: 1rem; color: #888; text-decoration: none; font-size: 0.9rem; }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Login Requirement</h1>
            <div class="warning-box">
              <strong>CRITICAL POLICY:</strong>
              <p style="margin-top: 8px; margin-bottom: 0;">You MUST log in to Fermion using your LinkSpec email. If you use a different account, your verification results will not be synchronized.</p>
            </div>
            <p>Your LinkSpec Email:</p>
            <span class="email-display">${email}</span>
            <div style="margin-top: 2rem;">
              <a href="${req.url}&confirm=true" class="btn">I am using this email, Proceed</a>
              <a href="javascript:window.close();" class="cancel">Cancel and Go Back</a>
            </div>
          </div>
        </body>
        </html>
      `);
    }

    // ── STEP 2: Proceed to Logout -> Login Gate ──────────────────────────────
    // This clears any existing session and lands them on the login page.
    const logonGateUrl = `https://${schoolHost}/logout?next=${encodeURIComponent(`/login?redirect_uri=${contestUrl}`)}`;
    
    console.log(`[fermion-redirect] email=${email} → Final Gate: ${logonGateUrl}`);
    
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');

    return res.redirect(302, logonGateUrl);

  } catch (e: any) {
    console.error('fermion-redirect error:', e);
    return res.status(500).send(`Unexpected server error: ${e?.message || e}`);
  }
}
