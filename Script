-- services variables
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- player stuff
local player = Players.LocalPlayer
local playerBackpack = player:WaitForChild("Backpack")
local inventoryFolder = player:WaitForChild("Inventory") 

-- modules and all the remotes
local ItemsModule = require(ReplicatedStorage:WaitForChild("ItemsModule"))
local EquipRemote = ReplicatedStorage:WaitForChild("Equip")

-- ui stuff
local InventoryBackground = script.Parent.Background
local ItemsList = InventoryBackground.Items
local ItemTemplate = ItemsList.Item 
ItemTemplate.Visible = false 

local ItemBackground = script.Parent.ItemBackground
local DetailsFrame = ItemBackground.Item
local EquipButton = DetailsFrame.Equip
local DetailsName = DetailsFrame.ItemName
local DetailsDesc = DetailsFrame.ItemDescription
local DetailsRarity = DetailsFrame.ItemRarity

-- states
local currentSelectedItem = nil -- check which item string is being viewed
local isDetailsOpen = false 

-- ui configs
-- this is the tweening info for the pop up window
local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- the open and close end result for postions
local openPosition = UDim2.new(0.532, 0, 0.161, 0)
local closePosition = UDim2.new(0.251, 0, 0.159, 0)

-- ui configs
ItemBackground.Position = closePosition
ItemBackground.Visible = false

-- check if the tool is being held by the player or in the backpack
local function getEquipStatus(itemName)
	local char = player.Character or player.CharacterAdded:Wait()

	-- checking both player and backpack locations
	local foundInChar = char:FindFirstChild(itemName)
	local foundInBackpack = playerBackpack:FindFirstChild(itemName)

	if foundInChar or foundInBackpack then 
		return "Unequip"
	end

	return "Equip"
end

-- toggles the equip button based on the item's data
-- materials won't be equipable
local function updateEquipButtonState()
	if not currentSelectedItem then return end -- Sanity check

	local itemData = ItemsModule.Items[currentSelectedItem]

	if itemData and itemData.Equipable then
		EquipButton.Visible = true
		EquipButton.Text = getEquipStatus(currentSelectedItem)
	else
		-- hide if the item is not equipable
		EquipButton.Visible = false
	end
end

-- does some cool animations
local function closeDetailsPanel()
	isDetailsOpen = false
	currentSelectedItem = nil

	-- Slide out
	local tween = TweenService:Create(ItemBackground, tweenInfo, {Position = closePosition})
	tween:Play()

	-- wait for animation to finish before fully hiding
	task.wait(0.4)
	if not isDetailsOpen then 
		ItemBackground.Visible = false 
	end
end

-- opens the details panel to check out some details about the item
local function openDetailsPanel(itemName)
	-- if they click the button twice they open and close it
	if currentSelectedItem == itemName and isDetailsOpen then
		closeDetailsPanel()
		return
	end

	local itemData = ItemsModule.Items[itemName]
	if not itemData then 
		warn("Inventory: Attempted to view item with no Module data: " .. tostring(itemName))
		return 
	end

	currentSelectedItem = itemName
	isDetailsOpen = true

	-- UI Elements
	DetailsName.Text = itemData.Name
	DetailsDesc.Text = itemData.Description
	DetailsRarity.Text = itemData.Rarity

	-- Default to white if rarity color is missing to prevent errors
	local rarityColor = ItemsModule.Rarities[itemData.Rarity] or Color3.new(1,1,1)
	DetailsRarity.TextColor3 = rarityColor

	updateEquipButtonState()

	-- the popup needs to be above the scrolling frame so that is why the ZIndex is awesome
	ItemBackground.ZIndex = 5
	DetailsName.ZIndex = 10
	EquipButton.ZIndex = 10

	-- cool animation
	ItemBackground.Visible = true
	local tween = TweenService:Create(ItemBackground, tweenInfo, {Position = openPosition})
	tween:Play()
end

-- refresh of the inventory list
local function refreshInventory()
	-- Clean up old list items
	for _, child in ipairs(ItemsList:GetChildren()) do
		if child ~= ItemTemplate and child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	if not inventoryFolder then return end

	-- go through the physical NumberValues in the player's inventory folder
	for _, itemValue in ipairs(inventoryFolder:GetChildren()) do
		local itemName = itemValue.Name
		local itemAmount = itemValue.Value
		local itemData = ItemsModule.Items[itemName]

		if itemData then
			local newItem = ItemTemplate:Clone()
			newItem.Name = itemName
			newItem.Visible = true
			newItem.Parent = ItemsList

			--stuff
			newItem.ItemName.Text = itemName
			newItem.ImageLabel.Image = itemData.Image
			newItem.Amount.Text = "x" .. tostring(itemAmount)

			-- some visual stuff
			local rarityColor = ItemsModule.Rarities[itemData.Rarity] or Color3.new(1,1,1)
			newItem.ImageColor3 = rarityColor

			-- important to open the details panel for the item
			newItem.MouseButton1Click:Connect(function()
				openDetailsPanel(itemName)
			end)
		end
	end
end

-- Handle the Equip/Unequip button like a pro
EquipButton.MouseButton1Click:Connect(function()
	if not currentSelectedItem then return end

	local currentStatus = EquipButton.Text

	-- Send request to server to handle the welding/inventory logic
	EquipRemote:FireServer(currentSelectedItem, currentStatus)
	
	if currentStatus == "Equip" then
		EquipButton.Text = "Unequip"
	else
		EquipButton.Text = "Equip"
	end
end)

-- we keep track of all the connected items so it's more smooth
local connectedItems = {}

local function setupItemConnection(itemValue)
	if not connectedItems[itemValue] then
		connectedItems[itemValue] = true
		-- if the ammount of the item changes then the inventory gets refreshed
		itemValue.Changed:Connect(refreshInventory)
	end
end

-- inputing existing inventory items
if inventoryFolder then
	for _, child in ipairs(inventoryFolder:GetChildren()) do
		if child:IsA("NumberValue") then 
			setupItemConnection(child) 
		end
	end

	-- waits for any new items to get added
	inventoryFolder.ChildAdded:Connect(function(child)
		if child:IsA("NumberValue") then
			setupItemConnection(child)
			refreshInventory()
		end
	end)

	-- waits for items to get removed
	inventoryFolder.ChildRemoved:Connect(refreshInventory)
end

-- if its equipped then the button says UnEquip if its UnEquip the button says Equipped
playerBackpack.ChildAdded:Connect(updateEquipButtonState)
playerBackpack.ChildRemoved:Connect(updateEquipButtonState)

-- we do it again if the player gets reseted or something
local function onCharacterAdded(newChar)
	updateEquipButtonState()
	newChar.ChildAdded:Connect(updateEquipButtonState)
	newChar.ChildRemoved:Connect(updateEquipButtonState)
end

-- Hook existing character if script loads late, otherwise wait for spawn
if player.Character then 
	onCharacterAdded(player.Character) 
end
player.CharacterAdded:Connect(onCharacterAdded)

refreshInventory()
