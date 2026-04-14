import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method not allowed' });
  }

  const otpApiUrl = process.env.OTP_API_URL || 'https://otp-sender-seven.vercel.app';
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error('[verify-otp] Supabase config missing');
    return res.status(500).json({ message: 'Server configuration error' });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const { user_id, work_email, otp, token } = req.body;

    if (!user_id || !work_email || !otp || !token) {
      return res.status(400).json({ message: 'user_id, work_email, otp, and token are required' });
    }

    console.log(`[verify-otp] Verifying OTP for ${work_email} (User: ${user_id})`);

    // 1. Verify OTP with Mail Service
    const otpVerifyResponse = await fetch(`${otpApiUrl}/verify-otp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: work_email,
        otp_code: otp,
        token: token
      }),
    });

    const otpData = await otpVerifyResponse.json();

    if (!otpVerifyResponse.ok) {
      console.error('[verify-otp] OTP Service error:', otpData);
      return res.status(otpVerifyResponse.status).json({
        success: false,
        message: otpData.detail || 'Invalid or expired OTP'
      });
    }

    console.log(`[verify-otp] OTP verified. Updating Supabase for user ${user_id}`);

    // 2. Update Supabase profile
    const { error: dbError } = await supabase
      .from('profiles_dim')
      .update({
        work_email: work_email,
        is_work_email_verified: true
      })
      .eq('id', user_id);

    if (dbError) {
      console.error('[verify-otp] Supabase update error:', dbError);
      return res.status(500).json({
        success: false,
        message: 'Verified, but failed to update profile in database'
      });
    }

    console.log(`[verify-otp] Success for user ${user_id}`);
    return res.status(200).json({
      success: true,
      message: 'Work email verified and profile updated'
    });

  } catch (error) {
    console.error('[verify-otp] Internal Error:', error);
    return res.status(500).json({ 
      success: false, 
      message: 'Internal server error',
      error: error instanceof Error ? error.message : String(error) 
    });
  }
}
