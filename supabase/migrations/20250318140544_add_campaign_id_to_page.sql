alter table "public"."pages" add column "campaign_id" uuid;

alter table "public"."pages" add constraint "pages_campaign_id_fkey" FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE SET NULL not valid;

alter table "public"."pages" validate constraint "pages_campaign_id_fkey";


