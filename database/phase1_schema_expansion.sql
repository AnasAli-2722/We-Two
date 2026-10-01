-- V1.1 Phase 1: Schema expansion
-- Adds message reply support and profile FCM token storage.

alter table public.messages
  add column if not exists reply_to_id uuid null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'messages_reply_to_id_fkey'
      and conrelid = 'public.messages'::regclass
  ) then
    alter table public.messages
      add constraint messages_reply_to_id_fkey
      foreign key (reply_to_id)
      references public.messages(id)
      on delete set null;
  end if;
end $$;

create index if not exists messages_reply_to_id_idx
  on public.messages (reply_to_id);

alter table public.profiles
  add column if not exists fcm_token text null;
