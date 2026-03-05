
import type { VercelRequest, VercelResponse } from '@vercel/node';
import nodemailer from 'nodemailer';

const ALLOWED_ORIGINS = [
  'http://localhost:59297',
  'https://localhost:8443', // experimental HTTPS dev port
  'http://localhost:8443',
  'https://linkspec.vercel.app', // placeholder for production
];

export default async function handler(
  request: VercelRequest,
  response: VercelResponse
) {
  const origin = request.headers.origin;

  // 1. CORS Middleware (Backend): Explicitly allow trusted origins
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    response.setHeader('Access-Control-Allow-Origin', origin);
  } else {
    // If not in our trusted list, we still need to handle the request properly in dev
    // or block it for production security. For now, allow all in dev if not set.
    response.setHeader('Access-Control-Allow-Origin', origin || '*');
  }

  response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');

  // 2. Handle the 'OPTIONS' pre-flight request
  if (request.method === 'OPTIONS') {
    return response.status(204).end();
  }

  if (request.method !== 'POST') {
    return response.status(405).json({ error: 'Method not allowed' });
  }

  // extract data
  const { email, otp, config } = request.body;

  if (!email || !otp) {
    return response.status(400).json({ error: 'Missing email or otp' });
  }

  // 3. SMTP Config (Gmail Server: smtp.gmail.com | Port: 465 (SSL))
  const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true, 
    auth: {
      user: config?.sender_email || process.env.GMAIL_SENDER_EMAIL,
      pass: config?.gmail_app_password || process.env.GMAIL_APP_PASSWORD,
    },
  });

  // 4. Send: Use professional HTML template
  const mailOptions = {
    from: `"LinkSpec" <${config?.sender_email || process.env.GMAIL_SENDER_EMAIL}>`,
    to: email,
    subject: 'Verification OTP Code - LinkSpec',
    html: `
      <div style="font-family: Arial, sans-serif; padding: 24px; color: #333; max-width: 480px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 20px;">
        <h2 style="color: #0066CC; font-size: 24px;">LinkSpec Verification</h2>
        <p style="font-size: 16px; line-height: 1.6;">Your LinkSpec Verification Code is:</p>
        <div style="background: #f0f6ff; padding: 24px; text-align: center; border-radius: 16px; margin: 24px 0;">
          <span style="font-size: 40px; font-weight: 900; letter-spacing: 10px; color: #0066CC;">${otp}</span>
        </div>
        <p style="font-size: 14px; color: #6b7280;">This code expires in <strong>5 minutes</strong>. Do not share this with anyone.</p>
        <hr style="border: 0; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
        <p style="font-size: 12px; color: #9ca3af; text-align: center;">© 2026 LinkSpec · Professional Domain Network</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return response.status(200).json({ success: true, message: 'OTP sent successfully' });
  } catch (error: any) {
    console.error('SMTP Error:', error);
    return response.status(500).json({ error: 'Failed to send OTP email', details: error.message });
  }
}
