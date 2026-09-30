-- Receipts: idempotent per PurchaseId, save before grant, rollback on failed save.
local RS = game:GetService("ReplicatedStorage")
local Rules = require(RS.BlackoutCrew.Rules)
local Receipts = require(game.ServerScriptService.BlackoutCrew.Receipts)

return function(T)
	local D = Enum.ProductPurchaseDecision
	local player = { UserId = 5 }
	local saveOk, saves, granted = true, 0, 0
	local profiles = { loaded = { [player] = Rules.defaultProfile() } }
	function profiles:save()
		saves += 1
		return saveOk
	end
	local handle = Receipts.handler({
		products = { { id = 0, credits = 999 }, { id = 111, credits = 500 } },
		profiles = profiles,
		getPlayer = function(id)
			return id == 5 and player or nil
		end,
		onGranted = function()
			granted += 1
		end,
	})
	local data = profiles.loaded[player]
	T.eq("first purchase granted", handle({ PlayerId = 5, PurchaseId = "p1", ProductId = 111 }), D.PurchaseGranted)
	T.eq("credits added", data.credits, 500)
	T.check("receipt recorded + saved", data.receipts.p1 == true and saves == 1)
	T.eq("repeat PurchaseId granted", handle({ PlayerId = 5, PurchaseId = "p1", ProductId = 111 }), D.PurchaseGranted)
	T.eq("repeat not credited twice", data.credits, 500)
	T.eq("onGranted once", granted, 1)
	T.eq("unknown product not processed", handle({ PlayerId = 5, PurchaseId = "p2", ProductId = 999 }), D.NotProcessedYet)
	T.eq("hidden id 0 never matches", handle({ PlayerId = 5, PurchaseId = "p3", ProductId = 0 }), D.NotProcessedYet)
	T.eq("player not loaded", handle({ PlayerId = 6, PurchaseId = "p4", ProductId = 111 }), D.NotProcessedYet)
	saveOk = false
	T.eq("failed save not processed", handle({ PlayerId = 5, PurchaseId = "p5", ProductId = 111 }), D.NotProcessedYet)
	T.check("failed save rolled back", data.credits == 500 and data.receipts.p5 == nil)
	saveOk = true
	T.eq("retry after recovery granted", handle({ PlayerId = 5, PurchaseId = "p5", ProductId = 111 }), D.PurchaseGranted)
	T.eq("retry credited once", data.credits, 1000)
	T.eq("PurchaseId number key", handle({ PlayerId = 5, PurchaseId = 123, ProductId = 111 }), D.PurchaseGranted)
	T.check("numeric PurchaseId stored as string", data.receipts["123"] == true)
end
