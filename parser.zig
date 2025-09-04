const std = @import("std");
const json = std.json;
const ArrayList = std.array_list.Managed;
const Allocator = std.mem.Allocator;

const PropertyData = struct {
    property_id: u32,
    base: []const u8,
    level: ?u32 = null,
    add: ?u32 = null,
};

const MainPropertyData = struct {
    property_id: u32,
    base: []const u8,
    add: ?u32 = null,
};

const EquipmentData = struct {
    id: u32,
    level: u32,
    star: u32 = 5,
    equipment_type: u32,
    main_properties: []MainPropertyData,
    properties: []PropertyData,
};

const WeaponData = struct {
    id: u32,
    level: u32,
    star: u32 = 5,
    refine_level: u32,
};

const AvatarData = struct {
    id: u32,
    level: u32,
    rank: u32,
    weapon: ?WeaponData,
    equipment: []EquipmentData,
};

fn parsePercentageValue(value_str: []const u8) !f64 {
    if (value_str.len == 0) return 0.0;

    if (std.mem.endsWith(u8, value_str, "%")) {
        const num_str = value_str[0 .. value_str.len - 1];
        if (num_str.len == 0) return 0.0;
        const num = try std.fmt.parseFloat(f64, num_str);
        return num * 100;
    } else {
        return try std.fmt.parseFloat(f64, value_str);
    }
}

fn formatMainPropertyValue(base_str: []const u8, item_level: u32) !u32 {
    if (base_str.len == 0) return 0;

    const base_value = try parsePercentageValue(base_str);
    const divisor = @as(f64, @floatFromInt(item_level / 5 + 1));
    const result = @round(base_value / divisor);

    if (result < 0) return 0;
    if (result > @as(f64, @floatFromInt(std.math.maxInt(u32)))) return std.math.maxInt(u32);

    return @intFromFloat(result);
}

fn formatSubPropertyValue(base_str: []const u8, level: u32) !u32 {
    if (base_str.len == 0) return 0;

    const base_value = try parsePercentageValue(base_str);

    if (level == 0) {
        return @intFromFloat(@round(base_value));
    }

    const result = @round(base_value / @as(f64, @floatFromInt(level)));

    if (result < 0) return 0;
    if (result > @as(f64, @floatFromInt(std.math.maxInt(u32)))) {
        return std.math.maxInt(u32);
    }

    return @intFromFloat(result);
}

fn parseEquipment(allocator: Allocator, equip_array: json.Array) ![]EquipmentData {
    var equipment_list = ArrayList(EquipmentData).init(allocator);

    for (equip_array.items) |equip_item| {
        const equip_obj = equip_item.object;

        const id = @as(u32, @intCast(equip_obj.get("id").?.integer));
        const level = @as(u32, @intCast(equip_obj.get("level").?.integer));
        const equipment_type = @as(u32, @intCast(equip_obj.get("equipment_type").?.integer));

        var main_props_list = ArrayList(MainPropertyData).init(allocator);

        if (equip_obj.get("main_properties")) |main_props| {
            for (main_props.array.items) |prop_item| {
                const prop_obj = prop_item.object;
                const property_id = @as(u32, @intCast(prop_obj.get("property_id").?.integer));
                const base_value = prop_obj.get("base").?;
                const base_str = try allocator.dupe(u8, base_value.string);

                try main_props_list.append(MainPropertyData{
                    .property_id = property_id,
                    .base = base_str,
                    .add = 0,
                });
            }
        }

        var props_list = ArrayList(PropertyData).init(allocator);

        if (equip_obj.get("properties")) |props| {
            for (props.array.items) |prop_item| {
                const prop_obj = prop_item.object;
                const property_id = @as(u32, @intCast(prop_obj.get("property_id").?.integer));
                const base_value = prop_obj.get("base").?;
                const level_val = @as(u32, @intCast(prop_obj.get("level").?.integer));
                const add_val = @as(u32, @intCast(prop_obj.get("add").?.integer));
                const base_str = try allocator.dupe(u8, base_value.string);

                try props_list.append(PropertyData{
                    .property_id = property_id,
                    .base = base_str,
                    .level = level_val,
                    .add = add_val,
                });
            }
        }

        const main_props_slice = try main_props_list.toOwnedSlice();
        const props_slice = try props_list.toOwnedSlice();

        try equipment_list.append(EquipmentData{
            .id = id,
            .level = level,
            .equipment_type = equipment_type,
            .star = 0,
            .main_properties = main_props_slice,
            .properties = props_slice,
        });
    }

    return try equipment_list.toOwnedSlice();
}

fn calculateWeaponStar(level: u32) u32 {
    if (level <= 10) return 0;
    if (level <= 20) return 1;
    if (level <= 30) return 2;
    if (level <= 40) return 3;
    if (level <= 50) return 4;
    return 5;
}

fn parseWeapon(weapon_value: json.Value) ?WeaponData {
    if (weapon_value == .null) return null;

    const weapon_obj = weapon_value.object;
    const id = @as(u32, @intCast(weapon_obj.get("id").?.integer));
    const level = @as(u32, @intCast(weapon_obj.get("level").?.integer));
    const star_val = @as(u32, @intCast(weapon_obj.get("star").?.integer));

    return WeaponData{
        .id = id,
        .level = level,
        .star = calculateWeaponStar(level),
        .refine_level = star_val,
    };
}

fn writeGameplaySettings(writer: anytype, avatars: []AvatarData) !void {
    try writer.print(".{{\n", .{});
    try writer.print("    .hadal_entrance_list = .{{\n", .{});
    try writer.print("        .{{ .entrance_id = 2, .zone_id = 61001 }},\n", .{});
    try writer.print("        .{{ .entrance_id = 3, .zone_id = 61002 }},\n", .{});
    try writer.print("        .{{ .entrance_id = 1, .zone_id = 62027 }},\n", .{});
    try writer.print("        .{{ .entrance_id = 9, .zone_id = 69021 }},\n", .{});
    try writer.print("    }},\n\n", .{});

    try writer.print("    .avatar_overrides = .{{\n", .{});

    for (avatars) |avatar| {
        try writer.print("        .{{\n", .{});
        try writer.print("            .id = {},\n", .{avatar.id});
        try writer.print("            .level = {},\n", .{avatar.level});
        try writer.print("            .unlocked_talent_num = {},\n", .{avatar.rank});

        if (avatar.weapon) |weapon| {
            try writer.print("            .weapon = .{{\n", .{});
            try writer.print("                .id = {},\n", .{weapon.id});
            try writer.print("                .level = {},\n", .{weapon.level});
            try writer.print("                .star = {},\n", .{weapon.star});
            try writer.print("                .refine_level = {},\n", .{weapon.refine_level});
            try writer.print("            }},\n", .{});
        }

        if (avatar.equipment.len > 0) {
            try writer.print("            .equipment = .{{\n", .{});

            for (avatar.equipment) |equip| {
                const slot_index = equip.equipment_type - 1;
                try writer.print("                .{{\n", .{});
                try writer.print("                    {},\n", .{slot_index});
                try writer.print("                    .{{\n", .{});
                try writer.print("                        .id = {},\n", .{equip.id});
                try writer.print("                        .level = {},\n", .{equip.level});
                try writer.print("                        .star = {},\n", .{equip.star});

                try writer.print("                        .properties = .{{\n", .{});
                for (equip.main_properties) |main_prop| {
                    if (main_prop.base.len > 0) {
                        const formatted_value = formatMainPropertyValue(main_prop.base, equip.level) catch 0;
                        try writer.print("                            .{{ {}, {}, {} }},\n", .{ main_prop.property_id, formatted_value, main_prop.add orelse 0 });
                    }
                }
                try writer.print("                        }},\n", .{});

                try writer.print("                        .sub_properties = .{{\n", .{});
                for (equip.properties) |prop| {
                    if (prop.base.len > 0 and prop.level != null) {
                        const formatted_value = formatSubPropertyValue(prop.base, prop.level.?) catch 0;
                        try writer.print("                            .{{ {}, {}, {} }},\n", .{ prop.property_id, formatted_value, (prop.add orelse 0) + 1 });
                    }
                }
                try writer.print("                        }},\n", .{});

                try writer.print("                    }},\n", .{});
                try writer.print("                }},\n", .{});
            }
            try writer.print("            }},\n", .{});
        }

        try writer.print("        }},\n", .{});
    }

    try writer.print("    }},\n\n", .{});

    try writer.print("    .weapons = .{{}},\n", .{});
    try writer.print("    .equipment = .{{}},\n", .{});
    try writer.print("}}\n", .{});
}

pub fn parseHoyoLabJson(allocator: Allocator, json_content: []const u8) !void {
    var parsed = try json.parseFromSlice(json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    const data = root.get("data").?.object;
    const avatar_list = data.get("avatar_list").?.array;

    var avatars = ArrayList(AvatarData).init(allocator);
    defer {
        for (avatars.items) |avatar| {
            for (avatar.equipment) |equip| {
                for (equip.main_properties) |main_prop| {
                    allocator.free(main_prop.base);
                }
                for (equip.properties) |prop| {
                    allocator.free(prop.base);
                }
                allocator.free(equip.main_properties);
                allocator.free(equip.properties);
            }
            allocator.free(avatar.equipment);
        }
        avatars.deinit();
    }

    for (avatar_list.items) |avatar_item| {
        const avatar_obj = avatar_item.object;

        const id = @as(u32, @intCast(avatar_obj.get("id").?.integer));
        const level = @as(u32, @intCast(avatar_obj.get("level").?.integer));
        const rank = @as(u32, @intCast(avatar_obj.get("rank").?.integer));

        const weapon_data = if (avatar_obj.get("weapon")) |weapon_value|
            parseWeapon(weapon_value)
        else
            null;

        const equipment_data = if (avatar_obj.get("equip")) |equip_value|
            if (equip_value == .array and equip_value.array.items.len > 0)
                try parseEquipment(allocator, equip_value.array)
            else
                try allocator.alloc(EquipmentData, 0)
        else
            try allocator.alloc(EquipmentData, 0);

        try avatars.append(AvatarData{
            .id = id,
            .level = level,
            .rank = rank,
            .weapon = weapon_data,
            .equipment = equipment_data,
        });
    }

    const output_file = try std.fs.cwd().createFile("gameplay_settings.zon", .{ .truncate = true });
    defer output_file.close();

    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const writer = buffer.writer();
    try writeGameplaySettings(writer, avatars.items);

    try output_file.writeAll(buffer.items);
}

pub fn parseFromFile(allocator: Allocator, file_path: []const u8) !void {
    const input_file = try std.fs.cwd().openFile(file_path, .{});
    defer input_file.close();

    const file_size = try input_file.getEndPos();
    const contents = try allocator.alloc(u8, file_size);
    defer allocator.free(contents);

    _ = try input_file.readAll(contents);
    try parseHoyoLabJson(allocator, contents);
}

pub fn parseFromFolder(allocator: Allocator) !void {
    const folder_path = "hoyolab";

    var dir = std.fs.cwd().openDir(folder_path, .{ .iterate = true }) catch {
        std.debug.print("Folder '{s}' not found.\n", .{folder_path});
        return;
    };
    defer dir.close();

    var all_avatars = ArrayList(AvatarData).init(allocator);
    defer {
        for (all_avatars.items) |avatar| {
            for (avatar.equipment) |equip| {
                for (equip.main_properties) |main_prop| {
                    allocator.free(main_prop.base);
                }
                for (equip.properties) |prop| {
                    allocator.free(prop.base);
                }
                allocator.free(equip.main_properties);
                allocator.free(equip.properties);
            }
            allocator.free(avatar.equipment);
        }
        all_avatars.deinit();
    }

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) {
            const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ folder_path, entry.name });
            defer allocator.free(full_path);

            const input_file = std.fs.cwd().openFile(full_path, .{}) catch continue;
            defer input_file.close();

            const file_size = try input_file.getEndPos();
            const contents = try allocator.alloc(u8, file_size);
            defer allocator.free(contents);

            _ = try input_file.readAll(contents);

            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();

            var parsed = json.parseFromSlice(json.Value, arena_allocator, contents, .{}) catch continue;
            defer parsed.deinit();

            const root = parsed.value.object;
            const data = root.get("data").?.object;
            const avatar_list = data.get("avatar_list").?.array;

            for (avatar_list.items) |avatar_item| {
                const avatar_obj = avatar_item.object;

                const id = @as(u32, @intCast(avatar_obj.get("id").?.integer));
                const level = @as(u32, @intCast(avatar_obj.get("level").?.integer));
                const rank = @as(u32, @intCast(avatar_obj.get("rank").?.integer));

                const weapon_data = if (avatar_obj.get("weapon")) |weapon_value| parseWeapon(weapon_value) else null;

                const equipment_data = if (avatar_obj.get("equip")) |equip_value|
                    if (equip_value == .array and equip_value.array.items.len > 0)
                        try parseEquipment(allocator, equip_value.array)
                    else
                        try allocator.alloc(EquipmentData, 0)
                else
                    try allocator.alloc(EquipmentData, 0);

                try all_avatars.append(AvatarData{
                    .id = id,
                    .level = level,
                    .rank = rank,
                    .weapon = weapon_data,
                    .equipment = equipment_data,
                });
            }
        }
    }

    const output_file = try std.fs.cwd().createFile("gameplay_settings.zon", .{ .truncate = true });
    defer output_file.close();

    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const writer = buffer.writer();
    try writeGameplaySettings(writer, all_avatars.items);

    try output_file.writeAll(buffer.items);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1) {
        try parseFromFile(allocator, args[1]);
    } else {
        try parseFromFolder(allocator);
    }

    std.debug.print("Successfully generated gameplay_settings.zon\n", .{});
    std.Thread.sleep(5 * std.time.ns_per_s);
}
