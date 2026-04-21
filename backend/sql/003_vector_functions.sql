-- Supabase SQL #3: pgvector retrieval function

create or replace function public.match_episodic_memories (
  p_user_id text,
  p_query_embedding vector(1536),
  p_match_count int default 5,
  p_min_similarity float default 0.60
)
returns table (
  id uuid,
  user_id text,
  summary text,
  tags text[],
  similarity float,
  created_at timestamptz
)
language sql
stable
as $$
  select
    m.id,
    m.user_id,
    m.summary,
    m.tags,
    1 - (m.embedding <=> p_query_embedding) as similarity,
    m.created_at
  from public.episodic_memories m
  where m.user_id = p_user_id
    and 1 - (m.embedding <=> p_query_embedding) >= p_min_similarity
  order by m.embedding <=> p_query_embedding
  limit p_match_count;
$$;
