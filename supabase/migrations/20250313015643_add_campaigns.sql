create table "public"."campaign_business_datas" (
    "campaign_id" uuid not null,
    "business_data_id" uuid not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
);


alter table "public"."campaign_business_datas" enable row level security;

create table "public"."campaigns" (
    "id" uuid not null default gen_random_uuid(),
    "business_id" uuid not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "name" text not null default ''::text,
    "description" text not null default ''::text,
    "generation_prompt" text not null default ''::text
);


alter table "public"."campaigns" enable row level security;

CREATE UNIQUE INDEX campaign_business_datas_pkey ON public.campaign_business_datas USING btree (campaign_id, business_data_id);

CREATE UNIQUE INDEX campaigns_pkey ON public.campaigns USING btree (id);

alter table "public"."campaign_business_datas" add constraint "campaign_business_datas_pkey" PRIMARY KEY using index "campaign_business_datas_pkey";

alter table "public"."campaigns" add constraint "campaigns_pkey" PRIMARY KEY using index "campaigns_pkey";

alter table "public"."campaign_business_datas" add constraint "campaign_business_datas_business_data_id_fkey" FOREIGN KEY (business_data_id) REFERENCES business_data(business_data_id) ON DELETE CASCADE not valid;

alter table "public"."campaign_business_datas" validate constraint "campaign_business_datas_business_data_id_fkey";

alter table "public"."campaign_business_datas" add constraint "campaign_business_datas_campaign_id_fkey" FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE not valid;

alter table "public"."campaign_business_datas" validate constraint "campaign_business_datas_campaign_id_fkey";

alter table "public"."campaigns" add constraint "campaigns_business_id_fkey" FOREIGN KEY (business_id) REFERENCES businesses(business_id) ON DELETE CASCADE not valid;

alter table "public"."campaigns" validate constraint "campaigns_business_id_fkey";

grant delete on table "public"."campaign_business_datas" to "anon";

grant insert on table "public"."campaign_business_datas" to "anon";

grant references on table "public"."campaign_business_datas" to "anon";

grant select on table "public"."campaign_business_datas" to "anon";

grant trigger on table "public"."campaign_business_datas" to "anon";

grant truncate on table "public"."campaign_business_datas" to "anon";

grant update on table "public"."campaign_business_datas" to "anon";

grant delete on table "public"."campaign_business_datas" to "authenticated";

grant insert on table "public"."campaign_business_datas" to "authenticated";

grant references on table "public"."campaign_business_datas" to "authenticated";

grant select on table "public"."campaign_business_datas" to "authenticated";

grant trigger on table "public"."campaign_business_datas" to "authenticated";

grant truncate on table "public"."campaign_business_datas" to "authenticated";

grant update on table "public"."campaign_business_datas" to "authenticated";

grant delete on table "public"."campaign_business_datas" to "service_role";

grant insert on table "public"."campaign_business_datas" to "service_role";

grant references on table "public"."campaign_business_datas" to "service_role";

grant select on table "public"."campaign_business_datas" to "service_role";

grant trigger on table "public"."campaign_business_datas" to "service_role";

grant truncate on table "public"."campaign_business_datas" to "service_role";

grant update on table "public"."campaign_business_datas" to "service_role";

grant delete on table "public"."campaigns" to "anon";

grant insert on table "public"."campaigns" to "anon";

grant references on table "public"."campaigns" to "anon";

grant select on table "public"."campaigns" to "anon";

grant trigger on table "public"."campaigns" to "anon";

grant truncate on table "public"."campaigns" to "anon";

grant update on table "public"."campaigns" to "anon";

grant delete on table "public"."campaigns" to "authenticated";

grant insert on table "public"."campaigns" to "authenticated";

grant references on table "public"."campaigns" to "authenticated";

grant select on table "public"."campaigns" to "authenticated";

grant trigger on table "public"."campaigns" to "authenticated";

grant truncate on table "public"."campaigns" to "authenticated";

grant update on table "public"."campaigns" to "authenticated";

grant delete on table "public"."campaigns" to "service_role";

grant insert on table "public"."campaigns" to "service_role";

grant references on table "public"."campaigns" to "service_role";

grant select on table "public"."campaigns" to "service_role";

grant trigger on table "public"."campaigns" to "service_role";

grant truncate on table "public"."campaigns" to "service_role";

grant update on table "public"."campaigns" to "service_role";


