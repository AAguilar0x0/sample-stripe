alter table "public"."campaigns" add column "count" numeric;

alter table "public"."campaigns" add column "published_at" timestamp with time zone;

alter table "public"."campaigns" add column "schedule" timestamp with time zone;


