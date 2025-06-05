revoke delete on table "public"."campaign_business_datas" from "anon";

revoke insert on table "public"."campaign_business_datas" from "anon";

revoke references on table "public"."campaign_business_datas" from "anon";

revoke select on table "public"."campaign_business_datas" from "anon";

revoke trigger on table "public"."campaign_business_datas" from "anon";

revoke truncate on table "public"."campaign_business_datas" from "anon";

revoke update on table "public"."campaign_business_datas" from "anon";

revoke delete on table "public"."campaign_business_datas" from "authenticated";

revoke insert on table "public"."campaign_business_datas" from "authenticated";

revoke references on table "public"."campaign_business_datas" from "authenticated";

revoke select on table "public"."campaign_business_datas" from "authenticated";

revoke trigger on table "public"."campaign_business_datas" from "authenticated";

revoke truncate on table "public"."campaign_business_datas" from "authenticated";

revoke update on table "public"."campaign_business_datas" from "authenticated";

revoke delete on table "public"."campaign_business_datas" from "service_role";

revoke insert on table "public"."campaign_business_datas" from "service_role";

revoke references on table "public"."campaign_business_datas" from "service_role";

revoke select on table "public"."campaign_business_datas" from "service_role";

revoke trigger on table "public"."campaign_business_datas" from "service_role";

revoke truncate on table "public"."campaign_business_datas" from "service_role";

revoke update on table "public"."campaign_business_datas" from "service_role";

alter table "public"."campaign_business_datas" drop constraint "campaign_business_datas_business_data_id_fkey";

alter table "public"."campaign_business_datas" drop constraint "campaign_business_datas_campaign_id_fkey";

alter table "public"."campaign_business_datas" drop constraint "campaign_business_datas_pkey";

drop index if exists "public"."campaign_business_datas_pkey";

drop table "public"."campaign_business_datas";


