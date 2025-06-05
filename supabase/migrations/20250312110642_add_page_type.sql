alter table "public"."page_business_data" drop constraint "page_business_data_pkey";

drop index if exists "public"."page_business_data_pkey";

alter table "public"."page_business_data" drop column "id";

alter table "public"."page_business_data" alter column "business_data_id" drop default;

alter table "public"."page_business_data" alter column "page_id" drop default;

alter table "public"."pages" add column "page_type" text not null default 'catalog'::text;

CREATE UNIQUE INDEX page_business_data_pkey ON public.page_business_data USING btree (business_data_id, page_id);

alter table "public"."page_business_data" add constraint "page_business_data_pkey" PRIMARY KEY using index "page_business_data_pkey";


