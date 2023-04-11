-- shared.lua

GM.Name = "Yu-Gi-Oh Gamemode"
GM.Author = "Your Name"

CARD_TYPE_MONSTER = 1
CARD_TYPE_SPELL = 2

local PLAYER = FindMetaTable("Player")


CardExamples = {
    {
        name = "Blue-Eyes White Dragon",
        cardType = CARD_TYPE_MONSTER,
        attack = 3000,
        defense = 2500,
        level = 8,
        imagePath = "blueeyeswhitedragon.jpg",
    },
    {
        name = "Dark Magician",
        cardType = CARD_TYPE_MONSTER,
        attack = 2500,
        defense = 2100,
        level = 7,
        imagePath = "darkmagician.jpg",
    },
    {
        name = "Monster Reborn",
        cardType = CARD_TYPE_SPELL,
        effect = function(player, target)
            -- Add logic to revive a monster from the graveyard
        end,
        imagePath = "monster_reborn.jpg",
    },
}

-- shared.lua

function GM:ShowHelp(ply)
    if SERVER then
        net.Start("OpenDeckCreationMenu")
        net.Send(ply)
    end
end

function DrawCard(ply)
    local duelData = ply:GetDuelData()

    if not duelData or not duelData.deck or #duelData.deck == 0 then
        print("DrawCard: Deck is empty or nil for player " .. ply:Nick())
        print("DuelData:")
        PrintTable(duelData)
        return
    end

    local cardID = table.remove(duelData.deck, 1)
    duelData.hand = duelData.hand or {}
    table.insert(duelData.hand, cardID)

    ply:SetDuelData(duelData)

    print("DrawCard: " .. cardID .. " drawn for player " .. ply:Nick())
end





-- shared.lua

function PerformTurn(player)
    print("Performing turn for " .. player:Nick())

    local card = DrawCard(player)

    if card then
        net.Start("UpdateCardPositions")
        net.WriteEntity(player)
        net.Broadcast()
    end

    local duelData = ply:GetNW2Var("DuelData")
    if not duelData then
        return
    end

    if DuelInProgress() then
        local cardID = DrawCard(ply)
        if cardID then
            net.Start("CardDrawn")
            net.WriteEntity(ply)
            net.WriteUInt(cardID, 32)
            net.Broadcast()
        end

        local nextPlayer = GetNextDuelPlayer(ply)
        if nextPlayer then
            timer.Simple(1, function()
                PerformTurn(nextPlayer)
            end)
        end
    end
end


function EndTurn(ply)
    -- Add logic for handling end-of-turn effects and other cleanup tasks

    -- Start the next player's turn
    timer.Simple(1, function() PerformTurn(ply) end)
end

-- shared.lua

function PlaceCardOnField(ply, cardIndex, fieldIndex, isDefence)
    local duelData = ply:GetNWTable("DuelData")
    local hand = duelData.hand
    local field = duelData.field

    local card = table.remove(hand, cardIndex)

    if card.cardType == CARD_TYPE_MONSTER then
        card.isDefence = isDefence
    end

    field[fieldIndex] = card

    ply:SetNWTable("DuelData", duelData)
end

-- shared.lua

function Attack(ply, attackerIndex, targetIndex)
    local attacker = ply:GetNWTable("DuelData").field[attackerIndex]
    local targetPly = GetOpponent(ply)
    local target = targetPly:GetNWTable("DuelData").field[targetIndex]

    if attacker.cardType ~= CARD_TYPE_MONSTER then
        ply:ChatPrint("Only monster cards can attack.")
        return
    end

    if not target then
        -- Direct attack
        local damage = attacker.attack
        ApplyDamage(targetPly, damage)
    elseif attacker.attack > target.defense then
        -- Destroy the target and apply damage
        local damage = attacker.attack - target.defense
        ApplyDamage(targetPly, damage)
        targetPly:GetNWTable("DuelData").field[targetIndex] = nil
    else
        -- Attacker is destroyed
        ply:GetNWTable("DuelData").field[attackerIndex] = nil
    end
end

function ApplyDamage(ply, damage)
    local duelData = ply:GetNWTable("DuelData")
    duelData.lifePoints = duelData.lifePoints - damage

    if duelData.lifePoints <= 0 then
        EndDuel(GetOpponent(ply))
    else
        ply:SetNWTable("DuelData", duelData)
    end
end

-- shared.lua

function EndDuel(winner)
    local loser = GetOpponent(winner)

    winner:ChatPrint("Congratulations, you have won the duel!")
    loser:ChatPrint("You have lost the duel.")

    -- Add logic to reset the game state and handle any post-duel tasks
end


-- shared.lua

function ActivateSpell(ply, cardIndex, targetIndex)
    local duelData = ply:GetNWTable("DuelData")
    local hand = duelData.hand
    local field = duelData.field

    local card = hand[cardIndex]

    if card.cardType ~= CARD_TYPE_SPELL then
        ply:ChatPrint("Only Spell cards can be activated.")
        return
    end

    local targetPly = ply
    if targetIndex then
        local targetCard = field[targetIndex]
        if not targetCard then
            targetPly = GetOpponent(ply)
            targetCard = targetPly:GetNWTable("DuelData").field[targetIndex]
        end

        if targetCard then
            card.effect(targetPly, targetCard)
        end
    else
        card.effect(targetPly)
    end

    table.remove(hand, cardIndex)
    ply:SetNWTable("DuelData", duelData)
end



-- shared.lua

function RenderHand(ply, hand)
    if not hand then return end

    local sw, sh = ScrW(), ScrH()
    local cardWidth, cardHeight = sw * 0.1, sh * 0.25
    local cardSpacing = cardWidth * 0.1
    local totalWidth = (#hand * cardWidth) + (#hand - 1) * cardSpacing
    local startX = (sw - totalWidth) / 2

    for i, card in ipairs(hand) do
        local x = startX + (i - 1) * (cardWidth + cardSpacing)
        local y = sh - cardHeight

        -- Assuming you have a GetCardTexture function to load the card image
        local cardTexture = GetCardTexture(card)
        surface.SetDrawColor(255, 255, 255)
        surface.SetTexture(cardTexture)
        surface.DrawTexturedRect(x, y, cardWidth, cardHeight)
    end
end

-- shared.lua

-- shared.lua

function GetCardTexture(card)
    -- Assuming you have a folder named "card_images" containing card images
    local cardImagePath = "card_images/" .. card.Name .. ".jpg"

    if file.Exists("materials/" .. cardImagePath, "GAME") then
        return Material(cardImagePath, "smooth")
    else
        -- If the card image is not found, display a default image
        return Material("card_images/default_card.jpg", "smooth")
    end
end


-- shared.lua


function PLAYER:SetDuelData(duelData)
    if not self or not self:IsValid() then return end
    if not duelData then
        print("SetDuelData: Attempting to set nil DuelData for player " .. self:Nick())
        return
    end

    local duelDataJson = util.TableToJSON(duelData)
    if not duelDataJson then
        print("SetDuelData: Failed to convert DuelData to JSON for player " .. self:Nick())
        return
    end

    self:SetNWString("DuelData", duelDataJson)
    print("SetDuelData: DuelData set for player " .. self:Nick() .. ", JSON: " .. duelDataJson)
end



function PLAYER:GetDuelData()
    local duelData = self:GetNWString("duelData", "{}")
    local data = util.JSONToTable(duelData) or {}
    return data
end




function UpdateDuelData(ply)
    if SERVER then
        local duelData = ply:GetDuelData()
        if not duelData then return end
        local duelDataJson = util.TableToJSON(duelData)
        ply:SetNW2String("duelDataJson", duelDataJson)
    end
end


function Shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

