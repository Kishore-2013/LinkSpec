import type { VercelRequest, VercelResponse } from '@vercel/node';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method not allowed' });
  }

  const apiKey = process.env.FERMION_API_KEY;
  if (!apiKey) {
    console.error('❌ FERMION_API_KEY not configured');
    return res.status(500).json({ message: 'FERMION_API_KEY not configured' });
  }

  try {
    const { userId, name, email, username } = req.body;
    
    console.log('🔧 Creating Fermion user with:', { userId, name, email, username });

    const fermionPayload = {
      data: [{
        data: {
          userId,
          profileDefaults: {
            name,
            username: username || email.split('@')[0],
            email,
            password: 'Created@123'
          },
          shouldSendWelcomeEmail: true
        }
      }]
    };

    console.log('📤 Sending to Fermion:', JSON.stringify(fermionPayload, null, 2));

    const response = await fetch('https://backend.codedamn.com/api/public/create-new-user', {
      method: 'POST',
      headers: {
        'FERMION-API-KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(fermionPayload),
    });

    const data = await response.json();
    console.log('📥 Fermion API response:', { status: response.status, data });

    if (!response.ok) {
      console.error('❌ Fermion API error:', data);
      return res.status(response.status).json({
        success: false,
        error: data,
        message: 'Failed to create user in Fermion'
      });
    }

    console.log('✅ Fermion user created successfully');
    res.status(200).json({
      success: true,
      data,
      message: 'User created successfully in Fermion'
    });

  } catch (error) {
    console.error('❌ Error creating Fermion user:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error',
      error: error instanceof Error ? error.message : String(error) 
    });
  }
}
