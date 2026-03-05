import { VercelRequest, VercelResponse } from '@vercel/node';

/**
 * Scaling Service (Server-Side Implementation)
 * 
 * This service handles auto-scaling logic without relying on an external database.
 * It uses server-side logging and memory-based threshold checks.
 */

// Configuration
const CONFIG = {
  TRAFFIC_STEP: 100,
  SCALING_THRESHOLD_PERCENTAGE: 0.8,
  COOL_DOWN_MS: 60000,
  METRIC_NAME: 'ActiveUserCount'
};

// In-memory state (Note: Ephemeral in serverless environments like Vercel)
let currentState = {
  maxCapacity: 1000,
  lastScalingTime: 0
};

/**
 * processScalingRequest: Main logic for threshold evaluation.
 * 
 * Logic: Current Traffic >= (Max_Capacity * 0.8) => Recursive Step Increment.
 */
function evaluateScaling(currentTraffic: number, maxCapacity: number): { newCapacity: number, events: string[] } {
  const threshold = maxCapacity * CONFIG.SCALING_THRESHOLD_PERCENTAGE;
  const events: string[] = [];

  if (currentTraffic >= threshold) {
    const nextCapacity = maxCapacity + CONFIG.TRAFFIC_STEP;
    events.push(`THRESHOLD_BREACH: Traffic ${currentTraffic} hit ${CONFIG.SCALING_THRESHOLD_PERCENTAGE * 100}% of ${maxCapacity}. Scaling to ${nextCapacity}.`);
    
    // Recursive check
    const recursiveResult = evaluateScaling(currentTraffic, nextCapacity);
    return {
      newCapacity: recursiveResult.newCapacity,
      events: [...events, ...recursiveResult.events]
    };
  }

  return { newCapacity: maxCapacity, events: [] };
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { currentTraffic } = req.body;

  if (typeof currentTraffic !== 'number') {
    return res.status(400).json({ error: 'currentTraffic must be a number' });
  }

  const now = Date.now();
  
  // Cooldown check
  if (now - currentState.lastScalingTime < CONFIG.COOL_DOWN_MS) {
    return res.status(200).json({
      status: 'COOLDOWN',
      message: 'Scaling policy is in cooling period.',
      currentCapacity: currentState.maxCapacity
    });
  }

  const result = evaluateScaling(currentTraffic, currentState.maxCapacity);

  if (result.newCapacity > currentState.maxCapacity) {
    // Log events to server console (Server logging)
    result.events.forEach(event => {
      console.log(`[INFRASTRUCTURE_LOG] [${new Date().toISOString()}] ${event}`);
    });

    // Update state
    const oldCapacity = currentState.maxCapacity;
    currentState.maxCapacity = result.newCapacity;
    currentState.lastScalingTime = now;

    return res.status(200).json({
      status: 'SCALE_OUT',
      oldCapacity,
      newCapacity: currentState.maxCapacity,
      events: result.events,
      timestamp: new Date().toISOString()
    });
  }

  return res.status(200).json({
    status: 'STABLE',
    currentCapacity: currentState.maxCapacity,
    threshold: currentState.maxCapacity * CONFIG.SCALING_THRESHOLD_PERCENTAGE
  });
}
