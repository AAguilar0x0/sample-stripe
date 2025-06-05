alter type "public"."page_type" rename to "page_type__old_version_to_be_dropped";

create type "public"."page_type" as enum ('problem', 'solution');

alter table "public"."pages" alter column type type "public"."page_type" using type::text::"public"."page_type";

drop type "public"."page_type__old_version_to_be_dropped";


