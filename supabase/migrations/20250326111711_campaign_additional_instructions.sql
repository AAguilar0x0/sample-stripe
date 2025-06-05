alter table "public"."campaigns" rename column "description" to "additional_instruction";

alter table "public"."campaigns" drop column "generation_prompt";