-- LOCAL MARS: persist each member's last explorer position.
alter table public.mars_avatars
  add column if not exists world_x double precision not null default 0,
  add column if not exists world_z double precision not null default 0,
  add column if not exists world_yaw double precision not null default 0;

alter table public.mars_avatars
  drop constraint if exists mars_avatars_world_x_range,
  add constraint mars_avatars_world_x_range check (world_x between -80 and 80),
  drop constraint if exists mars_avatars_world_z_range,
  add constraint mars_avatars_world_z_range check (world_z between -80 and 80),
  drop constraint if exists mars_avatars_world_yaw_range,
  add constraint mars_avatars_world_yaw_range check (world_yaw between -6.284 and 6.284);

comment on column public.mars_avatars.world_x is 'Persistent LOCAL MARS simulated world X coordinate.';
comment on column public.mars_avatars.world_z is 'Persistent LOCAL MARS simulated world Z coordinate.';
comment on column public.mars_avatars.world_yaw is 'Persistent LOCAL MARS avatar facing direction in radians.';
