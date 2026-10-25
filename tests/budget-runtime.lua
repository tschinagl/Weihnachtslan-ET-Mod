-- Real Windows client: budget validation, spawn latching, inventory and input.
local now, resumeAt, job, done = 0, 0, nil, false
local fired = {}
local function get(field) return et.gentity_get(0, field) end
local function stat(index) return et.gentity_get(0, "ps.stats", index) end
local function cmd(text) et.trap_SendConsoleCommand(et.EXEC_APPEND, text .. "\n") end
local function wait(ms) resumeAt = now + ms; coroutine.yield() end
local function check(value, message)
    assert(value, message)
    et.G_Print("ETBUDGET_CHECK: " .. message .. "\n")
end
function et_WeaponFire(client, weapon)
    if client == 0 then fired[weapon] = (fired[weapon] or 0) + 1 end
end
local function entityWithWeapon(weapon)
    for id = 64, 1021 do
        if et.gentity_get(id, "inuse") == 1 and (et.gentity_get(id, "s.weapon") == weapon or (weapon == et.WP_MEDKIT and et.gentity_get(id, "classname") == "item_health")) then return id end
    end
end
local function run()
    check(et.trap_Cvar_Get("fs_game") == "etbudget", "independent mod loaded")
    check(get("sess.playerType") == et.PC_CUSTOM, "sixth class spawned")
    check(stat(et.STAT_CUSTOM_LOADOUT) == 19, "purchased abilities synchronized to client")
    cmd("openlimbomenu")
    wait(1300)
    cmd("screenshotJPEG etbudget-limbo")
    wait(500)
    cmd("openlimbomenu\nweaponbank 6")
    wait(900)
    check(get("ps.weapon") == et.WP_MEDKIT, "purchased medkit selectable")
    cmd("+attack")
    wait(300)
    cmd("-attack")
    wait(500)
    check((fired[et.WP_MEDKIT] or 0) > 0, "Custom throws a real Medic pack")
    check(entityWithWeapon(et.WP_MEDKIT) ~= nil, "Medic pack exists in world")
    cmd("weaponbank 5")
    wait(900)
    check(get("ps.weapon") == et.WP_MEDIC_SYRINGE, "purchased syringe selectable")
    cmd("weaponbank 3\nwait 60\nweaponbank 3")
    wait(2200)
    check(get("ps.weapon") == et.WP_K43, "additional sniper selectable beside SMG")
    cmd("team r 5 0 0 255")
    wait(1200)
    check(get("sess.customLoadout") == 19, "server rejects over-budget command")
    cmd("team r 5 0 0 256")
    wait(1200)
    check(get("sess.customLoadout") == 19, "server rejects unknown capability bit")
    cmd("team r 5 0 0 -1")
    wait(1200)
    check(get("sess.customLoadout") == 19, "server rejects negative command")
    cmd("team r 5 0 0 9")
    wait(1200)
    check(get("sess.customLoadout") == 9, "server accepts valid pending selection")
    check(stat(et.STAT_CUSTOM_LOADOUT) == 19, "selection does not change current life")
    cmd("rs")
    wait(1200)
    check(get("sess.customLoadout") == 19, "cancel restores active loadout")
    cmd("team b 5 0 0 9")
    wait(4500)
    check(get("sess.sessionTeam") == 2 and get("health") > 0, "Custom spawns on other team")
    check(stat(et.STAT_CUSTOM_LOADOUT) == 9, "next spawn activates new selection")
    check(et.gentity_get(0, "ps.ammoclip", et.WP_MEDIC_SYRINGE) == 0, "deselected syringe removed")
    cmd("weaponbank 7")
    wait(900)
    check(get("ps.weapon") == et.WP_LANDMINE, "purchased landmine selectable")
    cmd("+attack")
    wait(300)
    cmd("-attack")
    wait(900)
    check(entityWithWeapon(et.WP_LANDMINE) ~= nil, "Custom places a real landmine")
    cmd("weaponbank 5")
    wait(900)
    check(get("ps.weapon") == et.WP_PLIERS, "Engineer package includes working weapon selection for pliers")
    cmd("screenshotJPEG etbudget-engineer")
    wait(500)
    et.G_Print("ETBUDGET_RUNTIME_PASS\n")
    done = true
    cmd("quit")
end
function et_InitGame() et.RegisterModname("ETBudget runtime test") end
function et_RunFrame(time)
    now = time
    if done then return end
    if not job then
        if now < 12000 or get("health") <= 0 or get("sess.playerType") ~= et.PC_CUSTOM then return end
        job = coroutine.create(run)
    end
    if now < resumeAt then return end
    local ok, err = coroutine.resume(job)
    if not ok then
        done = true
        et.G_Print("ETBUDGET_RUNTIME_FAIL: " .. tostring(err) .. "\n")
        cmd("-attack\nscreenshotJPEG etbudget-failure\nwait 10\nquit")
    end
end
