-- A player code brings tonight back too (Daniele 2026-11-21 "My friend send some i got none"). His phone was on a new
-- anonymous account (the old session was lost: a new browser storage, e.g. a QR scanned into another browser or an
-- in-app browser) while tonight's check-in at WestTable0 and the 7 verbs his friends sent stayed on the old account.
-- bc_profile_restore already moved the character and the pieces; it now also moves tonight's check-in and the
-- unread verbs, so typing the code (or the automatic restore when a save that knows its code meets a new account)
-- reunites the player with tonight. Needs 20261121000001 (checkins.left_at).

create or replace function public.bc_profile_restore(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); src public.profiles; code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  if (select count(*) from public.restore_attempts where player_id = uid and at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  insert into public.restore_attempts (player_id) values (uid);
  select * into src from public.profiles where restore_code = code;
  if not found then return jsonb_build_object('ok', false, 'reason', 'bad_code'); end if;
  if src.player_id = uid then return public.bc_profile_json(uid); end if;
  if src.banned then return jsonb_build_object('ok', false, 'reason', 'bad_code'); end if;
  insert into public.profiles (player_id) values (uid) on conflict do nothing;
  update public.profiles set restore_code = null where player_id = src.player_id;
  update public.profiles set display_name = src.display_name, avatar = src.avatar, personality = src.personality,
    character_created_at = coalesce(src.character_created_at, src.created_at), avatar_at = src.avatar_at,
    restore_code = code, restored_from = src.player_id, updated_at = now()
  where player_id = uid;
  insert into public.inventory (player_id, item_id, acquired_at, source, price_paid)
    select uid, item_id, acquired_at, source, price_paid from public.inventory where player_id = src.player_id
    on conflict do nothing;
  delete from public.inventory where player_id = src.player_id;
  -- Tonight follows the player (hotfix 4): the old account's check-in (when this one has none tonight) and the
  -- verbs waiting on it. The old account is out of tonight's list either way.
  if not exists (select 1 from public.checkins where player_id = uid and night = public.bc_night()) then
    update public.checkins set player_id = uid where player_id = src.player_id and night = public.bc_night();
  else
    update public.checkins set left_at = coalesce(left_at, now())
    where player_id = src.player_id and night = public.bc_night();
  end if;
  update public.events set to_id = uid where to_id = src.player_id and read_at is null and to_id <> uid;
  return public.bc_profile_json(uid);
end $$;

revoke execute on function public.bc_profile_restore(text) from public, anon;
grant execute on function public.bc_profile_restore(text) to authenticated;
