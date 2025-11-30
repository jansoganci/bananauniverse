import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { job_id } = await req.json();
    
    if (!job_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing job_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Job'ı bul
    const { data: job, error: jobError } = await supabase
      .from('job_results')
      .select('fal_job_id, image_url')
      .eq('fal_job_id', job_id)
      .single();

    if (jobError || !job) {
      return new Response(
        JSON.stringify({ success: false, error: 'Job not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Storage'dan dosyayı sil
    // image_url artık path olduğu için direkt kullanabiliriz
    // Ancak http ile başlıyorsa (eski veri) silinemez veya parse edilmeli
    let filePath = job.image_url;
    
    if (filePath && !filePath.startsWith('http')) {
        const { error: deleteError } = await supabase.storage
          .from('noname-banana-images-prod')
          .remove([filePath]);

        if (deleteError) {
          console.error('Storage deletion failed:', deleteError);
          // Devam et, database'den sil
        }
    }

    // 3. Database'den image_url'yi null yap
    const { error: updateError } = await supabase
      .from('job_results')
      .update({ image_url: null })
      .eq('fal_job_id', job_id);

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: 'Database update failed' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Image deleted' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

