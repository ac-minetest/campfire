-- idea: cant stay away from your active fire too long or die, fuel cost increases with distance from spawn

local campfire = {};
campfire.radius = 10;
campfire.timestep = 5;
campfire.damage = 5;
campfire.timeout = 10; -- how long can you stay outside fire area before you start loosing hp
campfire.cost  = 2/100; -- cost of making new fire active, per 1 block distance from spawn
campfire.count = {}; -- how many fires have you placed already
campfire.fire_pos = {};
campfire.fire_timer = {};
local spawn_pos = (minetest.setting_get_pos("static_spawnpoint") or {x = 0, y = 2, z = 0})

local time = 0;

minetest.register_node("campfire:fire_active", {
	description = "camp fire",
	drawtype = "plantlike",
	--drawtype = "nodebox",
	tiles = {"campfire.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {cracky = 3},
	is_ground_content = false,
	paramtype = "light",
	light_source = 10,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5 ,-0.5, -0.5, 0.5, 0.5, 0.5},
		}
	},
	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos);
		if meta:get_string("owner")~="ADMIN" and not( minetest.is_protected(pos,player:get_player_name()) ) then
			minetest.set_node(pos,{name = "air"});
		end
		return false
	end,
	
	after_place_node = function(pos, placer) 
		minetest.set_node(pos,{name = "air"});
	end
});

minetest.register_node("campfire:fire", {
	description = "camp fire",
	drawtype = "plantlike",
	--drawtype = "nodebox",
	tiles = {"campfire_off.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {cracky = 3},
	is_ground_content = false,
	paramtype = "light",
	light_source = 0,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5 ,-0.5, -0.5, 0.5, 0.5, 0.5},
		}
	},

	after_place_node = function(pos, placer) 
		local name = placer:get_player_name(); if not name then return end
		if not campfire.fire_pos[name] then campfire.fire_pos[name] = {} end
		
		local meta = minetest.get_meta(pos);
		meta:set_int("active",0);	meta:set_string("owner",name);
		local cost = 0;
		local count = campfire.count[name] or 0;
	
		-- check if fire can be activated (is it close enough to previous fire)
		local p = minetest.find_node_near(pos, campfire.radius, "campfire:fire_active");
		local fire = false;
		if p then 
			local pmeta = minetest.get_meta(p); local owner = pmeta:get_string("owner");
			
				fire = true;
				--count = math.max(pmeta:get_int("count"), count);
				meta:set_int("ignitable",1); -- new fire can be ignited with fuel
				--meta:set_int("count",count);
				--campfire.count[name] = count;
				cost = math.sqrt(math.pow(spawn_pos.x-pos.x,2)+math.pow(spawn_pos.y-pos.y,2)+math.pow(spawn_pos.z-pos.z,2));
				cost = campfire.cost*cost; cost = math.ceil(cost); -- cost depends on distance from spawn?
				meta:set_int("cost",cost);
				meta:set_string("infotext","inactive campfire ( owned by ".. name .."), please punch it to place some fuel in ( needs " .. cost ..")");
			
		end

		if not fire then 
			meta:set_string("infotext","inactive campfire ( owned by ".. name .."), place it closer (".. campfire.radius .. " blocks ) to existing active campfire owned by you or ADMIN. ");
		end
		
	end,
	
	on_punch = function(pos, node, puncher, pointed_thing)
		local name = puncher:get_player_name(); if not name then return end
		local meta = minetest.get_meta(pos);
		local cost = meta:get_int("cost");
		if meta:get_int("ignitable")~=1 and not minetest.check_player_privs(name, {privs = true}) then return end
		
			local inv = puncher:get_inventory();
			if not inv:contains_item("main", ItemStack("default:tree "..cost)) then 
			minetest.chat_send_player(name,"campfire: you need at least " .. cost .. " tree to make campfire active. ");
			return 
		end
		
		inv:remove_item("main", ItemStack("default:tree "..cost));

		minetest.set_node(pos,{name = "campfire:fire_active"});
		meta = minetest.get_meta(pos);
		if minetest.check_player_privs(name, {privs = true}) then 
			meta:set_string("owner","ADMIN") 
		else
			meta:set_string("owner",name) 
		end
		meta:set_string("infotext","active fire ( owned by ".. meta:get_string("owner") ..")"); 
		
		
	end,
		
	can_dig = function(pos, player)
		local candig = true
		--minetest.check_player_privs(player:get_player_name(), {privs = true}) or (player:get_player_name()==meta:get_string("owner"));
		minetest.set_node(pos,{name = "air"});
		return true
	end
});

minetest.register_craft({
	output = "campfire:fire",
	recipe = {
		{"default:cobble","","default:cobble"}
	}
})

minetest.register_on_dieplayer(function(player)
	local name = player:get_player_name() or "";
	campfire.fire_timer[name] = minetest.get_gametime()+60; 
	local pos = player:getpos();
	campfire.fire_pos[name] =  pos;
	minetest.chat_send_player(name,"You have one minute to get near active campfire owned by you or ADMIN or return to your bones ( " .. pos.x .. " " .. pos.y .. " " .. pos.z .. " ).")
end
)

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name() or "";
	if not campfire.fire_pos[name] then campfire.fire_pos[name] = player:getpos(); end
	if not campfire.fire_timer[name] then 
		campfire.fire_timer[name] = minetest.get_gametime()+60;
		minetest.chat_send_player(name,"You have one minute to get near active campfire owned by you or ADMIN.")
	end
	if not campfire.count[name] then campfire.count[name] = 0 end
	
	player:set_physics_override({speed = 0.75})
end
)


minetest.register_globalstep(function(dtime)
	time = time + dtime
	if time < campfire.timestep then return end
	time = 0;

	local t1,t2,player;
	t2 = minetest.get_gametime(); 
	
	for _,player in ipairs(minetest.get_connected_players()) do 
        local p = player:getpos()
        local name = player:get_player_name();
		
		t1 = campfire.fire_timer[name];
		t1 = t2 - t1;
		
		if t1>campfire.timeout then -- check if player near campfire or safe point ( fire owned by ADMIN)
			
			local fire = false;
			local pf = campfire.fire_pos[name];
			-- wandered away from previous campfire, look for new campfire
			local dist  = math.max(math.abs(pf.x-p.x),math.abs(pf.y-p.y),math.abs(pf.z-p.z))
			if dist>campfire.radius then 
				--campfire.radius = 10;
				local pos = minetest.find_node_near(p, campfire.radius, "campfire:fire_active");
				if pos then 
					local meta = minetest.get_meta(pos); local owner = meta:get_string("owner"); 
					if owner == name or owner == "ADMIN" then 
						fire = true 
						campfire.fire_pos[name] = pos; -- set newly found campfire as new campfire position
					end
				end
			else
				fire = true
			end
			
			if not fire then
				if player:get_hp()>0 then
					minetest.chat_send_player(name,"You need to get close (" .. campfire.radius .." blocks) to active campfire you own to stop taking damage ");
					player:set_hp(player:get_hp() - campfire.damage)
				end
			else 
				campfire.fire_timer[name] = t2;
			end
		end
		
	end
end
)
