-- Developer-product receipts (ported pattern from roblox 1 GameService ProcessReceipt):
-- idempotent per PurchaseId, save BEFORE grant, roll back on failed save. Reused for crate/wheel/pass (3B).
local Receipts = {}

-- opts.products: { {id, credits} } (id 0 = hidden, never matches); opts.profiles: Profiles instance;
-- opts.getPlayer(userId); opts.onGranted(player, product)
function Receipts.handler(opts)
	return function(info)
		local Decision = Enum.ProductPurchaseDecision
		local player = opts.getPlayer(info.PlayerId)
		local data = player and opts.profiles.loaded[player]
		if not data then
			return Decision.NotProcessedYet
		end
		local key = tostring(info.PurchaseId)
		if data.receipts[key] then
			return Decision.PurchaseGranted -- already granted and saved: don't grant twice
		end
		local product
		for _, x in ipairs(opts.products) do
			if x.id ~= 0 and x.id == info.ProductId then
				product = x
			end
		end
		if not product then
			return Decision.NotProcessedYet
		end
		data.receipts[key] = true
		data.credits += product.credits
		if not opts.profiles:save(player, false) then
			data.receipts[key] = nil
			data.credits -= product.credits
			return Decision.NotProcessedYet
		end
		if opts.onGranted then
			opts.onGranted(player, product)
		end
		return Decision.PurchaseGranted
	end
end

return Receipts
