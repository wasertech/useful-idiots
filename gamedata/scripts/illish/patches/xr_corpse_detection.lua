local safe_require = function(lib)
  local ok, result = pcall(require, lib)
  if not ok then
    printf("[useful-idiots] Error: missing required library '%s'. Mod will not load.", lib)
    return nil
  end
  return result
end

local NPC = safe_require("illish.lib.npc")
if not NPC then return end


local PATCH = {}


-- Enable/disable corpse looting for non-companions
local PATCH_corpse_evaluate = xr_corpse_detection.evaluator_corpse.evaluate

function xr_corpse_detection.evaluator_corpse:evaluate()
  local noGathering = ui_mcm.get("idiots/options/noNpcLooting")

  if noGathering and not NPC.isCompanion(self.object) then
    return false
  end

  return PATCH_corpse_evaluate(self)
end


-- Start tracking looted items for inventory visiblity
local PATCH_corpse_initialize = xr_corpse_detection.action_search_corpse.initialize

function xr_corpse_detection.action_search_corpse:initialize()
  if NPC.isCompanion(self.object) then
    NPC.LOOT_SHARING_NPCS[self.object:id()] = true
  end

  PATCH_corpse_initialize(self)
end


-- Stop tracking looted items
local PATCH_corpse_finalize = xr_corpse_detection.action_search_corpse.finalize

function xr_corpse_detection.action_search_corpse:finalize()
  NPC.LOOT_SHARING_NPCS[self.object:id()] = nil
  PATCH_corpse_finalize(self)
end


-- Track lotted item when taken
function PATCH.onTakeItem(npc, item)
  if NPC.isCompanion(npc) and NPC.LOOT_SHARING_NPCS[npc:id()] then
    NPC.LOOT_SHARED_ITEMS[item:id()] = true
  end
end


-- Untrack looted item once actor takes it
function PATCH.onActorTakeItem(item)
  NPC.LOOT_SHARED_ITEMS[item:id()] = nil
end


-- Untrack looted item when despawned
function PATCH.onEntityUnregister(entity)
  NPC.LOOT_SHARED_ITEMS[entity.id] = nil
end


-- Callbacks
RegisterScriptCallback("idiots_on_start", function()
  RegisterScriptCallback("npc_on_item_take", PATCH.onTakeItem)
  RegisterScriptCallback("actor_on_item_take", PATCH.onActorTakeItem)
  RegisterScriptCallback("server_entity_on_unregister", PATCH.onEntityUnregister)
end)


return PATCH
