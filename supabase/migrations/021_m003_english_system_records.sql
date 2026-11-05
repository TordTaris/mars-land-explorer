-- LOCAL MARS: convert all M-003 underground level records to English.
-- Safe to run after migration 008. Updates labels and descriptions only.
update public.m003_private_base as b
set room_name = v.room_name,
    description = v.description,
    updated_at = now()
from (values
(1,'MAIN CONTROL CENTER','Central monitoring and control of all underground facility operations.'),
(2,'COMMAND CENTER','Mission planning, operational coordination, and department management.'),
(3,'SECURITY SYSTEMS','Access control, perimeter sensors, surveillance, and restricted-zone monitoring.'),
(4,'COMMUNICATIONS CENTER','Internal communications network and external communication systems.'),
(5,'POWER MANAGEMENT CENTER','Primary power distribution and backup power coordination.'),
(6,'REACTOR AND POWER CONTROL','Simulated reactor operations and facility power-control systems.'),
(7,'ENERGY STORAGE SYSTEM','Battery arrays and emergency power storage and distribution.'),
(8,'WATER PRODUCTION SYSTEM','Water processing, purification, and internal recycling systems.'),
(9,'ATMOSPHERE AND OXYGEN SYSTEM','Air-quality monitoring and oxygen circulation management.'),
(10,'BOTANICAL GROWTH CHAMBER','Food production and controlled-environment agriculture research.'),
(11,'SUPPLY STORAGE','Storage inventory for food, consumables, and essential materials.'),
(12,'SCIENCE LABORATORY','Analysis of soil, rock, and simulated planetary resource samples.'),
(13,'MEDICAL CENTER','Medical support, health monitoring, and emergency care facilities.'),
(14,'RESIDENTIAL QUARTERS A','Accommodation area assigned to Operations Team A.'),
(15,'RESIDENTIAL QUARTERS B','Accommodation area assigned to Operations Team B.'),
(16,'MESS HALL','Dining, recreation, and personnel rest area.'),
(17,'MAINTENANCE WORKSHOP','Maintenance and repair of vehicles, robotics, and operational equipment.'),
(18,'SPARE PARTS STORAGE','Inventory of replacement components and backup equipment.'),
(19,'EXPLORATION VEHICLE HANGAR','Parking, inspection, and preparation of planetary exploration vehicles.'),
(20,'ROBOTICS CONTROL CENTER','Remote operation of exploration robots and automated systems.'),
(21,'RESOURCE STORAGE','Storage of mineral samples and construction materials.'),
(22,'SUBSURFACE RESEARCH CENTER','Geological and environmental research beneath the Martian surface.'),
(23,'EMERGENCY EVACUATION CENTER','Emergency assembly point and contingency support systems.'),
(24,'BACKUP COMMAND CENTER','Redundant command systems for operation during primary control outages.')
) as v(floor_no,room_name,description)
where b.floor_no = v.floor_no;
