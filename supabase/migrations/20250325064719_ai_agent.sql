create table "public"."checkpoint_blobs" (
    "thread_id" text not null,
    "checkpoint_ns" text not null default ''::text,
    "channel" text not null,
    "version" text not null,
    "type" text not null,
    "blob" bytea
);


create table "public"."checkpoint_migrations" (
    "v" integer not null
);


create table "public"."checkpoint_writes" (
    "thread_id" text not null,
    "checkpoint_ns" text not null default ''::text,
    "checkpoint_id" text not null,
    "task_id" text not null,
    "idx" integer not null,
    "channel" text not null,
    "type" text,
    "blob" bytea not null
);


create table "public"."checkpoints" (
    "thread_id" text not null,
    "checkpoint_ns" text not null default ''::text,
    "checkpoint_id" text not null,
    "parent_checkpoint_id" text,
    "type" text,
    "checkpoint" jsonb not null,
    "metadata" jsonb not null default '{}'::jsonb
);


CREATE UNIQUE INDEX checkpoint_blobs_pkey ON public.checkpoint_blobs USING btree (thread_id, checkpoint_ns, channel, version);

CREATE UNIQUE INDEX checkpoint_migrations_pkey ON public.checkpoint_migrations USING btree (v);

CREATE UNIQUE INDEX checkpoint_writes_pkey ON public.checkpoint_writes USING btree (thread_id, checkpoint_ns, checkpoint_id, task_id, idx);

CREATE UNIQUE INDEX checkpoints_pkey ON public.checkpoints USING btree (thread_id, checkpoint_ns, checkpoint_id);

alter table "public"."checkpoint_blobs" add constraint "checkpoint_blobs_pkey" PRIMARY KEY using index "checkpoint_blobs_pkey";

alter table "public"."checkpoint_migrations" add constraint "checkpoint_migrations_pkey" PRIMARY KEY using index "checkpoint_migrations_pkey";

alter table "public"."checkpoint_writes" add constraint "checkpoint_writes_pkey" PRIMARY KEY using index "checkpoint_writes_pkey";

alter table "public"."checkpoints" add constraint "checkpoints_pkey" PRIMARY KEY using index "checkpoints_pkey";

grant delete on table "public"."checkpoint_blobs" to "anon";

grant insert on table "public"."checkpoint_blobs" to "anon";

grant references on table "public"."checkpoint_blobs" to "anon";

grant select on table "public"."checkpoint_blobs" to "anon";

grant trigger on table "public"."checkpoint_blobs" to "anon";

grant truncate on table "public"."checkpoint_blobs" to "anon";

grant update on table "public"."checkpoint_blobs" to "anon";

grant delete on table "public"."checkpoint_blobs" to "authenticated";

grant insert on table "public"."checkpoint_blobs" to "authenticated";

grant references on table "public"."checkpoint_blobs" to "authenticated";

grant select on table "public"."checkpoint_blobs" to "authenticated";

grant trigger on table "public"."checkpoint_blobs" to "authenticated";

grant truncate on table "public"."checkpoint_blobs" to "authenticated";

grant update on table "public"."checkpoint_blobs" to "authenticated";

grant delete on table "public"."checkpoint_blobs" to "service_role";

grant insert on table "public"."checkpoint_blobs" to "service_role";

grant references on table "public"."checkpoint_blobs" to "service_role";

grant select on table "public"."checkpoint_blobs" to "service_role";

grant trigger on table "public"."checkpoint_blobs" to "service_role";

grant truncate on table "public"."checkpoint_blobs" to "service_role";

grant update on table "public"."checkpoint_blobs" to "service_role";

grant delete on table "public"."checkpoint_migrations" to "anon";

grant insert on table "public"."checkpoint_migrations" to "anon";

grant references on table "public"."checkpoint_migrations" to "anon";

grant select on table "public"."checkpoint_migrations" to "anon";

grant trigger on table "public"."checkpoint_migrations" to "anon";

grant truncate on table "public"."checkpoint_migrations" to "anon";

grant update on table "public"."checkpoint_migrations" to "anon";

grant delete on table "public"."checkpoint_migrations" to "authenticated";

grant insert on table "public"."checkpoint_migrations" to "authenticated";

grant references on table "public"."checkpoint_migrations" to "authenticated";

grant select on table "public"."checkpoint_migrations" to "authenticated";

grant trigger on table "public"."checkpoint_migrations" to "authenticated";

grant truncate on table "public"."checkpoint_migrations" to "authenticated";

grant update on table "public"."checkpoint_migrations" to "authenticated";

grant delete on table "public"."checkpoint_migrations" to "service_role";

grant insert on table "public"."checkpoint_migrations" to "service_role";

grant references on table "public"."checkpoint_migrations" to "service_role";

grant select on table "public"."checkpoint_migrations" to "service_role";

grant trigger on table "public"."checkpoint_migrations" to "service_role";

grant truncate on table "public"."checkpoint_migrations" to "service_role";

grant update on table "public"."checkpoint_migrations" to "service_role";

grant delete on table "public"."checkpoint_writes" to "anon";

grant insert on table "public"."checkpoint_writes" to "anon";

grant references on table "public"."checkpoint_writes" to "anon";

grant select on table "public"."checkpoint_writes" to "anon";

grant trigger on table "public"."checkpoint_writes" to "anon";

grant truncate on table "public"."checkpoint_writes" to "anon";

grant update on table "public"."checkpoint_writes" to "anon";

grant delete on table "public"."checkpoint_writes" to "authenticated";

grant insert on table "public"."checkpoint_writes" to "authenticated";

grant references on table "public"."checkpoint_writes" to "authenticated";

grant select on table "public"."checkpoint_writes" to "authenticated";

grant trigger on table "public"."checkpoint_writes" to "authenticated";

grant truncate on table "public"."checkpoint_writes" to "authenticated";

grant update on table "public"."checkpoint_writes" to "authenticated";

grant delete on table "public"."checkpoint_writes" to "service_role";

grant insert on table "public"."checkpoint_writes" to "service_role";

grant references on table "public"."checkpoint_writes" to "service_role";

grant select on table "public"."checkpoint_writes" to "service_role";

grant trigger on table "public"."checkpoint_writes" to "service_role";

grant truncate on table "public"."checkpoint_writes" to "service_role";

grant update on table "public"."checkpoint_writes" to "service_role";

grant delete on table "public"."checkpoints" to "anon";

grant insert on table "public"."checkpoints" to "anon";

grant references on table "public"."checkpoints" to "anon";

grant select on table "public"."checkpoints" to "anon";

grant trigger on table "public"."checkpoints" to "anon";

grant truncate on table "public"."checkpoints" to "anon";

grant update on table "public"."checkpoints" to "anon";

grant delete on table "public"."checkpoints" to "authenticated";

grant insert on table "public"."checkpoints" to "authenticated";

grant references on table "public"."checkpoints" to "authenticated";

grant select on table "public"."checkpoints" to "authenticated";

grant trigger on table "public"."checkpoints" to "authenticated";

grant truncate on table "public"."checkpoints" to "authenticated";

grant update on table "public"."checkpoints" to "authenticated";

grant delete on table "public"."checkpoints" to "service_role";

grant insert on table "public"."checkpoints" to "service_role";

grant references on table "public"."checkpoints" to "service_role";

grant select on table "public"."checkpoints" to "service_role";

grant trigger on table "public"."checkpoints" to "service_role";

grant truncate on table "public"."checkpoints" to "service_role";

grant update on table "public"."checkpoints" to "service_role";


