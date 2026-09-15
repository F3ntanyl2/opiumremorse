-- Wind Sound System
-- Client-side wind sound effects based on player/ragdoll velocity
-- Adapted for remorseism-main: ragdoll combat uses FakeRagdoll velocity

if CLIENT then
    local windSound = nil
    local lastVelocity = 0
    local soundPlaying = false
    local fadingOut = false
    local fadeStartTime = 0
    local targetVolume = 0
    local currentVolume = 0

    local hg_windsounds = CreateClientConVar("hg_windsounds", "1", true, false, "Toggle wind sound effects when moving fast", 0, 1)

    -- Wind sound configuration
    local WIND_START_VELOCITY = 400
    local WIND_TRIGGER_VELOCITY = 445
    local WIND_PEAK_VELOCITY = 550
    local WIND_SOUND_PATH = "windloop.mp3"
    local FADE_OUT_TIME = 1.5

    local function GetPlayerVelocity(ply)
        if not IsValid(ply) then return 0 end

        if hg.RagdollCombatInUse and hg.RagdollCombatInUse(ply) then
            local ragdoll = ply.FakeRagdoll
            if IsValid(ragdoll) then
                return ragdoll:GetVelocity():Length()
            end
        end

        return ply:GetVelocity():Length()
    end

    local function CalculateWindVolume(velocity)
        if velocity < WIND_START_VELOCITY then
            return 0
        elseif velocity >= WIND_PEAK_VELOCITY then
            return 1.0
        else
            local progress = (velocity - WIND_START_VELOCITY) / (WIND_PEAK_VELOCITY - WIND_START_VELOCITY)
            return math.Clamp(progress, 0, 1)
        end
    end

    local function StartWindSound()
        if soundPlaying then return end

        windSound = CreateSound(LocalPlayer(), WIND_SOUND_PATH)
        if windSound then
            windSound:Play()
            soundPlaying = true
        end
    end

    local function StopWindSound()
        if not soundPlaying then return end

        if windSound then
            windSound:Stop()
            windSound = nil
        end
        soundPlaying = false
        fadingOut = false
        currentVolume = 0
        targetVolume = 0
    end

    local function StartFadeOut()
        if not soundPlaying or fadingOut then return end

        fadingOut = true
        fadeStartTime = CurTime()
        targetVolume = 0
    end

    local function UpdateWindSound(velocity)
        if not hg_windsounds:GetBool() then
            if soundPlaying then
                StopWindSound()
            end
            return
        end

        local volume = CalculateWindVolume(velocity)

        if velocity >= WIND_TRIGGER_VELOCITY and volume > 0 then
            if not soundPlaying then
                StartWindSound()
                fadingOut = false
            end

            if fadingOut then
                fadingOut = false
            end

            targetVolume = volume

            if windSound then
                windSound:ChangeVolume(volume, 0.1)
                currentVolume = volume
            end
        else
            if soundPlaying and not fadingOut then
                StartFadeOut()
            end
        end

        if fadingOut and soundPlaying then
            local fadeProgress = (CurTime() - fadeStartTime) / FADE_OUT_TIME

            if fadeProgress >= 1.0 then
                StopWindSound()
            else
                local fadeVolume = currentVolume * (1.0 - fadeProgress)
                if windSound then
                    windSound:ChangeVolume(fadeVolume, 0.05)
                end
            end
        end
    end

    hook.Add("Think", "HG_WindSound", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then
            if soundPlaying then
                StopWindSound()
            end
            return
        end

        local currentVelocity = GetPlayerVelocity(ply)

        if math.abs(currentVelocity - lastVelocity) > 5 then
            UpdateWindSound(currentVelocity)
            lastVelocity = currentVelocity
        end
    end)

    hook.Add("PlayerDeath", "HG_WindSound_Cleanup", function(victim)
        if victim == LocalPlayer() and soundPlaying then
            StopWindSound()
        end
    end)

    hook.Add("ShutDown", "HG_WindSound_Shutdown", function()
        if soundPlaying then
            StopWindSound()
        end
    end)
end