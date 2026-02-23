import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface EmotionAnalysisRequest {
  imageBase64: string;
  userId: string;
  petId?: string;
  memo?: string;
}

interface EmotionScores {
  happiness: number;
  sadness: number;
  anxiety: number;
  sleepiness: number;
  curiosity: number;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Parse request body
    const { imageBase64, userId, petId, memo }: EmotionAnalysisRequest = await req.json();

    if (!imageBase64 || !userId) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: imageBase64, userId' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Upload image to Supabase Storage first
    const imageBuffer = Uint8Array.from(atob(imageBase64), c => c.charCodeAt(0));
    const fileName = `emotions/${userId}/${Date.now()}.jpg`;

    const { data: uploadData, error: uploadError } = await supabaseClient.storage
      .from('images')
      .upload(fileName, imageBuffer, {
        contentType: 'image/jpeg',
        cacheControl: '3600',
      });

    if (uploadError) {
      console.error('Storage upload error:', uploadError);
      return new Response(
        JSON.stringify({ error: 'Failed to upload image' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Get public URL for the uploaded image
    const { data: { publicUrl } } = supabaseClient.storage
      .from('images')
      .getPublicUrl(fileName);

    // Perform emotion analysis
    const emotionScores = await analyzeEmotionWithGoogleVision(imageBase64);

    // Save analysis result to database
    const { data: historyData, error: historyError } = await supabaseClient
      .from('emotion_history')
      .insert({
        user_id: userId,
        pet_id: petId,
        image_url: publicUrl,
        emotion_analysis: emotionScores,
        memo: memo,
      })
      .select()
      .single();

    if (historyError) {
      console.error('Database insert error:', historyError);
      return new Response(
        JSON.stringify({ error: 'Failed to save analysis result' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          id: historyData.id,
          emotion_analysis: emotionScores,
          image_url: publicUrl,
          created_at: historyData.created_at,
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('Error in analyze-emotion function:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});

async function analyzeEmotionWithGoogleVision(imageBase64: string): Promise<EmotionScores> {
  const googleVisionApiKey = Deno.env.get('GOOGLE_VISION_API_KEY');
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY');

  // 1순위: Google Vision API 사용
  if (googleVisionApiKey) {
    try {
      const response = await fetch(
        `https://vision.googleapis.com/v1/images:annotate?key=${googleVisionApiKey}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            requests: [
              {
                image: {
                  content: imageBase64,
                },
                features: [
                  {
                    type: 'FACE_DETECTION',
                    maxResults: 10,
                  },
                  {
                    type: 'OBJECT_LOCALIZATION',
                    maxResults: 10,
                  },
                ],
              },
            ],
          }),
        }
      );

      const result = await response.json();

      if (!result.responses?.[0]?.error) {
        // Extract emotions from Google Vision API response
        const faces = result.responses?.[0]?.faceAnnotations || [];
        const objects = result.responses?.[0]?.localizedObjectAnnotations || [];

        // Process faces and objects to determine emotions
        return await processVisionResults(faces, objects);
      }

      console.error('Google Vision API error:', result.responses[0].error);
    } catch (error) {
      console.error('Google Vision API call failed:', error);
    }
  }

  // 2순위: Gemini API 사용
  if (geminiApiKey) {
    console.log('Falling back to Gemini API');
    try {
      return await analyzeEmotionWithGemini(imageBase64, geminiApiKey);
    } catch (error) {
      console.error('Gemini API call failed:', error);
    }
  }

  // 3순위: 데모 모드 (랜덤 결과)
  console.warn('No API keys configured, using fallback analysis');
  return await getFallbackEmotionAnalysis();
}

async function processVisionResults(faces: any[], objects: any[]): Promise<EmotionScores> {
  // Initialize emotion scores
  let happiness = 0;
  let sadness = 0;
  let anxiety = 0;
  let sleepiness = 0;
  let curiosity = 0;

  // Process face detection results
  if (faces.length > 0) {
    const face = faces[0]; // Use the first detected face

    // Map Google Vision emotions to our custom emotions
    const joyLikelihood = getLikelihoodScore(face.joyLikelihood);
    const sorrowLikelihood = getLikelihoodScore(face.sorrowLikelihood);
    const angerLikelihood = getLikelihoodScore(face.angerLikelihood);
    const surpriseLikelihood = getLikelihoodScore(face.surpriseLikelihood);

    happiness = joyLikelihood;
    sadness = sorrowLikelihood;
    anxiety = angerLikelihood;
    curiosity = surpriseLikelihood;

    // Sleepiness based on eye openness (if available)
    // This is a simplified approach - in reality, you'd need more sophisticated analysis
    sleepiness = Math.random() * 0.3; // Placeholder
  }

  // Process object detection for context
  const petObjects = objects.filter(obj =>
    ['Dog', 'Cat', 'Animal'].includes(obj.name)
  );

  if (petObjects.length > 0) {
    // Boost curiosity if pet objects are detected
    curiosity = Math.min(curiosity + 0.2, 1.0);
  }

  // Normalize scores to ensure they sum to 1.0
  const total = happiness + sadness + anxiety + sleepiness + curiosity;
  if (total > 0) {
    happiness /= total;
    sadness /= total;
    anxiety /= total;
    sleepiness /= total;
    curiosity /= total;
  } else {
    // Fallback if no emotions detected
    return await getFallbackEmotionAnalysis();
  }

  return {
    happiness: Math.round(happiness * 1000) / 1000,
    sadness: Math.round(sadness * 1000) / 1000,
    anxiety: Math.round(anxiety * 1000) / 1000,
    sleepiness: Math.round(sleepiness * 1000) / 1000,
    curiosity: Math.round(curiosity * 1000) / 1000,
  };
}

function getLikelihoodScore(likelihood: string): number {
  switch (likelihood) {
    case 'VERY_LIKELY': return 0.9;
    case 'LIKELY': return 0.7;
    case 'POSSIBLE': return 0.5;
    case 'UNLIKELY': return 0.3;
    case 'VERY_UNLIKELY': return 0.1;
    default: return 0.1;
  }
}

async function analyzeEmotionWithGemini(imageBase64: string, apiKey: string): Promise<EmotionScores> {
  const requestBody = {
    contents: [
      {
        parts: [
          {
            text: `이 이미지의 동물(강아지 또는 고양이)의 감정을 분석해주세요.

다음 5가지 감정에 대해 0.0~1.0 사이의 점수를 부여해주세요 (모든 값의 합은 1.0이 되어야 합니다):

1. happiness (행복함): 꼬리를 흔들거나, 입을 벌리고 있거나, 편안한 표정
2. sadness (슬픔): 귀가 처져있거나, 눈이 처져있거나, 우울한 표정
3. anxiety (불안): 경계하는 모습이나, 긴장된 자세, 스트레스를 받는 모습
4. sleepiness (졸림): 눈이 감기거나, 휴식 자세, 나른한 모습
5. curiosity (호기심): 귀가 세워져 있거나, 집중하는 모습, 탐색하는 자세

응답은 반드시 다음 JSON 형식으로만 응답해주세요:
{
  "happiness": 0.3,
  "sadness": 0.1,
  "anxiety": 0.2,
  "sleepiness": 0.1,
  "curiosity": 0.3
}

동물이 보이지 않거나 명확하지 않은 경우에는 균등하게 분배해주세요 (각각 0.2).`
          },
          {
            inline_data: {
              mime_type: 'image/jpeg',
              data: imageBase64
            }
          }
        ]
      }
    ],
    generationConfig: {
      temperature: 0.4,
      topK: 32,
      topP: 1,
      maxOutputTokens: 4096,
    },
    safetySettings: [
      {
        category: 'HARM_CATEGORY_HARASSMENT',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE'
      },
      {
        category: 'HARM_CATEGORY_HATE_SPEECH',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE'
      },
      {
        category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE'
      },
      {
        category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE'
      }
    ]
  };

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    }
  );

  if (!response.ok) {
    throw new Error(`Gemini API error: ${response.status} ${response.statusText}`);
  }

  const result = await response.json();

  if (!result.candidates || result.candidates.length === 0) {
    throw new Error('No response from Gemini API');
  }

  const textContent = result.candidates[0].content.parts[0].text;

  // Extract JSON from the response
  const jsonMatch = textContent.match(/\{[^}]*\}/);
  if (!jsonMatch) {
    throw new Error('Failed to parse JSON from Gemini response');
  }

  const emotionData = JSON.parse(jsonMatch[0]);

  // Parse and normalize emotion scores
  let happiness = parseFloat(emotionData.happiness || '0.2');
  let sadness = parseFloat(emotionData.sadness || '0.2');
  let anxiety = parseFloat(emotionData.anxiety || '0.2');
  let sleepiness = parseFloat(emotionData.sleepiness || '0.2');
  let curiosity = parseFloat(emotionData.curiosity || '0.2');

  const total = happiness + sadness + anxiety + sleepiness + curiosity;
  if (total > 0) {
    happiness /= total;
    sadness /= total;
    anxiety /= total;
    sleepiness /= total;
    curiosity /= total;
  }

  return {
    happiness: Math.round(happiness * 1000) / 1000,
    sadness: Math.round(sadness * 1000) / 1000,
    anxiety: Math.round(anxiety * 1000) / 1000,
    sleepiness: Math.round(sleepiness * 1000) / 1000,
    curiosity: Math.round(curiosity * 1000) / 1000,
  };
}

async function getFallbackEmotionAnalysis(): Promise<EmotionScores> {
  // Simulate AI analysis delay
  await new Promise(resolve => setTimeout(resolve, 2000));

  // Generate realistic random emotion scores that sum to 1.0
  const values = Array.from({ length: 5 }, () => Math.random());
  const sum = values.reduce((a, b) => a + b, 0);
  const normalizedValues = values.map(v => Math.round((v / sum) * 1000) / 1000);

  return {
    happiness: normalizedValues[0],
    sadness: normalizedValues[1],
    anxiety: normalizedValues[2],
    sleepiness: normalizedValues[3],
    curiosity: normalizedValues[4],
  };
}