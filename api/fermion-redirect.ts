import type { VercelRequest, VercelResponse } from '@vercel/node';
import jwt from 'jsonwebtoken';

// Environment configuration map
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
    productId: '69b3df96facdfdaa50f64a0b',
    contestUrl: 'https://careerbadge.apply-wizz.com/contest/tree-slightly'
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

const ENROLL_URL = 'https://backend.codedamn.com/api/public/enroll-user-into-digital-product';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    const apiKey = process.env.FERMION_API_KEY;
    if (!apiKey) return res.status(500).send('Missing FERMION_API_KEY');

    const env = (req.query.env as string) || 'default';
    const userId = (req.query.uid as string) || 'anon-user';

    const config = ENVIRONMENTS[env as keyof typeof ENVIRONMENTS] || ENVIRONMENTS.default;
    const labId = config.productId;

    // 1) Get the contest URL and handle dynamic school host
    const schoolHost = process.env.FERMION_SCHOOL_HOST || 'careerbadge.apply-wizz.com';
    const contestUrl = config.contestUrl.replace('careerbadge.apply-wizz.com', schoolHost);
    
    // 2) Append skill if provided
    const skill = req.query.skill as string;
    let url = contestUrl;
    if (skill) {
      url += (url.includes('?') ? '&' : '?') + `skill=${encodeURIComponent(skill)}`;
    }

    // 3) Direct redirect (Fermion will handle login/registration prompt)
    res.setHeader('Cache-Control', 'no-store');
    return res.redirect(302, url);
  } catch (e: any) {
    console.error('fermion-redirect error:', e);
    return res.status(500).send(`Unexpected server error: ${e?.message || e}`);
  }
}
