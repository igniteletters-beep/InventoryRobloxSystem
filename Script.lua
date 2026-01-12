-- inventory handler script 
-- handles the UI, sorting by rarity, and category filtering
-- note to self: make sure the buttons in FilterFrame are named exactly like the Types in the module

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- player stuff
local player = Players.LocalPlayer
local playerBackpack = player:WaitForChild("Backpack")
local inventoryFolder = player:WaitForChild("Inventory") 

-- getting module data and the equip remote
local ItemsModule = require(ReplicatedStorage:WaitForChild("ItemsModule"))
local EquipRemote = ReplicatedStorage:WaitForChild("Equip")

-- ui elements
local InventoryBackground = script.Parent.Background
local ItemsList = InventoryBackground.Items
local ItemTemplate = ItemsList.Item 
ItemTemplate.Visible = false 

-- detail side panel stuff
local ItemBackground = script.Parent.ItemBackground
local DetailsFrame = ItemBackground.Item
local EquipButton = DetailsFrame.Equip
local DetailsName = DetailsFrame.ItemName
local DetailsDesc = DetailsFrame.ItemDescription
local DetailsRarity = DetailsFrame.ItemRarity

-- filtering/sorting buttons
local FilterButtons = InventoryBackground:FindFirstChild("FilterFrame") 
local SortButton = InventoryBackground:FindFirstChild("SortBtn")

-- current states
local currentSelectedItem = nil 
local isDetailsOpen = false 
local currentCategory = "All" 
local currentSortMode = "Rarity" -- starting with rarity sort since thats what you want

-- tweening configs
local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local openPosition = UDim2.new(0.532, 0, 0.161, 0)
local closePosition = UDim2.new(0.251, 0, 0.159, 0)

-- hide detail panel on start
ItemBackground.Position = closePosition
ItemBackground.Visible = false

-- check if item is held or in backpack
local function getEquipStatus(itemName)
	local char = player.Character or player.CharacterAdded:Wait()

	local foundInChar = char:FindFirstChild(itemName)
	local foundInBackpack = playerBackpack:FindFirstChild(itemName)

	if foundInChar or foundInBackpack then 
		return "Unequip"
	end
	return "Equip"
end

-- updates the button text based on status
local function updateEquipButtonState()
	if not currentSelectedItem then return end 

	local itemData = ItemsModule.Items[currentSelectedItem]
	if itemData and itemData.Equipable then
		EquipButton.Visible = true
		EquipButton.Text = getEquipStatus(currentSelectedItem)
	else
		-- hide for stuff like stones or emeralds that u cant "hold"
		EquipButton.Visible = false
	end
end

-- slide out the side panel
local function closeDetailsPanel()
	isDetailsOpen = false
	currentSelectedItem = nil

	local tween = TweenService:Create(ItemBackground, tweenInfo, {Position = closePosition})
	tween:Play()

	task.wait(0.4)
	if not isDetailsOpen then 
		ItemBackground.Visible = false 
	end
end

-- show item info when clicked
local function openDetailsPanel(itemName)
	if currentSelectedItem == itemName and isDetailsOpen then
		closeDetailsPanel()
		return
	end

	local itemData = ItemsModule.Items[itemName]
	if not itemData then 
		warn("Inventory: No module info for " .. tostring(itemName))
		return 
	end

	currentSelectedItem = itemName
	isDetailsOpen = true

	-- fill text labels
	DetailsName.Text = itemData.Name
	DetailsDesc.Text = itemData.Description
	DetailsRarity.Text = itemData.Rarity

	-- color based on module colors
	local rarityColor = ItemsModule.Rarities[itemData.Rarity] or Color3.new(1,1,1)
	DetailsRarity.TextColor3 = rarityColor

	updateEquipButtonState()

	ItemBackground.Visible = true
	local tween = TweenService:Create(ItemBackground, tweenInfo, {Position = openPosition})
	tween:Play()
end

-- THE SORTING LOGIC
local function getSortedTable()
	local displayTable = {}

	-- collect items that match current filter
	for _, itemValue in ipairs(inventoryFolder:GetChildren()) do
		local itemData = ItemsModule.Items[itemValue.Name]

		if itemData then
			if currentCategory == "All" or itemData.Type == currentCategory then
				table.insert(displayTable, {
					Name = itemValue.Name,
					Amount = itemValue.Value,
					Rarity = itemData.Rarity,
					Data = itemData
				})
			end
		end
	end

	-- sort the items
	table.sort(displayTable, function(a, b)
		if currentSortMode == "Rarity" then
			-- weight system: common is lowest (1), mythical is highest
			-- adjust names here to match your exact rarity names in the module!
			local weights = {
				["Common"] = 1, 
				["Rare"] = 2, 
				["Legendary"] = 3, 
				["Mytical"] = 4, 
			}

			local weightA = weights[a.Rarity] or 0
			local weightB = weights[b.Rarity] or 0

			if weightA ~= weightB then
				-- use < to put lower weights (Common) at the start
				return weightA < weightB 
			end
		end

		-- default alphabetic sort if rarities are same
		return a.Name < b.Name
	end)

	return displayTable
end

-- clear and rebuild the icons
local function refreshInventory()
	-- destroy old clones
	for _, child in ipairs(ItemsList:GetChildren()) do
		if child ~= ItemTemplate and child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	local itemsToShow = getSortedTable()

	for _, itemInfo in ipairs(itemsToShow) do
		local itemName = itemInfo.Name
		local itemAmount = itemInfo.Amount
		local itemData = itemInfo.Data

		local newItem = ItemTemplate:Clone()
		newItem.Name = itemName
		newItem.Visible = true
		newItem.Parent = ItemsList

		-- fill ui labels
		newItem.ItemName.Text = itemName
		newItem.ImageLabel.Image = itemData.Image
		newItem.Amount.Text = "x" .. tostring(itemAmount)

		-- rarity color BG
		local rarityColor = ItemsModule.Rarities[itemData.Rarity] or Color3.new(1,1,1)
		newItem.ImageColor3 = rarityColor

		newItem.MouseButton1Click:Connect(function()
			openDetailsPanel(itemName)
		end)
	end
end

-- filter category click handlers
if FilterButtons then
	for _, btn in ipairs(FilterButtons:GetChildren()) do
		if btn:IsA("TextButton") then
			btn.MouseButton1Click:Connect(function()
				currentCategory = btn.Name 
				refreshInventory()
			end)
		end
	end
end

-- toggle sort mode
if SortButton then
	SortButton.MouseButton1Click:Connect(function()
		currentSortMode = (currentSortMode == "Name") and "Rarity" or "Name"
		SortButton.Text = "Sort: " .. currentSortMode
		refreshInventory()
	end)
end

-- equip btn request
EquipButton.MouseButton1Click:Connect(function()
	if not currentSelectedItem then return end
	local currentStatus = EquipButton.Text

	EquipRemote:FireServer(currentSelectedItem, currentStatus)

	-- quick UI swap for better feel
	EquipButton.Text = (currentStatus == "Equip") and "Unequip" or "Equip"
end)

-- connection tracking to stop memory leaks
local connectedItems = {}

local function setupItemConnection(itemValue)
	if not connectedItems[itemValue] then
		connectedItems[itemValue] = itemValue.Changed:Connect(refreshInventory)
	end
end

local function removeConnection(itemValue)
	if connectedItems[itemValue] then
		connectedItems[itemValue]:Disconnect()
		connectedItems[itemValue] = nil
	end
end

-- init connections
if inventoryFolder then
	for _, child in ipairs(inventoryFolder:GetChildren()) do
		if child:IsA("NumberValue") then setupItemConnection(child) end
	end

	inventoryFolder.ChildAdded:Connect(function(child)
		if child:IsA("NumberValue") then
			setupItemConnection(child)
			refreshInventory()
		end
	end)

	inventoryFolder.ChildRemoved:Connect(function(child)
		removeConnection(child)
		refreshInventory()
	end)
end

-- keep button text updated on tool move
playerBackpack.ChildAdded:Connect(updateEquipButtonState)
playerBackpack.ChildRemoved:Connect(updateEquipButtonState)

local function onCharacterAdded(newChar)
	updateEquipButtonState()
	newChar.ChildAdded:Connect(updateEquipButtonState)
	newChar.ChildRemoved:Connect(updateEquipButtonState)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

-- startup
refreshInventory()
