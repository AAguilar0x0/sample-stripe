

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";






CREATE TYPE "public"."business_data_types" AS ENUM (
    'feature',
    'solution',
    'product',
    'service',
    'target_customer'
);


ALTER TYPE "public"."business_data_types" OWNER TO "postgres";


COMMENT ON TYPE "public"."business_data_types" IS 'The types of data we collect about a business';



CREATE TYPE "public"."page_state" AS ENUM (
    'published',
    'unpublished',
    'draft'
);


ALTER TYPE "public"."page_state" OWNER TO "postgres";


CREATE TYPE "public"."page_type" AS ENUM (
    'problem'
);


ALTER TYPE "public"."page_type" OWNER TO "postgres";


CREATE TYPE "public"."profile_state" AS ENUM (
    'published',
    'unpublished',
    'draft'
);


ALTER TYPE "public"."profile_state" OWNER TO "postgres";


CREATE TYPE "public"."query_run_status" AS ENUM (
    'pending',
    'running',
    'completed',
    'failed'
);


ALTER TYPE "public"."query_run_status" OWNER TO "postgres";


CREATE TYPE "public"."report_status" AS ENUM (
    'pending',
    'complete',
    'failed'
);


ALTER TYPE "public"."report_status" OWNER TO "postgres";


CREATE TYPE "public"."subscription_status" AS ENUM (
    'active',
    'canceled',
    'past_due',
    'trial',
    'unpaid',
    'incomplete',
    'incomplete_expired',
    'trialing',
    'paused'
);


ALTER TYPE "public"."subscription_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."DELETEget_ai_results_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer, "page_size" integer DEFAULT 10, "page_number" integer DEFAULT 1) RETURNS TABLE("ai_query_id" "uuid", "ai_query_run_id" "uuid", "rank" smallint, "reason" "text", "business_name" "text", "business_domain" "text", "created_at" timestamp with time zone, "total_count" bigint, "model_name" "text")
    LANGUAGE "plpgsql"
    AS $$BEGIN
    RETURN QUERY
    WITH relevant_queries AS (
        SELECT 
            aq.ai_query_id,
            am.model_name
        FROM ai_queries aq
        JOIN ai_models am ON aq.ai_model_id = am.ai_model_id
        WHERE aq.problem_id = problem_id_input
        AND aq.ai_model_id = model_id_input
        AND (aq.deleted IS NULL OR aq.deleted = false)
    ),
    query_runs AS (
        SELECT 
            aqr.ai_query_run_id,
            aqr.ai_query_id,
            aqr.created_at,
            aqr.status
        FROM ai_query_runs aqr
        JOIN relevant_queries rq ON aqr.ai_query_id = rq.ai_query_id
        WHERE aqr.created_at >= NOW() - (days_back * INTERVAL '1 day')
        AND aqr.status = 'completed'
        AND (aqr.deleted IS NULL OR aqr.deleted = false)
    ),
    results_with_count AS (
        SELECT 
            qr.ai_query_id,
            qr.ai_query_run_id,
            arr.rank,
            arr.reason,
            b.business_name,
            b.business_website as business_domain,
            qr.created_at,
            rq.model_name,
            COUNT(*) OVER() as total_count
        FROM query_runs qr
        JOIN relevant_queries rq ON qr.ai_query_id = rq.ai_query_id
        JOIN ai_rank_query_results arr ON qr.ai_query_run_id = arr.ai_query_run_id
        JOIN businesses b ON arr.business_id = b.business_id
        WHERE (arr.deleted IS NULL OR arr.deleted = false)
    )
    SELECT 
        results_with_count.ai_query_id,
        results_with_count.ai_query_run_id,
        results_with_count.rank,
        results_with_count.reason,
        results_with_count.business_name,
        results_with_count.business_domain,
        results_with_count.created_at,
        results_with_count.total_count,
        results_with_count.model_name
    FROM results_with_count
    ORDER BY results_with_count.created_at DESC
    LIMIT page_size
    OFFSET ((page_number - 1) * page_size);
END;$$;


ALTER FUNCTION "public"."DELETEget_ai_results_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer, "page_size" integer, "page_number" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."DELETEvectle_report_business_problem_rankings"("input_business_id" "uuid") RETURNS TABLE("business_id" "uuid", "problem_id" "uuid", "rank" smallint, "reason" "text", "business_name" "text", "business_domain" "text", "business_description" "text", "problem_description" "text")
    LANGUAGE "plpgsql"
    AS $$BEGIN
  RETURN QUERY
  WITH latest_queries AS (
    SELECT DISTINCT ON (ai_queries.problem_id) 
      ai_queries.ai_query_id,
      ai_queries.problem_id,
      ai_queries.created_at
    FROM ai_queries
    ORDER BY ai_queries.problem_id, ai_queries.created_at DESC
  )
  SELECT 
    ar.business_id,
    bp.problem_id,
    ar.rank,
    ar.reason,
    b.name,
    b.domain,
    b.description,
    p.the_problem
  FROM business_problems bp
  JOIN problems p ON bp.problem_id = p.problem_id
  JOIN latest_queries lq ON lq.problem_id = p.problem_id
  JOIN ai_rank_query_results ar ON lq.ai_query_id = ar.ai_query_id
  JOIN businesses b ON ar.business_id = b.id
  WHERE bp.business_id = input_business_id
  ORDER BY ar.rank ASC;
END;$$;


ALTER FUNCTION "public"."DELETEvectle_report_business_problem_rankings"("input_business_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."DEPRICATEDget_business_problems_with_details"("business_id_input" "uuid") RETURNS TABLE("business_id" "uuid", "created_at" timestamp with time zone, "deleted" boolean, "deleted_at" timestamp with time zone, "problem_id" "uuid", "solution_id" "uuid", "updated_at" timestamp with time zone, "problem_created_at" timestamp with time zone, "problem_deleted" boolean, "problem_deleted_at" timestamp with time zone, "the_problem" "text", "problem_updated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$begin
  return query
  select 
    bp.business_id,
    bp.created_at,
    bp.deleted,
    bp.deleted_at,
    bp.problem_id,
    bp.solution_id,
    bp.updated_at,
    p.created_at as problem_created_at,
    p.deleted as problem_deleted,
    p.deleted_at as problem_deleted_at,
    p.the_problem,
    p.updated_at as problem_updated_at
  from business_problems bp
  left join problems p on p.problem_id = bp.problem_id
  where bp.business_id = business_id_input
    and (bp.deleted is null or bp.deleted = false)
    and (p.deleted is null or p.deleted = false);
end;$$;


ALTER FUNCTION "public"."DEPRICATEDget_business_problems_with_details"("business_id_input" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."call_external_api"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT net.http_get(
    url := 'https://vectle.com/api/exa/industry-research-search?batch=true',
    headers := '{"Content-Type": "application/json"}'::jsonb
  )
  INTO result;

  -- Optionally, log the result for debugging
  RAISE NOTICE 'HTTP GET result: %', result;
END;
$$;


ALTER FUNCTION "public"."call_external_api"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_new_problem_embedding"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  max_attempts INTEGER := 3;
  attempt INTEGER := 0;
  success BOOLEAN := FALSE;
  problem_exists BOOLEAN;
BEGIN
  -- Log start
  INSERT INTO debug_logs (function_name, problem_id, message)
  VALUES ('create_new_problem_embedding', NEW.problem_id, 'Function started');
  
  -- Initial delay
  PERFORM pg_sleep(1);
  
  WHILE attempt < max_attempts AND NOT success LOOP
    BEGIN
      attempt := attempt + 1;
      
      -- Log attempt
      INSERT INTO debug_logs (function_name, problem_id, message, data)
      VALUES (
        'create_new_problem_embedding', 
        NEW.problem_id, 
        format('Attempt %s starting', attempt),
        jsonb_build_object('attempt', attempt)
      );

      -- Check if problem exists
      SELECT EXISTS (
        SELECT 1 
        FROM problems 
        WHERE problem_id = NEW.problem_id 
        AND (deleted IS NULL OR deleted = false)
      ) INTO problem_exists;

      -- Log existence check
      INSERT INTO debug_logs (function_name, problem_id, message, data)
      VALUES (
        'create_new_problem_embedding', 
        NEW.problem_id, 
        'Problem exists check',
        jsonb_build_object('exists', problem_exists)
      );

      IF problem_exists THEN
        -- Make HTTP call
        PERFORM http_post(
          'https://vectle.com/api/problems/create-embedding',
          '{"record": ' || row_to_json(NEW)::text || '}',
          'application/json'
        );
        
        success := TRUE;
        
        INSERT INTO debug_logs (function_name, problem_id, message)
        VALUES ('create_new_problem_embedding', NEW.problem_id, 'HTTP call successful');
      ELSE
        INSERT INTO debug_logs (function_name, problem_id, message)
        VALUES ('create_new_problem_embedding', NEW.problem_id, format('Problem not found on attempt %s, waiting...', attempt));
        
        PERFORM pg_sleep(attempt);
      END IF;

    EXCEPTION WHEN OTHERS THEN
      INSERT INTO debug_logs (function_name, problem_id, message, data)
      VALUES (
        'create_new_problem_embedding', 
        NEW.problem_id, 
        format('Error on attempt %s', attempt),
        jsonb_build_object('error', SQLERRM)
      );
      
      IF attempt < max_attempts THEN
        PERFORM pg_sleep(attempt);
      END IF;
    END;
  END LOOP;

  IF NOT success THEN
    INSERT INTO debug_logs (function_name, problem_id, message)
    VALUES ('create_new_problem_embedding', NEW.problem_id, format('Failed after %s attempts', max_attempts));
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_new_problem_embedding"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_ai_models_by_problem"("problem_id_input" "uuid", "days_back" integer) RETURNS TABLE("ai_query_id" "uuid", "ai_model_id" "uuid", "query_date" timestamp with time zone, "model_name" "text", "model_provider" "text", "model_description" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        aq.ai_query_id,
        aq.ai_model_id,
        aq.created_at as query_date,
        am.model_name,
        am.model_provider,
        am.model_description
    FROM ai_queries aq
    LEFT JOIN ai_models am ON aq.ai_model_id = am.ai_model_id
    WHERE 
        aq.related_entity_id = problem_id_input
        AND aq.created_at >= NOW() - (days_back * INTERVAL '1 day')
        AND aq.deleted IS NOT TRUE
    ORDER BY aq.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_ai_models_by_problem"("problem_id_input" "uuid", "days_back" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_ai_query_ranking_results"("problem_id_input" "uuid", "days_back" integer) RETURNS TABLE("ai_rank_query_results_id" "uuid", "ai_query_id" "uuid", "rank" integer, "reason" "text", "ranking_date" timestamp with time zone, "business_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        arqr.ai_rank_query_results_id,
        arqr.ai_query_id,
        arqr.rank,
        arqr.reason,
        arqr.created_at as ranking_date,
        arqr.business_id
    FROM ai_rank_query_results arqr
    WHERE 
        arqr.ai_query_id IN (
            SELECT ai_query_id 
            FROM ai_queries 
            WHERE problem_id = problem_id_input
            AND created_at >= NOW() - (days_back * INTERVAL '1 day')
        )
        AND arqr.deleted IS NOT TRUE
    ORDER BY arqr.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_ai_query_ranking_results"("problem_id_input" "uuid", "days_back" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_business_details"("business_id_input" "uuid") RETURNS TABLE("business_id" "uuid", "business_name" "text", "business_website" "text", "business_description" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  select 
    b.business_id,
    coalesce(b.business_name, ''),
    coalesce(b.business_website, ''),
    coalesce(b.business_description, '')
  from businesses b
  where b.business_id = business_id_input
    and (b.deleted is null or b.deleted = false);  -- Only return non-deleted businesses
$$;


ALTER FUNCTION "public"."get_business_details"("business_id_input" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_business_details"("business_id_input" "uuid") IS 'Gets public business details - accessible to all users';



CREATE OR REPLACE FUNCTION "public"."get_business_problems_with_details"("business_id_input" "uuid") RETURNS TABLE("business_id" "uuid", "problem_id" "uuid", "solution_id" "uuid", "the_problem" "text", "solution_name" "text", "solution_description" "text", "solution_link" "text")
    LANGUAGE "sql"
    AS $$SELECT 
    bp.business_id,
    bp.problem_id,
    bp.solution_id,
    p.the_problem,
    s.solution_name,
    s.solution_description,
    s.solution_link
  FROM business_problems bp
  JOIN problems p ON bp.problem_id = p.problem_id
  LEFT JOIN solutions s ON bp.solution_id = s.solution_id
  WHERE bp.business_id = business_id_input
    AND (bp.deleted IS NULL OR bp.deleted = false);$$;


ALTER FUNCTION "public"."get_business_problems_with_details"("business_id_input" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pending_ai_queries"() RETURNS TABLE("ai_query_id" "uuid", "related_entity_id" "uuid", "related_entity_type" "text", "ai_model_id" "uuid", "query_fuse" "text", "content" "jsonb")
    LANGUAGE "plpgsql"
    AS $$BEGIN
    RETURN QUERY
    
    -- Get problem-type queries
    SELECT 
        aq.ai_query_id,
        aq.related_entity_id,
        aq.related_entity_type,
        aq.ai_model_id,
        am.problem_query_fuse as query_fuse,
        jsonb_build_object(
            'problem', p.the_problem
        ) as content
    FROM ai_queries aq
    JOIN ai_models am ON aq.ai_model_id = am.ai_model_id
    JOIN problems p ON aq.related_entity_id = p.problem_id
    WHERE 
        aq.is_active = true 
        AND aq.next_run <= NOW()
        AND (aq.deleted IS NULL OR aq.deleted = false)
        AND aq.related_entity_type = 'problem'

    UNION ALL

    -- Get reputation-type queries
    SELECT 
        aq.ai_query_id,
        aq.related_entity_id,
        aq.related_entity_type,
        aq.ai_model_id,
        am.reputation_query_fuse as query_fuse,
        jsonb_build_object(
            'business', jsonb_build_object(
                'name', b.business_name,
                'website', b.business_website
            )
        ) as content
    FROM ai_queries aq
    JOIN ai_models am ON aq.ai_model_id = am.ai_model_id
    JOIN businesses b ON aq.related_entity_id = b.business_id
    WHERE 
        aq.is_active = true 
        AND aq.next_run <= NOW()
        AND (aq.deleted IS NULL OR aq.deleted = false)
        AND aq.related_entity_type = 'business_reputation';

END;$$;


ALTER FUNCTION "public"."get_pending_ai_queries"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pending_tracked_pages"() RETURNS TABLE("tracked_page_id" "uuid", "url" "text", "last_scraped_at" timestamp with time zone, "scraping_frequency" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    tp.tracked_page_id,
    tp.page_url as url,
    tp.last_run as last_scraped_at,  -- Changed from last_scan_at to last_run
    tp.frequency as scraping_frequency
  FROM tracked_pages tp
  WHERE 
    tp.next_run < NOW()              -- Changed from next_scan_at to next_run
    AND tp.is_active = true          -- Added active check
    AND (tp.deleted IS NULL OR tp.deleted = false)  -- Added deleted check
  ORDER BY tp.next_run ASC NULLS FIRST;
END;
$$;


ALTER FUNCTION "public"."get_pending_tracked_pages"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_problem_comparison"("business_id_input" "uuid") RETURNS TABLE("llm_problems" "jsonb", "website_problems" "jsonb")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
with llm_data as (
  select five_problems_business_solves
  from ai_reputation_query_results
  where related_entity_id = business_id_input
  order by created_at desc
  limit 1
),
website_data as (
  select 
    jsonb_agg(
      jsonb_build_object(
        'problem_id', p.problem_id,
        'problem_description', p.the_problem
      )
    ) as problems
  from business_problems bp
  join problems p on p.problem_id = bp.problem_id
  where bp.business_id = business_id_input
  and bp.source = 'find-five-business-problems'
  limit 5
)
select 
  coalesce(
    (select jsonb_agg(jsonb_build_object('problem_description', elem))
     from llm_data,
     jsonb_array_elements_text(to_jsonb(five_problems_business_solves)) elem),
    '[]'::jsonb
  ) as llm_problems,
  coalesce(wd.problems, '[]'::jsonb) as website_problems
from llm_data
cross join website_data wd;
$$;


ALTER FUNCTION "public"."get_problem_comparison"("business_id_input" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_problem_comparison"("business_id_input" "uuid") IS 'Gets problem comparison data - accessible to all users';



CREATE OR REPLACE FUNCTION "public"."get_problem_competition_data"("problem_id_input" "uuid") RETURNS TABLE("ai_rank_query_results_id" "uuid", "ai_query_id" "uuid", "ai_query_run_id" "uuid", "business_id" "uuid", "business_name" "text", "business_website" "text", "problem_id" "uuid", "rank" smallint, "reason" "text", "created_at" timestamp with time zone, "deleted" boolean, "deleted_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        arqr.ai_rank_query_results_id,
        arqr.ai_query_id,
        arqr.ai_query_run_id,
        arqr.business_id,
        b.business_name,
        b.business_website,
        arqr.problem_id,
        arqr.rank,
        arqr.reason,
        arqr.created_at,
        arqr.deleted,
        arqr.deleted_at
    FROM ai_rank_query_results arqr
    JOIN ai_query_runs aqr ON arqr.ai_query_run_id = aqr.ai_query_run_id
    LEFT JOIN businesses b ON arqr.business_id = b.business_id
    WHERE arqr.problem_id = problem_id_input
    AND (arqr.deleted IS NULL OR arqr.deleted = FALSE)
    AND aqr.status = 'completed'
    ORDER BY 
        arqr.created_at DESC,
        arqr.rank ASC
    LIMIT 10;
END;
$$;


ALTER FUNCTION "public"."get_problem_competition_data"("problem_id_input" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_problem_queries_and_models"("problem_id_input" "uuid") RETURNS TABLE("ai_query_id" "uuid", "created_at" timestamp with time zone, "is_active" boolean, "is_scheduled" boolean, "last_run" timestamp with time zone, "next_run" timestamp with time zone, "deleted" boolean, "deleted_at" timestamp with time zone, "ai_model_id" "uuid", "model_name" "text", "model_provider" "text", "model_description" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        aq.ai_query_id,
        aq.created_at,
        aq.is_active,
        aq.is_scheduled,
        aq.last_run,
        aq.next_run,
        aq.deleted,
        aq.deleted_at,
        am.ai_model_id,
        am.model_name,
        am.model_provider,
        am.model_description
    FROM ai_queries aq
    JOIN ai_models am ON aq.ai_model_id = am.ai_model_id
    WHERE aq.related_entity_id = problem_id_input
    AND aq.related_entity_type = 'problem'
    AND (aq.deleted IS NULL OR aq.deleted = FALSE)
    ORDER BY aq.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_problem_queries_and_models"("problem_id_input" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_problems_needing_embeddings"("batch_size" integer DEFAULT 5, "max_attempts" integer DEFAULT 3) RETURNS TABLE("problem_id" "uuid", "the_problem" "text", "embedding_attempts" integer, "last_embedding_attempt" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Update stuck processing records (older than 5 minutes) back to pending
    UPDATE problems p
    SET embedding_status = 'pending'
    WHERE p.embedding_status = 'processing'
    AND p.last_embedding_attempt < NOW() - INTERVAL '5 minutes';

    RETURN QUERY
    SELECT 
        p.problem_id,
        p.the_problem,
        p.embedding_attempts,
        p.last_embedding_attempt
    FROM problems p
    WHERE (p.embedding IS NULL)
    AND (p.deleted IS NULL OR p.deleted = false)
    AND (p.embedding_status IN ('pending', 'failed'))
    AND (p.embedding_attempts < max_attempts)
    ORDER BY 
        CASE WHEN p.last_embedding_attempt IS NULL THEN 0 ELSE 1 END,
        COALESCE(p.last_embedding_attempt, p.created_at),
        p.embedding_attempts
    LIMIT batch_size;

    -- Update status for selected problems
    UPDATE problems p
    SET 
        embedding_status = 'processing',
        embedding_attempts = COALESCE(p.embedding_attempts, 0) + 1,
        last_embedding_attempt = NOW()
    WHERE p.problem_id IN (
        SELECT p2.problem_id
        FROM problems p2
        WHERE (p2.embedding IS NULL)
        AND (p2.deleted IS NULL OR p2.deleted = false)
        AND (p2.embedding_status IN ('pending', 'failed'))
        AND (p2.embedding_attempts < max_attempts)
        ORDER BY 
            CASE WHEN p2.last_embedding_attempt IS NULL THEN 0 ELSE 1 END,
            COALESCE(p2.last_embedding_attempt, p2.created_at),
            p2.embedding_attempts
        LIMIT batch_size
    );
END;
$$;


ALTER FUNCTION "public"."get_problems_needing_embeddings"("batch_size" integer, "max_attempts" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_rank_results_by_run"("run_id_input" "uuid") RETURNS TABLE("ai_rank_query_results_id" "uuid", "ai_query_id" "uuid", "ai_query_run_id" "uuid", "business_id" "uuid", "created_at" timestamp with time zone, "rank" smallint, "reason" "text", "problem_id" "uuid", "business_name" "text", "business_website" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        arrq.ai_rank_query_results_id,
        arrq.ai_query_id,
        arrq.ai_query_run_id,
        arrq.business_id,
        arrq.created_at::timestamptz,
        arrq.rank::smallint,
        arrq.reason,
        arrq.problem_id,
        b.business_name,
        b.business_website
    FROM ai_rank_query_results arrq
    LEFT JOIN businesses b ON arrq.business_id = b.business_id
    WHERE arrq.ai_query_run_id = run_id_input
    AND (arrq.deleted IS NULL OR arrq.deleted = false)
    ORDER BY arrq.rank ASC;
END;
$$;


ALTER FUNCTION "public"."get_rank_results_by_run"("run_id_input" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_reputation_analysis"("business_id_input" "uuid") RETURNS TABLE("recommendation" "text", "recommendation_reason" "text", "created_at" timestamp with time zone, "ai_query_run_id" "uuid", "related_entity_id" "uuid", "related_entity_type" "text", "raw_response" "jsonb")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  select
    recommendation,
    recommendation_reason,
    created_at,
    ai_query_run_id,
    related_entity_id,
    related_entity_type,
    raw_response
  from ai_reputation_query_results
  where related_entity_id = business_id_input
  order by created_at desc
  limit 1;
$$;


ALTER FUNCTION "public"."get_reputation_analysis"("business_id_input" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_reputation_analysis"("business_id_input" "uuid") IS 'Gets latest reputation analysis for a business - accessible to all users';



CREATE OR REPLACE FUNCTION "public"."get_runs_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer) RETURNS TABLE("ai_query_run_id" "uuid", "model_name" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    WITH relevant_queries AS (
        SELECT 
            aq.ai_query_id,
            am.model_name
        FROM ai_queries aq
        JOIN ai_models am ON aq.ai_model_id = am.ai_model_id
        WHERE aq.related_entity_id = problem_id_input
        AND aq.ai_model_id = model_id_input
    ),
    query_runs AS (
        SELECT 
            aqr.ai_query_run_id,
            rq.model_name,
            aqr.created_at
        FROM ai_query_runs aqr
        JOIN relevant_queries rq ON aqr.ai_query_id = rq.ai_query_id
        WHERE aqr.created_at >= NOW() - (days_back * INTERVAL '1 day')
        AND aqr.deleted IS NOT TRUE
    )
    SELECT * FROM query_runs
    ORDER BY created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_runs_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_solutions_with_problems_by_busienssid"("business_id_input" "uuid") RETURNS TABLE("solution_id" "uuid", "solution_name" "text", "solution_description" "text", "solution_link" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "problem_count" integer, "problem_ids" "uuid"[], "problems" "jsonb")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  WITH filtered_solutions AS (
    SELECT 
      s.solution_id,
      s.solution_name,
      s.solution_description,
      s.solution_link,
      s.created_at,
      s.updated_at
    FROM solutions s
    WHERE s.business_id = business_id_input
    AND (s.deleted IS NULL OR s.deleted = false)
  ),
  filtered_problems AS (
    SELECT 
      bp.solution_id,
      p.problem_id,
      p.the_problem
    FROM business_problems bp
    JOIN problems p ON bp.problem_id = p.problem_id
    WHERE (bp.deleted IS NULL OR bp.deleted = false)
    AND (p.deleted IS NULL OR p.deleted = false)
  )
  SELECT 
    s.*,
    COALESCE(COUNT(p.problem_id) FILTER (WHERE p.problem_id IS NOT NULL), 0)::INTEGER,
    ARRAY_AGG(p.problem_id) FILTER (WHERE p.problem_id IS NOT NULL),
    COALESCE(
      JSON_AGG(
        JSON_BUILD_OBJECT(
          'id', p.problem_id,
          'description', p.the_problem
        )
      ) FILTER (WHERE p.problem_id IS NOT NULL),
      '[]'
    )::JSONB
  FROM filtered_solutions s
  LEFT JOIN filtered_problems p ON s.solution_id = p.solution_id
  GROUP BY 
    s.solution_id,
    s.solution_name,
    s.solution_description,
    s.solution_link,
    s.created_at,
    s.updated_at
  ORDER BY s.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_solutions_with_problems_by_busienssid"("business_id_input" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tracked_problems"("input_business_id" "uuid") RETURNS TABLE("problem_id" "uuid", "the_problem" "text", "created_at" timestamp with time zone, "business_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
begin
    return query
    select 
        p.problem_id,
        p.the_problem,
        bp.created_at,
        bp.business_id
    from business_problems bp
    join problems p on p.problem_id = bp.problem_id
    where bp.business_id = input_business_id
    and bp.tracked_by_business = true
    and (bp.deleted is null or bp.deleted = false)
    order by bp.created_at desc;
end;
$$;


ALTER FUNCTION "public"."get_tracked_problems"("input_business_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tracked_problems_with_runs"("input_business_id" "uuid") RETURNS TABLE("problem_id" "uuid", "the_problem" "text", "query_status" "public"."query_run_status", "query_id" "uuid", "query_run_id" "uuid", "last_run_at" timestamp with time zone, "has_results" boolean)
    LANGUAGE "plpgsql"
    AS $$BEGIN
    RETURN QUERY
    WITH latest_query_runs AS (
        SELECT DISTINCT ON (aqr.ai_query_id)
            aqr.ai_query_id,
            aqr.ai_query_run_id,
            aqr.status,
            aqr.created_at as last_run_at,
            EXISTS (
                SELECT 1 
                FROM ai_rank_query_results arqr 
                WHERE arqr.ai_query_run_id = aqr.ai_query_run_id
            ) as has_results
        FROM ai_query_runs aqr
        ORDER BY aqr.ai_query_id, aqr.created_at DESC
    )
    SELECT 
        bp.problem_id,
        p.the_problem,
        lqr.status,
        aq.ai_query_id as query_id,
        lqr.ai_query_run_id,
        lqr.last_run_at,
        lqr.has_results
    FROM business_problems bp
    JOIN problems p ON bp.problem_id = p.problem_id
    LEFT JOIN ai_queries aq ON bp.problem_id = aq.related_entity_id 
        AND aq.related_entity_type = 'problem'
        AND (aq.deleted IS NULL OR aq.deleted = FALSE)
    LEFT JOIN latest_query_runs lqr ON aq.ai_query_id = lqr.ai_query_id
    WHERE bp.business_id = input_business_id
        AND bp.tracked_by_business = TRUE
        AND (bp.deleted IS NULL OR bp.deleted = FALSE)
    ORDER BY 
        CASE 
            WHEN lqr.status = 'completed' AND lqr.has_results THEN 1
            WHEN lqr.status = 'completed' THEN 2
            WHEN lqr.status = 'running' THEN 3
            WHEN lqr.status = 'pending' THEN 4
            ELSE 5
        END,
        lqr.last_run_at DESC NULLS LAST;
END;$$;


ALTER FUNCTION "public"."get_tracked_problems_with_runs"("input_business_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_untracked_problems"("business_id_input" "uuid") RETURNS TABLE("problem_id" "uuid", "the_problem" "text")
    LANGUAGE "plpgsql"
    AS $$
begin
  return query
  select 
    bp.problem_id,
    p.the_problem
  from business_problems bp
  inner join problems p on p.problem_id = bp.problem_id
  where bp.business_id = business_id_input
  and (bp.deleted is null or bp.deleted = false)
  and bp.tracked_by_business = false;
end;
$$;


ALTER FUNCTION "public"."get_untracked_problems"("business_id_input" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_untracked_problems_with_similarity"("business_id_input" "uuid", "page_number" integer DEFAULT 1, "page_size" integer DEFAULT 10) RETURNS TABLE("problem_id" "uuid", "the_problem" "text", "similarity" double precision, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
begin
  return query
  with tracked_problems as (
    -- Get embeddings of problems the business is tracking
    select p.embedding::vector as emb
    from business_problems bp
    join problems p on bp.problem_id = p.problem_id
    where bp.business_id = business_id_input
    and bp.deleted is not true
    and p.embedding is not null
  ),
  untracked_problems as (
    -- Get problems not tracked by this business
    select p.*
    from problems p
    where not exists (
      select 1 
      from business_problems bp
      where bp.problem_id = p.problem_id
      and bp.business_id = business_id_input
      and bp.deleted is not true
    )
    and p.deleted is not true
  )
  select 
    up.problem_id,
    up.the_problem,
    case 
      when exists (select 1 from tracked_problems)
      then (
        select max(1 - cosine_distance(up.embedding::vector, tp.emb))
        from tracked_problems tp
      )
      else 0
    end as similarity,
    up.created_at
  from untracked_problems up
  where up.embedding is not null
  order by 
    case when exists (select 1 from tracked_problems)
    then (
      select max(1 - cosine_distance(up.embedding::vector, tp.emb))
      from tracked_problems tp
    )
    else extract(epoch from up.created_at) end desc
  limit page_size
  offset (page_number - 1) * page_size;
end; $$;


ALTER FUNCTION "public"."get_untracked_problems_with_similarity"("business_id_input" "uuid", "page_number" integer, "page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_by_email"("email" "text") RETURNS TABLE("id" "uuid", "stripe_cuid" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
BEGIN
  RETURN QUERY SELECT au.id, au.raw_user_meta_data->>'stripe_cuid' FROM auth.users au WHERE au.email = $1;
END;
$_$;


ALTER FUNCTION "public"."get_user_by_email"("email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_business_owner"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    free_plan_id uuid;
    free_plan_tracked_problems integer;
    free_plan_price_id text;
BEGIN
    RAISE NOTICE 'Trigger fired for role: %', NEW.role;

    IF NEW.role = 'owner' THEN
        RAISE NOTICE 'Owner role detected for business_id: %', NEW.business_id;
        
        SELECT 
            p.plan_id, 
            p.tracked_problems,
            pp.stripe_price_id
        INTO 
            free_plan_id, 
            free_plan_tracked_problems,
            free_plan_price_id
        FROM plans p
        LEFT JOIN plan_prices pp ON p.plan_id = pp.plan_id
        WHERE p.plan_name = 'Free' 
        AND p.deleted = false
        AND pp.interval = 'month';
        
        RAISE NOTICE 'Free plan ID: %, tracked problems: %, stripe_price_id: %', 
            free_plan_id, free_plan_tracked_problems, free_plan_price_id;

        INSERT INTO public.subscriptions (
            id,
            business_id,
            plan_id,
            plan,
            tracked_problems,
            status,
            stripe_price_id,
            created_at,
            updated_at
        )
        SELECT 
            gen_random_uuid(),
            NEW.business_id,
            free_plan_id,
            'Free',
            free_plan_tracked_problems,
            'active'::subscription_status,
            free_plan_price_id,
            NOW()::timestamptz,
            NOW()::timestamptz
        WHERE NOT EXISTS (
            SELECT 1 FROM public.subscriptions 
            WHERE business_id = NEW.business_id
        );
        
        RAISE NOTICE 'Subscription created for business_id: %', NEW.business_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_business_owner"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."run_daily_research"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  result json;
BEGIN
  SELECT net.http_post(
    url := 'https://app.vectle.com/api/exa/industry-research-search?batch=true',
    headers := '{"Content-Type": "application/json"}'
  )
  INTO result;
END;
$$;


ALTER FUNCTION "public"."run_daily_research"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_problems"("search_query" "text", "business_id_input" "uuid", "page_size_input" integer DEFAULT 20, "page_number_input" integer DEFAULT 1) RETURNS TABLE("problem_id" "uuid", "the_problem" "text", "similarity" real, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  WITH untracked_problems AS (
    SELECT p.problem_id, p.the_problem, p.created_at
    FROM problems p
    WHERE NOT EXISTS (
      SELECT 1 
      FROM business_problems bp 
      WHERE bp.problem_id = p.problem_id 
      AND bp.business_id = business_id_input
      AND (bp.deleted IS NULL OR bp.deleted = false)
    )
  )
  SELECT 
    up.problem_id,
    up.the_problem,
    CASE 
      WHEN search_query IS NULL OR search_query = '' THEN 1.0
      ELSE similarity(up.the_problem, search_query)
    END as similarity,  -- Changed to match the type
    up.created_at
  FROM untracked_problems up
  WHERE 
    CASE 
      WHEN search_query IS NULL OR search_query = '' THEN true
      ELSE up.the_problem ILIKE '%' || search_query || '%'
    END
  ORDER BY 
    similarity DESC,
    up.the_problem
  LIMIT page_size_input
  OFFSET (page_number_input - 1) * page_size_input;
END;
$$;


ALTER FUNCTION "public"."search_problems"("search_query" "text", "business_id_input" "uuid", "page_size_input" integer, "page_number_input" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_days_of_week"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$BEGIN
  -- Check if all elements are valid day names
  IF NEW.day_of_week IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM unnest(NEW.day_of_week) AS day
      WHERE day NOT IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')
    ) THEN
      RAISE EXCEPTION 'Invalid day of week. Must be lowercase day names.';
    END IF;
  END IF;
  RETURN NEW;
END;$$;


ALTER FUNCTION "public"."validate_days_of_week"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."website_scan_report_problem_rankings"("input_business_id" "uuid") RETURNS TABLE("business_id" "uuid", "problem_id" "uuid", "rank" smallint, "reason" "text", "business_name" "text", "business_domain" "text", "business_description" "text", "problem_description" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  WITH business_problems AS (
    SELECT DISTINCT p.problem_id, p.the_problem as problem_description
    FROM business_problems bp
    JOIN problems p ON bp.problem_id = p.problem_id
    WHERE bp.business_id = input_business_id
    AND (bp.deleted IS NULL OR bp.deleted = false)
    LIMIT 5
  ),
  latest_queries AS (
    SELECT DISTINCT ON (aq.related_entity_id) 
      aq.ai_query_id,
      aq.related_entity_id as problem_id
    FROM ai_queries aq
    JOIN business_problems bp ON bp.problem_id = aq.related_entity_id
    WHERE aq.related_entity_type = 'problem'
    AND (aq.deleted IS NULL OR aq.deleted = false)
    ORDER BY aq.related_entity_id, aq.created_at DESC
  ),
  latest_runs AS (
    SELECT DISTINCT ON (aqr.ai_query_id)
      aqr.ai_query_run_id,
      aqr.ai_query_id
    FROM ai_query_runs aqr
    JOIN latest_queries lq ON lq.ai_query_id = aqr.ai_query_id
    WHERE aqr.status = 'completed'
    AND (aqr.deleted IS NULL OR aqr.deleted = false)
    ORDER BY aqr.ai_query_id, aqr.created_at DESC
  )
  SELECT 
    arqr.business_id,
    bp.problem_id,
    arqr.rank,
    arqr.reason,
    b.business_name,
    b.business_website as business_domain,
    b.business_description,
    bp.problem_description
  FROM business_problems bp
  JOIN latest_queries lq ON bp.problem_id = lq.problem_id
  JOIN latest_runs lr ON lr.ai_query_id = lq.ai_query_id
  JOIN ai_rank_query_results arqr ON arqr.ai_query_run_id = lr.ai_query_run_id
  JOIN businesses b ON b.business_id = arqr.business_id
  WHERE (arqr.deleted IS NULL OR arqr.deleted = false)
  ORDER BY bp.problem_id, arqr.rank ASC;
END;
$$;


ALTER FUNCTION "public"."website_scan_report_problem_rankings"("input_business_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."ai_models" (
    "ai_model_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "model_name" "text",
    "model_provider" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "deleted" boolean,
    "model_description" "text",
    "problem_query_fuse" "text",
    "reputation_query_fuse" "text",
    "model_host_country" "text"
);


ALTER TABLE "public"."ai_models" OWNER TO "postgres";


COMMENT ON COLUMN "public"."ai_models"."problem_query_fuse" IS 'The Fusion API for this problem query and model';



COMMENT ON COLUMN "public"."ai_models"."model_host_country" IS 'Who is hosting this model';



CREATE TABLE IF NOT EXISTS "public"."ai_queries" (
    "related_entity_id" "uuid",
    "ai_model_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ai_query_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "is_scheduled" boolean DEFAULT false,
    "frequency" "text",
    "hour_of_day" integer,
    "minute_of_hour" integer,
    "day_of_week" "text"[],
    "day_of_month" integer,
    "last_run" timestamp with time zone,
    "next_run" timestamp with time zone,
    "is_active" boolean DEFAULT false,
    "deleted" boolean,
    "deleted_at" timestamp with time zone,
    "related_entity_type" "text",
    CONSTRAINT "ai_queries_day_of_month_check" CHECK ((("day_of_month" >= 1) AND ("day_of_month" <= 31))),
    CONSTRAINT "ai_queries_frequency_check" CHECK (("frequency" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text"]))),
    CONSTRAINT "ai_queries_hour_of_day_check" CHECK ((("hour_of_day" >= 0) AND ("hour_of_day" <= 23))),
    CONSTRAINT "ai_queries_minute_of_hour_check" CHECK ((("minute_of_hour" >= 0) AND ("minute_of_hour" <= 59))),
    CONSTRAINT "schedule_configuration_check" CHECK ((("is_scheduled" = false) OR (("is_scheduled" = true) AND ("frequency" IS NOT NULL) AND ("hour_of_day" IS NOT NULL) AND ("minute_of_hour" IS NOT NULL) AND (("frequency" = 'daily'::"text") OR (("frequency" = 'weekly'::"text") AND ("day_of_week" IS NOT NULL)) OR (("frequency" = 'monthly'::"text") AND ("day_of_month" IS NOT NULL))))))
);


ALTER TABLE "public"."ai_queries" OWNER TO "postgres";


COMMENT ON TABLE "public"."ai_queries" IS 'Every problem / model combination can have 1 query.';



COMMENT ON COLUMN "public"."ai_queries"."is_scheduled" IS 'Whether this query is scheduled for regular runs';



COMMENT ON COLUMN "public"."ai_queries"."frequency" IS 'Frequency of scheduled runs (daily, weekly, monthly)';



COMMENT ON COLUMN "public"."ai_queries"."hour_of_day" IS 'Hour of day to run (0-23)';



COMMENT ON COLUMN "public"."ai_queries"."minute_of_hour" IS 'Minute of hour to run (0-59)';



COMMENT ON COLUMN "public"."ai_queries"."day_of_week" IS 'Days of week to run on (for weekly frequency)';



COMMENT ON COLUMN "public"."ai_queries"."day_of_month" IS 'Day of month to run on (for monthly frequency)';



COMMENT ON COLUMN "public"."ai_queries"."last_run" IS 'Timestamp of last successful run';



COMMENT ON COLUMN "public"."ai_queries"."next_run" IS 'Timestamp of next scheduled run.  The ''get_pending_ai_queries'' function will run on a schedule to find all the rows where next_run is in the past and then process them through the process_ai_queries api';



COMMENT ON COLUMN "public"."ai_queries"."is_active" IS 'Whether the schedule is currently active';



CREATE TABLE IF NOT EXISTS "public"."ai_query_runs" (
    "ai_query_run_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ai_query_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "completed_at" timestamp with time zone,
    "status" "public"."query_run_status" DEFAULT 'pending'::"public"."query_run_status" NOT NULL,
    "error_message" "text",
    "run_metadata" "jsonb",
    "scheduled_run" boolean DEFAULT false NOT NULL,
    "schedule_metadata" "jsonb",
    "deleted" boolean,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."ai_query_runs" OWNER TO "postgres";


COMMENT ON TABLE "public"."ai_query_runs" IS 'Tracks individual runs of AI queries';



COMMENT ON COLUMN "public"."ai_query_runs"."ai_query_run_id" IS 'Unique identifier for the query run';



COMMENT ON COLUMN "public"."ai_query_runs"."ai_query_id" IS 'Reference to the parent query';



COMMENT ON COLUMN "public"."ai_query_runs"."created_at" IS 'When the run was initiated';



COMMENT ON COLUMN "public"."ai_query_runs"."completed_at" IS 'When the run completed (if successful)';



COMMENT ON COLUMN "public"."ai_query_runs"."status" IS 'Current status of the run';



COMMENT ON COLUMN "public"."ai_query_runs"."error_message" IS 'Error message if the run failed';



COMMENT ON COLUMN "public"."ai_query_runs"."run_metadata" IS 'Additional metadata about the run';



COMMENT ON COLUMN "public"."ai_query_runs"."scheduled_run" IS 'Whether this was a scheduled run';



COMMENT ON COLUMN "public"."ai_query_runs"."schedule_metadata" IS 'Metadata about the schedule that triggered this run';



CREATE TABLE IF NOT EXISTS "public"."ai_rank_query_results" (
    "ai_rank_query_results_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "problem_id" "uuid",
    "business_id" "uuid",
    "rank" smallint,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ai_query_id" "uuid",
    "ai_query_run_id" "uuid",
    "deleted" boolean,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."ai_rank_query_results" OWNER TO "postgres";


COMMENT ON COLUMN "public"."ai_rank_query_results"."ai_query_run_id" IS 'Reference to the specific query run that generated these results';



CREATE TABLE IF NOT EXISTS "public"."ai_reputation_query_results" (
    "ai_reputation_query_results_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "recommendation_reason" "text",
    "ai_query_id" "uuid",
    "ai_query_run_id" "uuid",
    "related_entity_type" "text",
    "related_entity_id" "uuid" DEFAULT "gen_random_uuid"(),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "deleted" boolean,
    "raw_response" "jsonb",
    "recommendation" "text",
    "five_problems_business_solves" "jsonb"
);


ALTER TABLE "public"."ai_reputation_query_results" OWNER TO "postgres";


COMMENT ON COLUMN "public"."ai_reputation_query_results"."recommendation" IS 'yes, no, it depends, etc.';



COMMENT ON COLUMN "public"."ai_reputation_query_results"."five_problems_business_solves" IS 'What are the 5 problems AI thinks this business solves';



CREATE TABLE IF NOT EXISTS "public"."aio_report_email_recipients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "email" "text",
    "business_id" "uuid",
    "first_name" "text",
    "last_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "subscribed" boolean
);


ALTER TABLE "public"."aio_report_email_recipients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."business_data" (
    "business_data_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_id" "uuid",
    "data_type" "public"."business_data_types" NOT NULL,
    "data_name" "text",
    "data_description" "text",
    "data_link" "text",
    "created_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text") NOT NULL,
    "updated_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text"),
    "deleted_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text"),
    "deleted" boolean,
    "source" "text"
);


ALTER TABLE "public"."business_data" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."business_problems" (
    "business_id" "uuid" NOT NULL,
    "problem_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "deleted" boolean,
    "tracked_by_business" boolean,
    "source" "text"
);


ALTER TABLE "public"."business_problems" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."businesses" (
    "business_id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "business_name" "text",
    "business_website" "text",
    "subdomain" "text",
    "business_description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "onboarding_complete" boolean,
    "domain_uuid" "text",
    "claimed" boolean,
    "last_scan" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "deleted" boolean,
    "business_logo_url" "text",
    "business_favicon_url" "text",
    "stripe_cuid" "text"
);


ALTER TABLE "public"."businesses" OWNER TO "postgres";


COMMENT ON TABLE "public"."businesses" IS 'These are unique businesses';



CREATE TABLE IF NOT EXISTS "public"."debug_logs" (
    "id" bigint NOT NULL,
    "data" "json",
    "function_name" "text",
    "message" "text",
    "problem_id" "text",
    "timestamp" timestamp with time zone
);


ALTER TABLE "public"."debug_logs" OWNER TO "postgres";


ALTER TABLE "public"."debug_logs" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."debug_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."page_business_data" (
    "business_data_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "page_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."page_business_data" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."page_problem" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "page_id" "uuid",
    "problem_id" "uuid"
);


ALTER TABLE "public"."page_problem" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pages" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "business_id" "uuid" NOT NULL,
    "title" "text" DEFAULT ''::"text" NOT NULL,
    "description" "text" DEFAULT ''::"text" NOT NULL,
    "body" "text" DEFAULT ''::"text" NOT NULL,
    "type" "public"."page_type" NOT NULL,
    "slug" "text" NOT NULL,
    "state" "public"."page_state" DEFAULT 'draft'::"public"."page_state" NOT NULL
);


ALTER TABLE "public"."pages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plan_models" (
    "plan_id" "uuid" NOT NULL,
    "ai_model_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "deleted" boolean
);


ALTER TABLE "public"."plan_models" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plan_prices" (
    "price_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_id" "uuid",
    "interval" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "currency" "text" DEFAULT 'usd'::"text" NOT NULL,
    "stripe_price_id" "text" NOT NULL,
    "stripe_product_id" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "plan_prices_interval_check" CHECK (("interval" = ANY (ARRAY['month'::"text", 'year'::"text"])))
);


ALTER TABLE "public"."plan_prices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plans" (
    "plan_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_name" "text" NOT NULL,
    "tracked_problems" smallint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "deleted" boolean,
    "is_active" boolean,
    "stripe_product_id" "text" NOT NULL
);


ALTER TABLE "public"."plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."problems" (
    "problem_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "the_problem" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "deleted" boolean,
    "embedding" "public"."vector"(1536),
    "embedding_status" "text" DEFAULT 'pending'::"text",
    "embedding_attempts" integer DEFAULT 0,
    "last_embedding_attempt" timestamp with time zone,
    "embedding_error" "text",
    CONSTRAINT "problems_embedding_status_check" CHECK (("embedding_status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."problems" OWNER TO "postgres";


COMMENT ON TABLE "public"."problems" IS 'A list of all problems businesses solve';



COMMENT ON COLUMN "public"."problems"."embedding_status" IS 'Status of embedding creation: pending, processing, completed, or failed';



COMMENT ON COLUMN "public"."problems"."embedding_attempts" IS 'Number of attempts to create embedding';



COMMENT ON COLUMN "public"."problems"."last_embedding_attempt" IS 'Timestamp of last embedding creation attempt';



COMMENT ON COLUMN "public"."problems"."embedding_error" IS 'Error message if embedding creation failed';



CREATE TABLE IF NOT EXISTS "public"."subscriptions" (
    "business_id" "uuid" NOT NULL,
    "product_id" "text" NOT NULL,
    "stripe_subscription_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "expired_at" timestamp with time zone
);


ALTER TABLE "public"."subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tracked_pages" (
    "tracked_page_id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "business_id" "uuid",
    "page_url" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT true,
    "is_scheduled" boolean DEFAULT true,
    "frequency" "text",
    "hour_of_day" integer,
    "minute_of_hour" integer,
    "day_of_month" integer[],
    "day_of_week" "text"[],
    "last_run" timestamp with time zone,
    "next_run" timestamp with time zone,
    "deleted" boolean DEFAULT false,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."tracked_pages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tracked_pages_scraping_results" (
    "scraping_result_id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tracked_page_id" "uuid",
    "scraping_run_id" "uuid",
    "markdown_content" "text",
    "json_content" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "deleted" boolean DEFAULT false,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."tracked_pages_scraping_results" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tracked_pages_scraping_runs" (
    "scraping_run_id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tracked_page_id" "uuid",
    "status" "text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp with time zone,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "deleted" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "tracked_pages_scraping_runs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'running'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."tracked_pages_scraping_runs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "user_role_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "business_id" "uuid",
    "role" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_roles" IS 'What businesses a user is associated with and their role';



CREATE TABLE IF NOT EXISTS "public"."vectle_profiles" (
    "vectle_profile_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_id" "uuid",
    "profile_logo" "text",
    "profile_business_intro" "text",
    "profile_cta_text" "text",
    "profile_cta_link" "text",
    "profile_primary_color" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "deleted" boolean,
    "profile_handle" "text",
    "state" "public"."page_state" DEFAULT 'published'::"public"."page_state" NOT NULL
);


ALTER TABLE "public"."vectle_profiles" OWNER TO "postgres";


ALTER TABLE ONLY "public"."ai_models"
    ADD CONSTRAINT "ai_models_pkey" PRIMARY KEY ("ai_model_id");



ALTER TABLE ONLY "public"."ai_queries"
    ADD CONSTRAINT "ai_queries_pkey" PRIMARY KEY ("ai_query_id");



ALTER TABLE ONLY "public"."ai_query_runs"
    ADD CONSTRAINT "ai_query_runs_pkey" PRIMARY KEY ("ai_query_run_id");



ALTER TABLE ONLY "public"."ai_rank_query_results"
    ADD CONSTRAINT "ai_rank_query_results_pkey" PRIMARY KEY ("ai_rank_query_results_id");



ALTER TABLE ONLY "public"."ai_reputation_query_results"
    ADD CONSTRAINT "ai_reputation_query_results_pkey" PRIMARY KEY ("ai_reputation_query_results_id");



ALTER TABLE ONLY "public"."aio_report_email_recipients"
    ADD CONSTRAINT "aio_report_email_recipients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."business_data"
    ADD CONSTRAINT "business_data_pkey" PRIMARY KEY ("business_data_id");



ALTER TABLE ONLY "public"."business_problems"
    ADD CONSTRAINT "business_problems_pkey" PRIMARY KEY ("business_id", "problem_id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "business_users_pkey" PRIMARY KEY ("user_role_id");



ALTER TABLE ONLY "public"."businesses"
    ADD CONSTRAINT "businesses_business_website_key" UNIQUE ("business_website");



ALTER TABLE ONLY "public"."businesses"
    ADD CONSTRAINT "businesses_pkey" PRIMARY KEY ("business_id");



ALTER TABLE ONLY "public"."businesses"
    ADD CONSTRAINT "businesses_stripe_cuid_key" UNIQUE ("stripe_cuid");



ALTER TABLE ONLY "public"."debug_logs"
    ADD CONSTRAINT "debug_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."page_business_data"
    ADD CONSTRAINT "page_business_data_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pages"
    ADD CONSTRAINT "pages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pages"
    ADD CONSTRAINT "pages_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."pages"
    ADD CONSTRAINT "pages_title_key" UNIQUE ("title");



ALTER TABLE ONLY "public"."plan_models"
    ADD CONSTRAINT "plan_models_pkey" PRIMARY KEY ("plan_id", "ai_model_id");



ALTER TABLE ONLY "public"."plan_prices"
    ADD CONSTRAINT "plan_prices_pkey" PRIMARY KEY ("price_id");



ALTER TABLE ONLY "public"."plan_prices"
    ADD CONSTRAINT "plan_prices_plan_id_interval_key" UNIQUE ("plan_id", "interval");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_pkey" PRIMARY KEY ("plan_id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_plan_name_key" UNIQUE ("plan_name");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_stripe_plan_id_key" UNIQUE ("stripe_product_id");



ALTER TABLE ONLY "public"."problems"
    ADD CONSTRAINT "problems_businesses_solve_pkey" PRIMARY KEY ("problem_id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("business_id", "product_id");



ALTER TABLE ONLY "public"."tracked_pages"
    ADD CONSTRAINT "tracked_pages_pkey" PRIMARY KEY ("tracked_page_id");



ALTER TABLE ONLY "public"."tracked_pages_scraping_results"
    ADD CONSTRAINT "tracked_pages_scraping_results_pkey" PRIMARY KEY ("scraping_result_id");



ALTER TABLE ONLY "public"."tracked_pages_scraping_runs"
    ADD CONSTRAINT "tracked_pages_scraping_runs_pkey" PRIMARY KEY ("scraping_run_id");



ALTER TABLE ONLY "public"."vectle_profiles"
    ADD CONSTRAINT "vectle_profiles_pkey" PRIMARY KEY ("vectle_profile_id");



ALTER TABLE ONLY "public"."vectle_profiles"
    ADD CONSTRAINT "vectle_profiles_profile_handle_key" UNIQUE ("profile_handle");



CREATE INDEX "idx_ai_queries_next_run" ON "public"."ai_queries" USING "btree" ("next_run") WHERE (("is_scheduled" = true) AND ("is_active" = true));



CREATE INDEX "idx_ai_query_runs_ai_query_id" ON "public"."ai_query_runs" USING "btree" ("ai_query_id");



CREATE INDEX "idx_ai_query_runs_created_at" ON "public"."ai_query_runs" USING "btree" ("created_at");



CREATE INDEX "idx_ai_query_runs_status" ON "public"."ai_query_runs" USING "btree" ("status");



CREATE INDEX "idx_ai_rank_query_results_query_run_id" ON "public"."ai_rank_query_results" USING "btree" ("ai_query_run_id");



CREATE INDEX "idx_problems_embedding_status" ON "public"."problems" USING "btree" ("embedding_status") WHERE (("embedding" IS NULL) AND (("deleted" IS NULL) OR ("deleted" = false)));



CREATE INDEX "idx_scraped_results_run" ON "public"."tracked_pages_scraping_results" USING "btree" ("scraping_run_id");



CREATE INDEX "idx_scraped_results_tracked_page" ON "public"."tracked_pages_scraping_results" USING "btree" ("tracked_page_id");



CREATE INDEX "idx_scraping_runs_status" ON "public"."tracked_pages_scraping_runs" USING "btree" ("status");



CREATE INDEX "idx_scraping_runs_tracked_page" ON "public"."tracked_pages_scraping_runs" USING "btree" ("tracked_page_id");



CREATE INDEX "idx_subscriptions_business_id" ON "public"."subscriptions" USING "btree" ("product_id");



CREATE INDEX "idx_subscriptions_stripe_subscription_id" ON "public"."subscriptions" USING "btree" ("stripe_subscription_id");



CREATE OR REPLACE TRIGGER "on_new_business_owner" AFTER INSERT ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_business_owner"();



CREATE OR REPLACE TRIGGER "on_problem_created" AFTER INSERT ON "public"."problems" FOR EACH ROW EXECUTE FUNCTION "public"."create_new_problem_embedding"();



CREATE OR REPLACE TRIGGER "update_subscriptions_updated_at" BEFORE UPDATE ON "public"."subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "validate_days_of_week_trigger" BEFORE INSERT OR UPDATE ON "public"."ai_queries" FOR EACH ROW EXECUTE FUNCTION "public"."validate_days_of_week"();



ALTER TABLE ONLY "public"."ai_queries"
    ADD CONSTRAINT "ai_queries_ai_model_id_fkey" FOREIGN KEY ("ai_model_id") REFERENCES "public"."ai_models"("ai_model_id");



ALTER TABLE ONLY "public"."ai_query_runs"
    ADD CONSTRAINT "ai_query_runs_ai_query_id_fkey" FOREIGN KEY ("ai_query_id") REFERENCES "public"."ai_queries"("ai_query_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ai_rank_query_results"
    ADD CONSTRAINT "ai_rank_query_results_ai_query_id_fkey" FOREIGN KEY ("ai_query_id") REFERENCES "public"."ai_queries"("ai_query_id");



ALTER TABLE ONLY "public"."ai_rank_query_results"
    ADD CONSTRAINT "ai_rank_query_results_ai_query_run_id_fkey" FOREIGN KEY ("ai_query_run_id") REFERENCES "public"."ai_query_runs"("ai_query_run_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ai_rank_query_results"
    ADD CONSTRAINT "ai_rank_query_results_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id");



ALTER TABLE ONLY "public"."ai_rank_query_results"
    ADD CONSTRAINT "ai_rank_query_results_problem_id_fkey" FOREIGN KEY ("problem_id") REFERENCES "public"."problems"("problem_id");



ALTER TABLE ONLY "public"."ai_reputation_query_results"
    ADD CONSTRAINT "ai_reputation_query_results_ai_query_id_fkey" FOREIGN KEY ("ai_query_id") REFERENCES "public"."ai_queries"("ai_query_id");



ALTER TABLE ONLY "public"."ai_reputation_query_results"
    ADD CONSTRAINT "ai_reputation_query_results_ai_query_run_id_fkey" FOREIGN KEY ("ai_query_run_id") REFERENCES "public"."ai_query_runs"("ai_query_run_id");



ALTER TABLE ONLY "public"."aio_report_email_recipients"
    ADD CONSTRAINT "aio_report_email_recipients_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id");



ALTER TABLE ONLY "public"."business_data"
    ADD CONSTRAINT "business_data_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."business_problems"
    ADD CONSTRAINT "business_problems_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."business_problems"
    ADD CONSTRAINT "business_problems_problem_id_fkey" FOREIGN KEY ("problem_id") REFERENCES "public"."problems"("problem_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "business_users_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "business_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."page_business_data"
    ADD CONSTRAINT "page_business_data_business_data_id_fkey" FOREIGN KEY ("business_data_id") REFERENCES "public"."business_data"("business_data_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."page_business_data"
    ADD CONSTRAINT "page_business_data_page_id_fkey" FOREIGN KEY ("page_id") REFERENCES "public"."pages"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."page_problem"
    ADD CONSTRAINT "page_problem_page_id_fkey" FOREIGN KEY ("page_id") REFERENCES "public"."pages"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."page_problem"
    ADD CONSTRAINT "page_problem_problem_id_fkey" FOREIGN KEY ("problem_id") REFERENCES "public"."problems"("problem_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pages"
    ADD CONSTRAINT "pages_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plan_models"
    ADD CONSTRAINT "plan_models_ai_model_id_fkey" FOREIGN KEY ("ai_model_id") REFERENCES "public"."ai_models"("ai_model_id");



ALTER TABLE ONLY "public"."plan_models"
    ADD CONSTRAINT "plan_models_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans"("plan_id");



ALTER TABLE ONLY "public"."plan_prices"
    ADD CONSTRAINT "plan_prices_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans"("plan_id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."plans"("stripe_product_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tracked_pages"
    ADD CONSTRAINT "tracked_pages_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id");



ALTER TABLE ONLY "public"."tracked_pages_scraping_results"
    ADD CONSTRAINT "tracked_pages_scraped_results_scraping_run_id_fkey" FOREIGN KEY ("scraping_run_id") REFERENCES "public"."tracked_pages_scraping_runs"("scraping_run_id");



ALTER TABLE ONLY "public"."tracked_pages_scraping_results"
    ADD CONSTRAINT "tracked_pages_scraped_results_tracked_page_id_fkey" FOREIGN KEY ("tracked_page_id") REFERENCES "public"."tracked_pages"("tracked_page_id");



ALTER TABLE ONLY "public"."tracked_pages_scraping_runs"
    ADD CONSTRAINT "tracked_pages_scraping_runs_tracked_page_id_fkey" FOREIGN KEY ("tracked_page_id") REFERENCES "public"."tracked_pages"("tracked_page_id");



ALTER TABLE ONLY "public"."vectle_profiles"
    ADD CONSTRAINT "vectle_profiles_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("business_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE "public"."page_business_data" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pages" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."business_problems";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."problems";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "service_role";





















































































































































































































GRANT ALL ON FUNCTION "public"."DELETEget_ai_results_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer, "page_size" integer, "page_number" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."DELETEget_ai_results_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer, "page_size" integer, "page_number" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."DELETEget_ai_results_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer, "page_size" integer, "page_number" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."DELETEvectle_report_business_problem_rankings"("input_business_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."DELETEvectle_report_business_problem_rankings"("input_business_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."DELETEvectle_report_business_problem_rankings"("input_business_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."DEPRICATEDget_business_problems_with_details"("business_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."DEPRICATEDget_business_problems_with_details"("business_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."DEPRICATEDget_business_problems_with_details"("business_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."call_external_api"() TO "anon";
GRANT ALL ON FUNCTION "public"."call_external_api"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."call_external_api"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_new_problem_embedding"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_new_problem_embedding"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_new_problem_embedding"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_ai_models_by_problem"("problem_id_input" "uuid", "days_back" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_ai_models_by_problem"("problem_id_input" "uuid", "days_back" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_ai_models_by_problem"("problem_id_input" "uuid", "days_back" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_ai_query_ranking_results"("problem_id_input" "uuid", "days_back" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_ai_query_ranking_results"("problem_id_input" "uuid", "days_back" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_ai_query_ranking_results"("problem_id_input" "uuid", "days_back" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_business_details"("business_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_business_details"("business_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_business_details"("business_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_business_problems_with_details"("business_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_business_problems_with_details"("business_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_business_problems_with_details"("business_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_pending_ai_queries"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_pending_ai_queries"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pending_ai_queries"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_pending_tracked_pages"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_pending_tracked_pages"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pending_tracked_pages"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_problem_comparison"("business_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_problem_comparison"("business_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_problem_comparison"("business_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_problem_competition_data"("problem_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_problem_competition_data"("problem_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_problem_competition_data"("problem_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_problem_queries_and_models"("problem_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_problem_queries_and_models"("problem_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_problem_queries_and_models"("problem_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_problems_needing_embeddings"("batch_size" integer, "max_attempts" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_problems_needing_embeddings"("batch_size" integer, "max_attempts" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_problems_needing_embeddings"("batch_size" integer, "max_attempts" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_rank_results_by_run"("run_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_rank_results_by_run"("run_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_rank_results_by_run"("run_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_reputation_analysis"("business_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_reputation_analysis"("business_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_reputation_analysis"("business_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_runs_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_runs_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_runs_by_problem_and_model"("problem_id_input" "uuid", "model_id_input" "uuid", "days_back" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_solutions_with_problems_by_busienssid"("business_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_solutions_with_problems_by_busienssid"("business_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_solutions_with_problems_by_busienssid"("business_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_tracked_problems"("input_business_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_tracked_problems"("input_business_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tracked_problems"("input_business_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_tracked_problems_with_runs"("input_business_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_tracked_problems_with_runs"("input_business_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tracked_problems_with_runs"("input_business_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_untracked_problems"("business_id_input" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_untracked_problems"("business_id_input" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_untracked_problems"("business_id_input" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_untracked_problems_with_similarity"("business_id_input" "uuid", "page_number" integer, "page_size" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_untracked_problems_with_similarity"("business_id_input" "uuid", "page_number" integer, "page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_untracked_problems_with_similarity"("business_id_input" "uuid", "page_number" integer, "page_size" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_by_email"("email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_by_email"("email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_by_email"("email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_business_owner"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_business_owner"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_business_owner"() TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."http"("request" "public"."http_request") TO "postgres";
GRANT ALL ON FUNCTION "public"."http"("request" "public"."http_request") TO "anon";
GRANT ALL ON FUNCTION "public"."http"("request" "public"."http_request") TO "authenticated";
GRANT ALL ON FUNCTION "public"."http"("request" "public"."http_request") TO "service_role";



GRANT ALL ON FUNCTION "public"."http_delete"("uri" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_delete"("uri" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_delete"("uri" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_delete"("uri" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."http_delete"("uri" character varying, "content" character varying, "content_type" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_delete"("uri" character varying, "content" character varying, "content_type" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_delete"("uri" character varying, "content" character varying, "content_type" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_delete"("uri" character varying, "content" character varying, "content_type" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."http_get"("uri" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_get"("uri" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_get"("uri" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_get"("uri" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."http_get"("uri" character varying, "data" "jsonb") TO "postgres";
GRANT ALL ON FUNCTION "public"."http_get"("uri" character varying, "data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."http_get"("uri" character varying, "data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_get"("uri" character varying, "data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."http_head"("uri" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_head"("uri" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_head"("uri" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_head"("uri" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."http_header"("field" character varying, "value" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_header"("field" character varying, "value" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_header"("field" character varying, "value" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_header"("field" character varying, "value" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."http_list_curlopt"() TO "postgres";
GRANT ALL ON FUNCTION "public"."http_list_curlopt"() TO "anon";
GRANT ALL ON FUNCTION "public"."http_list_curlopt"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_list_curlopt"() TO "service_role";



GRANT ALL ON FUNCTION "public"."http_patch"("uri" character varying, "content" character varying, "content_type" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_patch"("uri" character varying, "content" character varying, "content_type" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_patch"("uri" character varying, "content" character varying, "content_type" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_patch"("uri" character varying, "content" character varying, "content_type" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."http_post"("uri" character varying, "data" "jsonb") TO "postgres";
GRANT ALL ON FUNCTION "public"."http_post"("uri" character varying, "data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."http_post"("uri" character varying, "data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_post"("uri" character varying, "data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."http_post"("uri" character varying, "content" character varying, "content_type" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_post"("uri" character varying, "content" character varying, "content_type" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_post"("uri" character varying, "content" character varying, "content_type" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_post"("uri" character varying, "content" character varying, "content_type" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."http_put"("uri" character varying, "content" character varying, "content_type" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_put"("uri" character varying, "content" character varying, "content_type" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_put"("uri" character varying, "content" character varying, "content_type" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_put"("uri" character varying, "content" character varying, "content_type" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."http_reset_curlopt"() TO "postgres";
GRANT ALL ON FUNCTION "public"."http_reset_curlopt"() TO "anon";
GRANT ALL ON FUNCTION "public"."http_reset_curlopt"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_reset_curlopt"() TO "service_role";



GRANT ALL ON FUNCTION "public"."http_set_curlopt"("curlopt" character varying, "value" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."http_set_curlopt"("curlopt" character varying, "value" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."http_set_curlopt"("curlopt" character varying, "value" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."http_set_curlopt"("curlopt" character varying, "value" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."run_daily_research"() TO "anon";
GRANT ALL ON FUNCTION "public"."run_daily_research"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."run_daily_research"() TO "service_role";



GRANT ALL ON FUNCTION "public"."search_problems"("search_query" "text", "business_id_input" "uuid", "page_size_input" integer, "page_number_input" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_problems"("search_query" "text", "business_id_input" "uuid", "page_size_input" integer, "page_number_input" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_problems"("search_query" "text", "business_id_input" "uuid", "page_size_input" integer, "page_number_input" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."urlencode"("string" "bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."urlencode"("string" "bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."urlencode"("string" "bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."urlencode"("string" "bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."urlencode"("data" "jsonb") TO "postgres";
GRANT ALL ON FUNCTION "public"."urlencode"("data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."urlencode"("data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."urlencode"("data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."urlencode"("string" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."urlencode"("string" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."urlencode"("string" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."urlencode"("string" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_days_of_week"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_days_of_week"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_days_of_week"() TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."website_scan_report_problem_rankings"("input_business_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."website_scan_report_problem_rankings"("input_business_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."website_scan_report_problem_rankings"("input_business_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "service_role";



























GRANT ALL ON TABLE "public"."ai_models" TO "anon";
GRANT ALL ON TABLE "public"."ai_models" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_models" TO "service_role";



GRANT ALL ON TABLE "public"."ai_queries" TO "anon";
GRANT ALL ON TABLE "public"."ai_queries" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_queries" TO "service_role";



GRANT ALL ON TABLE "public"."ai_query_runs" TO "anon";
GRANT ALL ON TABLE "public"."ai_query_runs" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_query_runs" TO "service_role";



GRANT ALL ON TABLE "public"."ai_rank_query_results" TO "anon";
GRANT ALL ON TABLE "public"."ai_rank_query_results" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_rank_query_results" TO "service_role";



GRANT ALL ON TABLE "public"."ai_reputation_query_results" TO "anon";
GRANT ALL ON TABLE "public"."ai_reputation_query_results" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_reputation_query_results" TO "service_role";



GRANT ALL ON TABLE "public"."aio_report_email_recipients" TO "anon";
GRANT ALL ON TABLE "public"."aio_report_email_recipients" TO "authenticated";
GRANT ALL ON TABLE "public"."aio_report_email_recipients" TO "service_role";



GRANT ALL ON TABLE "public"."business_data" TO "anon";
GRANT ALL ON TABLE "public"."business_data" TO "authenticated";
GRANT ALL ON TABLE "public"."business_data" TO "service_role";



GRANT ALL ON TABLE "public"."business_problems" TO "anon";
GRANT ALL ON TABLE "public"."business_problems" TO "authenticated";
GRANT ALL ON TABLE "public"."business_problems" TO "service_role";



GRANT ALL ON TABLE "public"."businesses" TO "anon";
GRANT ALL ON TABLE "public"."businesses" TO "authenticated";
GRANT ALL ON TABLE "public"."businesses" TO "service_role";



GRANT ALL ON TABLE "public"."debug_logs" TO "anon";
GRANT ALL ON TABLE "public"."debug_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."debug_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."debug_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."debug_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."debug_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."page_business_data" TO "anon";
GRANT ALL ON TABLE "public"."page_business_data" TO "authenticated";
GRANT ALL ON TABLE "public"."page_business_data" TO "service_role";



GRANT ALL ON TABLE "public"."page_problem" TO "anon";
GRANT ALL ON TABLE "public"."page_problem" TO "authenticated";
GRANT ALL ON TABLE "public"."page_problem" TO "service_role";



GRANT ALL ON TABLE "public"."pages" TO "anon";
GRANT ALL ON TABLE "public"."pages" TO "authenticated";
GRANT ALL ON TABLE "public"."pages" TO "service_role";



GRANT ALL ON TABLE "public"."plan_models" TO "anon";
GRANT ALL ON TABLE "public"."plan_models" TO "authenticated";
GRANT ALL ON TABLE "public"."plan_models" TO "service_role";



GRANT ALL ON TABLE "public"."plan_prices" TO "anon";
GRANT ALL ON TABLE "public"."plan_prices" TO "authenticated";
GRANT ALL ON TABLE "public"."plan_prices" TO "service_role";



GRANT ALL ON TABLE "public"."plans" TO "anon";
GRANT ALL ON TABLE "public"."plans" TO "authenticated";
GRANT ALL ON TABLE "public"."plans" TO "service_role";



GRANT ALL ON TABLE "public"."problems" TO "anon";
GRANT ALL ON TABLE "public"."problems" TO "authenticated";
GRANT ALL ON TABLE "public"."problems" TO "service_role";



GRANT ALL ON TABLE "public"."subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."tracked_pages" TO "anon";
GRANT ALL ON TABLE "public"."tracked_pages" TO "authenticated";
GRANT ALL ON TABLE "public"."tracked_pages" TO "service_role";



GRANT ALL ON TABLE "public"."tracked_pages_scraping_results" TO "anon";
GRANT ALL ON TABLE "public"."tracked_pages_scraping_results" TO "authenticated";
GRANT ALL ON TABLE "public"."tracked_pages_scraping_results" TO "service_role";



GRANT ALL ON TABLE "public"."tracked_pages_scraping_runs" TO "anon";
GRANT ALL ON TABLE "public"."tracked_pages_scraping_runs" TO "authenticated";
GRANT ALL ON TABLE "public"."tracked_pages_scraping_runs" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."vectle_profiles" TO "anon";
GRANT ALL ON TABLE "public"."vectle_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."vectle_profiles" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
