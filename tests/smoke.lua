local frames = 0
local initialized = false

function et_InitGame(levelTime, randomSeed, restart)
    et.RegisterModname("ETLab smoke test")
    assert(et.trap_Cvar_Get("mapname") == "oasis", "Expected oasis")
    assert(et.trap_Cvar_Get("fs_game") == "etbudget", "Expected etbudget")
    initialized = true
    et.G_Print("ETLAB_SMOKE_INIT_OK\n")
end

function et_RunFrame(levelTime)
    if not initialized then return end
    frames = frames + 1
    if frames == 20 then
        et.G_Print("ETLAB_SMOKE_FRAMES_OK\n")
    end
end
