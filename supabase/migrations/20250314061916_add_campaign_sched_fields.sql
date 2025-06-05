alter table "public"."campaigns" drop column "schedule";

alter table "public"."campaigns" add column "day_of_week" smallint not null;

alter table "public"."campaigns" add column "end_date" timestamp with time zone;

alter table "public"."campaigns" add column "start_date" timestamp with time zone not null;

alter table "public"."campaigns" add column "time_of_day" text not null;

alter table "public"."campaigns" alter column "count" set not null;


