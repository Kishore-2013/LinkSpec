import type { VercelRequest, VercelResponse } from '@vercel/node';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method not allowed' });
  }

  const otpApiUrl = process.env.OTP_API_URL || 'https://otp-sender-seven.vercel.app';

  try {
    const { user_id, work_email } = req.body;

    if (!user_id || !work_email) {
      return res.status(400).json({ message: 'user_id and work_email are required' });
    }

    console.log(`[request-otp] Requesting OTP for ${work_email} (User: ${user_id})`);

    const response = await fetch(`${otpApiUrl}/send-otp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: work_email,
        type: 'work_email_verification'
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('[request-otp] Error from OTP service:', data);
      return res.status(response.status).json({
        success: false,
        message: data.detail || 'Failed to send OTP'
      });
    }

    console.log(`[request-otp] OTP sent successfully to ${work_email}`);
    return res.status(200).json({
      success: true,
      message: 'OTP sent successfully',
      token: data.token
    });

  } catch (error) {
    console.error('[request-otp] Internal Error:', error);
    return res.status(500).json({ 
      success: false, 
      message: 'Internal server error',
      error: error instanceof Error ? error.message : String(error) 
    });
  }
}
