import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import nodemailer from 'nodemailer';
import * as dotenv from 'dotenv';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL || '';
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

// Initialize Supabase Admin Client
const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

// SMTP Transporter for Admin Invites
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_SENDER_EMAIL,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  // 1. Verify that the requester is an Admin
  // (In production, you'd extract 'sub' from the JWT and check profiles.role)
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Missing token' });
  }

  const { action, userData, userId } = req.body;

  try {
    if (action === 'create') {
      const { email, fullName, role, password } = userData;

      // Create user using Supabase Admin Auth API
      const { data, error } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName, role },
      });

      if (error) throw error;

      // Update the public profile role manually (trigger might handle it, but being explicit)
      await supabaseAdmin
        .from('profiles')
        .update({ role, full_name: fullName })
        .eq('id', data.user.id);

      // Send Welcome Invite Email
      await transporter.sendMail({
        from: `"LinkSpec Admin" <${process.env.GMAIL_SENDER_EMAIL}>`,
        to: email,
        subject: 'Welcome to LinkSpec: Your Account is Ready',
        text: `Hello ${fullName},\n\nYour Admin has created a new account for you on LinkSpec.\n\nLogin: ${email}\nTemporary Password: ${password}\n\nPlease change your password upon first login.`,
      });

      return res.status(200).json({ status: 'SUCCESS', user: data.user });
    }

    if (action === 'delete') {
      if (!userId) return res.status(400).json({ error: 'Missing userId' });

      // First, find the user to potentially cleanup storage
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId)
        .single();

      if (profile?.avatar_url) {
        // Simple logic for filename extraction (path after /profiles/)
        const parts = profile.avatar_url.split('/profiles/');
        const path = parts[parts.length - 1];
        if (path) {
          await supabaseAdmin.storage.from('profiles').remove([path]);
        }
      }

      // Delete user from Auth (Trigger handles database cleanup automatically)
      const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);
      if (error) throw error;

      return res.status(200).json({ status: 'SUCCESS', message: 'User deleted and storage cleaned' });
    }

    return res.status(400).json({ error: 'Invalid action provided' });

  } catch (err: any) {
    console.error('[ADMIN_API_ERROR]', err);
    return res.status(500).json({ error: err.message || 'Internal Server Error' });
  }
}
