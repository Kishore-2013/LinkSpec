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
    const { userId, labId } = req.body;

    // Validate required fields
    if (!userId || !labId) {
      return res.status(400).json({ 
        success: false,
        message: 'userId and labId are required' 
      });
    }

    console.log('🔧 Fetching Fermion lab results for:', { userId, labId });

    // Prepare the request payload
    const fermionPayload = {
      data: [{
        data: {
          userId,
          labId
        }
      }]
    };

    console.log('📤 Sending to Fermion:', JSON.stringify(fermionPayload, null, 2));

    // Call Fermion API
    const response = await fetch('https://backend.codedamn.com/api/public/get-user-io-lab-result', {
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
        message: 'Failed to fetch lab results from Fermion'
      });
    }

    // Parse the response
    const result = data[0]?.output;
    
    if (!result) {
      return res.status(500).json({
        success: false,
        message: 'Invalid response format from Fermion'
      });
    }

    // Check if it's an error response
    if (result.status === 'error') {
      return res.status(400).json({
        success: false,
        message: result.errorMessage || 'Error fetching lab results'
      });
    }

    // Success response
    const labData = result.data.result;
    
    // Calculate statistics if lab was attempted
    let stats: {
      totalTests: number;
      passedTests: number;
      failedTests: number;
      passRate: string;
      allTestsPassed: boolean;
    } | null = null;
    
    if (labData.isLabAttempted && labData.isRunComplete) {
      const totalTests = labData.resultArray.length;
      const passedTests = labData.resultArray.filter((tc: any) => tc.status === 'successful').length;
      const failedTests = totalTests - passedTests;
      const passRate = totalTests > 0 ? ((passedTests / totalTests) * 100).toFixed(2) : '0';

      stats = {
        totalTests,
        passedTests,
        failedTests,
        passRate: `${passRate}%`,
        allTestsPassed: passedTests === totalTests
      };
    }

    console.log('✅ Lab results fetched successfully');
    res.status(200).json({
      success: true,
      data: {
        userId,
        labId,
        isLabAttempted: labData.isLabAttempted,
        isRunComplete: labData.isRunComplete || false,
        resultArray: labData.resultArray || [],
        stats
      },
      message: 'Lab results fetched successfully'
    });

  } catch (error) {
    console.error('❌ Error fetching Fermion lab results:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error',
      error: error instanceof Error ? error.message : String(error) 
    });
  }
}
