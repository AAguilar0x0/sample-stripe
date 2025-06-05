alter table "public"."pages" alter column "state" drop default;

alter table "public"."vectle_profiles" alter column "state" drop default;

alter type "public"."page_state" rename to "page_state__old_version_to_be_dropped";

create type "public"."page_state" as enum ('published', 'unpublished', 'draft', 'scheduled');

alter table "public"."pages" alter column state type "public"."page_state" using state::text::"public"."page_state";

alter table "public"."vectle_profiles" alter column state type "public"."page_state" using state::text::"public"."page_state";

alter table "public"."pages" alter column "state" set default 'draft'::page_state;

alter table "public"."vectle_profiles" alter column "state" set default 'published'::page_state;

drop type "public"."page_state__old_version_to_be_dropped";


