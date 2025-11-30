import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  // API key kontrolü (güvenlik için)
  const apiKey = req.headers.get('x-api-key');
  const expectedKey = Deno.env.get('CLEANUP_API_KEY');
  
  if (expectedKey && apiKey !== expectedKey) {
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Silinmesi gereken görselleri bul (24 saat geçmiş ve kaydedilmemiş)
    const now = new Date();
    
    // auto_delete_at <= now AND saved_to_device = false AND image_url IS NOT NULL
    const { data: jobsToDelete, error: fetchError } = await supabase
      .from('job_results')
      .select('fal_job_id, image_url')
      .eq('saved_to_device', false)
      .lte('auto_delete_at', now.toISOString())
      .not('image_url', 'is', null);

    if (fetchError) {
      throw fetchError;
    }

    if (!jobsToDelete || jobsToDelete.length === 0) {
      return new Response(
        JSON.stringify({ success: true, deleted: 0, message: 'No images to delete' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // 2. Her görseli sil
    let deletedCount = 0;
    for (const job of jobsToDelete) {
      let filePath = job.image_url;
      
      // Sadece path olanları sil (http ile başlayanlar eski URL olabilir)
      if (filePath && !filePath.startsWith('http')) {
          // Storage'dan sil
          const { error: storageError } = await supabase.storage
            .from('noname-banana-images-prod')
            .remove([filePath]);

          if (!storageError) {
            // Database'den image_url'yi null yap
            await supabase
              .from('job_results')
              .update({ image_url: null })
              .eq('fal_job_id', job.fal_job_id);
            
            deletedCount++;
          }
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        deleted: deletedCount,
        total: jobsToDelete.length 
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

