-- ==========================================
-- MIGRATION: Async Jobs System
-- Purpose: Track asynchronous operations (video generation, image processing, etc.)
-- ==========================================

-- ==========================================
-- VIDEO JOBS TABLE (Example async job)
-- ==========================================
CREATE TABLE video_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) NOT NULL,

    -- Job details
    model_id TEXT NOT NULL, -- Which model/service to use
    prompt TEXT NOT NULL,
    duration INTEGER, -- Video duration in seconds

    -- Provider tracking
    provider_name TEXT, -- 'fal', 'runway', 'pika', etc.
    provider_job_id TEXT, -- External job ID from provider
    provider_attempts INTEGER DEFAULT 1,

    -- Status
    status TEXT CHECK (status IN (
        'pending',
        'processing',
        'completed',
        'failed',
        'cancelled'
    )) DEFAULT 'pending',

    -- Results
    video_url TEXT,
    thumbnail_url TEXT,
    error_message TEXT,

    -- Credits
    credits_used INTEGER NOT NULL,

    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,

    INDEX idx_video_jobs_user (user_id, created_at DESC),
    INDEX idx_video_jobs_status (status, created_at DESC),
    INDEX idx_video_jobs_provider (provider_job_id)
);

-- ==========================================
-- STORED PROCEDURE: Create Video Job
-- ==========================================
CREATE OR REPLACE FUNCTION create_video_job(
    p_user_id UUID,
    p_model_id TEXT,
    p_prompt TEXT,
    p_credits_required INTEGER,
    p_idempotency_key TEXT
) RETURNS JSONB AS $$
DECLARE
    job_id UUID;
    deduct_result JSONB;
BEGIN
    -- Check idempotency
    PERFORM 1 FROM idempotency_log
    WHERE idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Request already processed'
        );
    END IF;

    -- Deduct credits
    deduct_result := deduct_credits(
        p_user_id,
        p_credits_required,
        'video_generation',
        jsonb_build_object(
            'model_id', p_model_id,
            'prompt', p_prompt
        )
    );

    IF NOT (deduct_result->>'success')::boolean THEN
        RETURN deduct_result;
    END IF;

    -- Create job
    INSERT INTO video_jobs (
        user_id,
        model_id,
        prompt,
        credits_used,
        status
    ) VALUES (
        p_user_id,
        p_model_id,
        p_prompt,
        p_credits_required,
        'pending'
    ) RETURNING id INTO job_id;

    -- Store idempotency
    INSERT INTO idempotency_log (
        idempotency_key,
        user_id,
        operation_type,
        status_code,
        response_data
    ) VALUES (
        p_idempotency_key,
        p_user_id,
        'video_generation',
        200,
        jsonb_build_object('job_id', job_id)
    );

    RETURN jsonb_build_object(
        'success', true,
        'job_id', job_id,
        'credits_remaining', (deduct_result->>'credits_remaining')::integer
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- STORED PROCEDURE: Rollback Failed Job
-- ==========================================
CREATE OR REPLACE FUNCTION rollback_failed_job(
    p_job_id UUID
) RETURNS JSONB AS $$
DECLARE
    job RECORD;
BEGIN
    -- Get job details
    SELECT * INTO job
    FROM video_jobs
    WHERE id = p_job_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Job not found'
        );
    END IF;

    -- Only rollback if not already completed
    IF job.status = 'completed' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Cannot rollback completed job'
        );
    END IF;

    -- Refund credits
    PERFORM add_credits(
        job.user_id,
        job.credits_used,
        'job_failed_refund',
        NULL,
        jsonb_build_object('job_id', p_job_id)
    );

    -- Mark job as failed
    UPDATE video_jobs
    SET status = 'failed',
        completed_at = now()
    WHERE id = p_job_id;

    RETURN jsonb_build_object(
        'success', true,
        'credits_refunded', job.credits_used
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- ==========================================
ALTER TABLE video_jobs ENABLE ROW LEVEL SECURITY;

-- Users can only see their own jobs
CREATE POLICY "Users can view own jobs" ON video_jobs
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own jobs (through stored procedure)
CREATE POLICY "Users can create jobs" ON video_jobs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ==========================================
-- HELPER: Get User's Job History
-- ==========================================
CREATE OR REPLACE FUNCTION get_user_job_history(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE (
    job_id UUID,
    prompt TEXT,
    status TEXT,
    video_url TEXT,
    credits_used INTEGER,
    created_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        id,
        video_jobs.prompt,
        video_jobs.status,
        video_jobs.video_url,
        video_jobs.credits_used,
        video_jobs.created_at,
        video_jobs.completed_at
    FROM video_jobs
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
