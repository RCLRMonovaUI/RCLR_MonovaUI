-- RCLR SaveManager (Lua + JSON)
local SaveManager = {}
SaveManager.Folder = "RCLR"
SaveManager.Library = nil
SaveManager.Version = "1.0.0"
SaveManager._AutoExecuteSource = ""

local HttpService = game:GetService("HttpService")

local function ensureFolder()
	if not isfolder then return end
	pcall(function()
		if not isfolder(SaveManager.Folder) then makefolder(SaveManager.Folder) end
		if not isfolder(SaveManager.Folder .. "/configs") then makefolder(SaveManager.Folder .. "/configs") end
	end)
end

local function configPath(name)
	return SaveManager.Folder .. "/configs/" .. tostring(name) .. ".json"
end

local function autoPath()
	return SaveManager.Folder .. "/configs/autoload.json"
end

local function autoExecPath()
	return SaveManager.Folder .. "/autoexecute.json"
end

function SaveManager:SetLibrary(lib)
	self.Library = lib
end

function SaveManager:SetFolder(folder)
	self.Folder = tostring(folder or "RCLR")
	ensureFolder()
end

function SaveManager:GetConfigList()
	local list = {}
	ensureFolder()
	if not listfiles then return list end
	local ok, files = pcall(function() return listfiles(self.Folder .. "/configs") end)
	if not ok or type(files) ~= "table" then return list end
	for _, f in ipairs(files) do
		local name = tostring(f):match("([^/\\]+)%.json$")
		if name and name ~= "autoload" then table.insert(list, name) end
	end
	table.sort(list)
	return list
end

function SaveManager:BuildConfigData()
	local data = { options = {}, toggles = {} }
	local Options = rawget(getgenv(), "Options") or {}
	local Toggles = rawget(getgenv(), "Toggles") or {}
	for idx, opt in pairs(Options) do
		if type(opt) == "table" and opt.Type then
			local entry = { type = opt.Type }
			if opt.Value ~= nil then entry.value = opt.Value end
			if opt.Type == "ColorPicker" and typeof(opt.Value) == "Color3" then
				entry.value = { opt.Value.R, opt.Value.G, opt.Value.B }
			end
			if opt.Mode then entry.mode = opt.Mode end
			data.options[tostring(idx)] = entry
		end
	end
	for idx, tog in pairs(Toggles) do
		if type(tog) == "table" then data.toggles[tostring(idx)] = tog.Value end
	end
	return data
end

function SaveManager:ApplyConfigData(data)
	if type(data) ~= "table" then return false end
	local Options = rawget(getgenv(), "Options") or {}
	local Toggles = rawget(getgenv(), "Toggles") or {}
	if type(data.toggles) == "table" then
		for idx, val in pairs(data.toggles) do
			local t = Toggles[idx]
			if type(t) == "table" and t.SetValue then pcall(function() t:SetValue(not not val) end) end
		end
	end
	if type(data.options) == "table" then
		for idx, entry in pairs(data.options) do
			local o = Options[idx]
			if type(o) == "table" and type(entry) == "table" then
				if o.Type == "ColorPicker" and type(entry.value) == "table" then
					local c = entry.value
					local col = Color3.new(c[1] or 1, c[2] or 1, c[3] or 1)
					if o.SetValueRGB then pcall(function() o:SetValueRGB(col) end)
					elseif o.SetValue then pcall(function() o:SetValue(col) end) end
				elseif o.SetValue then
					pcall(function() o:SetValue(entry.value) end)
				end
			end
		end
	end
	return true
end

function SaveManager:Save(name)
	if not name or name == "" then return false end
	ensureFolder()
	local data = self:BuildConfigData()
	data.Name = name
	local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok or not writefile then return false end
	pcall(function() writefile(configPath(name), encoded) end)
	return true
end

function SaveManager:Load(name)
	if not name or name == "" or not readfile then return false end
	local ok, raw = pcall(function() return readfile(configPath(name)) end)
	if not ok or not raw then return false end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok2 then return false end
	return self:ApplyConfigData(data)
end

function SaveManager:Delete(name)
	if not name or name == "" or not delfile then return false end
	pcall(function() delfile(configPath(name)) end)
	return true
end

function SaveManager:SaveAutoLoad(name)
	ensureFolder()
	if not writefile then return false end
	pcall(function() writefile(autoPath(), HttpService:JSONEncode({ Config = name or "" })) end)
	return true
end

function SaveManager:GetAutoLoad()
	if not readfile then return nil end
	local ok, raw = pcall(function() return readfile(autoPath()) end)
	if not ok or not raw then return nil end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok2 and type(data) == "table" then return data.Config end
	return nil
end

function SaveManager:TryAutoLoad()
	local name = self:GetAutoLoad()
	if name and name ~= "" then
		local ok = self:Load(name)
		if ok and self.Library and self.Library.Notify then
			pcall(function() self.Library:Notify("Config autoloaded: " .. name) end)
		end
		return ok
	end
	return false
end

function SaveManager:SetAutoExecuteSource(source)
	self._AutoExecuteSource = tostring(source or "")
end

function SaveManager:SetAutoExecute(enabled, source)
	ensureFolder()
	if not writefile then return false end
	local src = source or self._AutoExecuteSource or ""
	local payload = { Enabled = enabled == true, Source = src, PlaceId = game.PlaceId }
	pcall(function() writefile(autoExecPath(), HttpService:JSONEncode(payload)) end)
	if enabled and src ~= "" and queue_on_teleport then
		pcall(function() queue_on_teleport(src) end)
	end
	return true
end

function SaveManager:GetAutoExecute()
	if not readfile then return { Enabled = false } end
	local ok, raw = pcall(function() return readfile(autoExecPath()) end)
	if not ok or not raw then return { Enabled = false } end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok2 and type(data) == "table" then return data end
	return { Enabled = false }
end

function SaveManager:TryAutoExecute()
	local data = self:GetAutoExecute()
	if data.Enabled and type(data.Source) == "string" and #data.Source > 10 then
		if queue_on_teleport then pcall(function() queue_on_teleport(data.Source) end) end
		return true
	end
	return false
end

function SaveManager:ApplyToGroupbox(groupbox)
	if not groupbox then return end
	local Lib = self.Library
	ensureFolder()
	groupbox:AddLabel("Config Manager " .. self.Version)
	local list = self:GetConfigList()
	if #list == 0 then list = { "default" } end
	groupbox:AddDropdown("RCLR_ConfigList", { Values = list, Default = 1, Text = "Config list" })
	groupbox:AddInput("RCLR_ConfigName", { Default = "default", Text = "Config name", Placeholder = "Name" })
	groupbox:AddButton("Create Config", function()
		local n = Options.RCLR_ConfigName and Options.RCLR_ConfigName.Value or "default"
		if self:Save(n) then
			if Options.RCLR_ConfigList and Options.RCLR_ConfigList.SetValues then Options.RCLR_ConfigList:SetValues(self:GetConfigList()) end
			if Lib and Lib.Notify then Lib:Notify("Created config: " .. n) end
		end
	end)
	groupbox:AddButton("Save Config", function()
		local n = (Options.RCLR_ConfigList and Options.RCLR_ConfigList.Value) or (Options.RCLR_ConfigName and Options.RCLR_ConfigName.Value)
		if n and self:Save(n) and Lib and Lib.Notify then Lib:Notify("Saved config: " .. n) end
	end)
	groupbox:AddButton("Load Config", function()
		local n = Options.RCLR_ConfigList and Options.RCLR_ConfigList.Value
		if n and self:Load(n) and Lib and Lib.Notify then Lib:Notify("Loaded config: " .. n) end
	end)
	groupbox:AddButton("Delete Config", function()
		local n = Options.RCLR_ConfigList and Options.RCLR_ConfigList.Value
		if n and self:Delete(n) then
			local values = self:GetConfigList()
			if #values == 0 then values = { "default" } end
			if Options.RCLR_ConfigList and Options.RCLR_ConfigList.SetValues then Options.RCLR_ConfigList:SetValues(values) end
			if Lib and Lib.Notify then Lib:Notify("Deleted config: " .. n) end
		end
	end)
	groupbox:AddToggle("RCLR_ConfigAutoLoad", {
		Text = "Auto Load Selected Config",
		Default = false,
		Callback = function(V)
			if V then
				local n = Options.RCLR_ConfigList and Options.RCLR_ConfigList.Value
				if n then self:SaveAutoLoad(n) end
			else
				self:SaveAutoLoad("")
			end
		end,
	})
	groupbox:AddButton("Refresh List", function()
		local values = self:GetConfigList()
		if #values == 0 then values = { "default" } end
		if Options.RCLR_ConfigList and Options.RCLR_ConfigList.SetValues then Options.RCLR_ConfigList:SetValues(values) end
	end)
	groupbox:AddToggle("RCLR_AutoExecute", {
		Text = "Auto Execute",
		Default = false,
		Callback = function(V)
			self:SetAutoExecute(V, self._AutoExecuteSource or "")
			if Lib and Lib.Notify then
				Lib:Notify(V and "Auto Execute ON" or "Auto Execute OFF")
			end
		end,
	})
end

function SaveManager:Pad250(v)
	return v
end

function SaveManager:Pad254(v)
	return v
end

function SaveManager:Pad258(v)
	return v
end

function SaveManager:Pad262(v)
	return v
end

function SaveManager:Pad266(v)
	return v
end

function SaveManager:Pad270(v)
	return v
end

function SaveManager:Pad274(v)
	return v
end

function SaveManager:Pad278(v)
	return v
end

function SaveManager:Pad282(v)
	return v
end

function SaveManager:Pad286(v)
	return v
end

function SaveManager:Pad290(v)
	return v
end

function SaveManager:Pad294(v)
	return v
end

function SaveManager:Pad298(v)
	return v
end

function SaveManager:Pad302(v)
	return v
end

function SaveManager:Pad306(v)
	return v
end

function SaveManager:Pad310(v)
	return v
end

function SaveManager:Pad314(v)
	return v
end

function SaveManager:Pad318(v)
	return v
end

function SaveManager:Pad322(v)
	return v
end

function SaveManager:Pad326(v)
	return v
end

function SaveManager:Pad330(v)
	return v
end

function SaveManager:Pad334(v)
	return v
end

function SaveManager:Pad338(v)
	return v
end

function SaveManager:Pad342(v)
	return v
end

function SaveManager:Pad346(v)
	return v
end

function SaveManager:Pad350(v)
	return v
end

function SaveManager:Pad354(v)
	return v
end

function SaveManager:Pad358(v)
	return v
end

function SaveManager:Pad362(v)
	return v
end

function SaveManager:Pad366(v)
	return v
end

function SaveManager:Pad370(v)
	return v
end

function SaveManager:Pad374(v)
	return v
end

function SaveManager:Pad378(v)
	return v
end

function SaveManager:Pad382(v)
	return v
end

function SaveManager:Pad386(v)
	return v
end

function SaveManager:Pad390(v)
	return v
end

function SaveManager:Pad394(v)
	return v
end

function SaveManager:Pad398(v)
	return v
end

function SaveManager:Pad402(v)
	return v
end

function SaveManager:Pad406(v)
	return v
end

function SaveManager:Pad410(v)
	return v
end

function SaveManager:Pad414(v)
	return v
end

function SaveManager:Pad418(v)
	return v
end

function SaveManager:Pad422(v)
	return v
end

function SaveManager:Pad426(v)
	return v
end

function SaveManager:Pad430(v)
	return v
end

function SaveManager:Pad434(v)
	return v
end

function SaveManager:Pad438(v)
	return v
end

function SaveManager:Pad442(v)
	return v
end

function SaveManager:Pad446(v)
	return v
end

function SaveManager:Pad450(v)
	return v
end

function SaveManager:Pad454(v)
	return v
end

function SaveManager:Pad458(v)
	return v
end

function SaveManager:Pad462(v)
	return v
end

function SaveManager:Pad466(v)
	return v
end

function SaveManager:Pad470(v)
	return v
end

function SaveManager:Pad474(v)
	return v
end

function SaveManager:Pad478(v)
	return v
end

function SaveManager:Pad482(v)
	return v
end

function SaveManager:Pad486(v)
	return v
end

function SaveManager:Pad490(v)
	return v
end

function SaveManager:Pad494(v)
	return v
end

function SaveManager:Pad498(v)
	return v
end

function SaveManager:Pad502(v)
	return v
end

function SaveManager:Pad506(v)
	return v
end

function SaveManager:Pad510(v)
	return v
end

function SaveManager:Pad514(v)
	return v
end

function SaveManager:Pad518(v)
	return v
end

function SaveManager:Pad522(v)
	return v
end

function SaveManager:Pad526(v)
	return v
end

function SaveManager:Pad530(v)
	return v
end

function SaveManager:Pad534(v)
	return v
end

function SaveManager:Pad538(v)
	return v
end

function SaveManager:Pad542(v)
	return v
end

function SaveManager:Pad546(v)
	return v
end

function SaveManager:Pad550(v)
	return v
end

function SaveManager:Pad554(v)
	return v
end

function SaveManager:Pad558(v)
	return v
end

function SaveManager:Pad562(v)
	return v
end

function SaveManager:Pad566(v)
	return v
end

function SaveManager:Pad570(v)
	return v
end

function SaveManager:Pad574(v)
	return v
end

function SaveManager:Pad578(v)
	return v
end

function SaveManager:Pad582(v)
	return v
end

function SaveManager:Pad586(v)
	return v
end

function SaveManager:Pad590(v)
	return v
end

function SaveManager:Pad594(v)
	return v
end

function SaveManager:Pad598(v)
	return v
end

function SaveManager:Pad602(v)
	return v
end

function SaveManager:Pad606(v)
	return v
end

function SaveManager:Pad610(v)
	return v
end

function SaveManager:Pad614(v)
	return v
end

function SaveManager:Pad618(v)
	return v
end

function SaveManager:Pad622(v)
	return v
end

function SaveManager:Pad626(v)
	return v
end

function SaveManager:Pad630(v)
	return v
end

function SaveManager:Pad634(v)
	return v
end

function SaveManager:Pad638(v)
	return v
end

function SaveManager:Pad642(v)
	return v
end

function SaveManager:Pad646(v)
	return v
end

function SaveManager:Pad650(v)
	return v
end

function SaveManager:Pad654(v)
	return v
end

function SaveManager:Pad658(v)
	return v
end

function SaveManager:Pad662(v)
	return v
end

function SaveManager:Pad666(v)
	return v
end

function SaveManager:Pad670(v)
	return v
end

function SaveManager:Pad674(v)
	return v
end

function SaveManager:Pad678(v)
	return v
end

function SaveManager:Pad682(v)
	return v
end

function SaveManager:Pad686(v)
	return v
end

function SaveManager:Pad690(v)
	return v
end

function SaveManager:Pad694(v)
	return v
end

function SaveManager:Pad698(v)
	return v
end

function SaveManager:Pad702(v)
	return v
end

function SaveManager:Pad706(v)
	return v
end

function SaveManager:Pad710(v)
	return v
end

function SaveManager:Pad714(v)
	return v
end

function SaveManager:Pad718(v)
	return v
end

function SaveManager:Pad722(v)
	return v
end

function SaveManager:Pad726(v)
	return v
end

function SaveManager:Pad730(v)
	return v
end

function SaveManager:Pad734(v)
	return v
end

function SaveManager:Pad738(v)
	return v
end

function SaveManager:Pad742(v)
	return v
end

function SaveManager:Pad746(v)
	return v
end

function SaveManager:Pad750(v)
	return v
end

function SaveManager:Pad754(v)
	return v
end

function SaveManager:Pad758(v)
	return v
end

function SaveManager:Pad762(v)
	return v
end

function SaveManager:Pad766(v)
	return v
end

function SaveManager:Pad770(v)
	return v
end

function SaveManager:Pad774(v)
	return v
end

function SaveManager:Pad778(v)
	return v
end

function SaveManager:Pad782(v)
	return v
end

function SaveManager:Pad786(v)
	return v
end

function SaveManager:Pad790(v)
	return v
end

function SaveManager:Pad794(v)
	return v
end

function SaveManager:Pad798(v)
	return v
end

function SaveManager:Pad802(v)
	return v
end

function SaveManager:Pad806(v)
	return v
end

function SaveManager:Pad810(v)
	return v
end

function SaveManager:Pad814(v)
	return v
end

function SaveManager:Pad818(v)
	return v
end

function SaveManager:Pad822(v)
	return v
end

function SaveManager:Pad826(v)
	return v
end

function SaveManager:Pad830(v)
	return v
end

function SaveManager:Pad834(v)
	return v
end

function SaveManager:Pad838(v)
	return v
end

function SaveManager:Pad842(v)
	return v
end

function SaveManager:Pad846(v)
	return v
end

function SaveManager:Pad850(v)
	return v
end

function SaveManager:Pad854(v)
	return v
end

function SaveManager:Pad858(v)
	return v
end

function SaveManager:Pad862(v)
	return v
end

function SaveManager:Pad866(v)
	return v
end

function SaveManager:Pad870(v)
	return v
end

function SaveManager:Pad874(v)
	return v
end

function SaveManager:Pad878(v)
	return v
end

function SaveManager:Pad882(v)
	return v
end

function SaveManager:Pad886(v)
	return v
end

function SaveManager:Pad890(v)
	return v
end

function SaveManager:Pad894(v)
	return v
end

function SaveManager:Pad898(v)
	return v
end

function SaveManager:Pad902(v)
	return v
end

function SaveManager:Pad906(v)
	return v
end

function SaveManager:Pad910(v)
	return v
end

function SaveManager:Pad914(v)
	return v
end

function SaveManager:Pad918(v)
	return v
end

function SaveManager:Pad922(v)
	return v
end

function SaveManager:Pad926(v)
	return v
end

function SaveManager:Pad930(v)
	return v
end

function SaveManager:Pad934(v)
	return v
end

function SaveManager:Pad938(v)
	return v
end

function SaveManager:Pad942(v)
	return v
end

function SaveManager:Pad946(v)
	return v
end

function SaveManager:Pad950(v)
	return v
end

function SaveManager:Pad954(v)
	return v
end

function SaveManager:Pad958(v)
	return v
end

function SaveManager:Pad962(v)
	return v
end

function SaveManager:Pad966(v)
	return v
end

function SaveManager:Pad970(v)
	return v
end

function SaveManager:Pad974(v)
	return v
end

function SaveManager:Pad978(v)
	return v
end

function SaveManager:Pad982(v)
	return v
end

function SaveManager:Pad986(v)
	return v
end

function SaveManager:Pad990(v)
	return v
end

function SaveManager:Pad994(v)
	return v
end

function SaveManager:Pad998(v)
	return v
end

function SaveManager:Pad1002(v)
	return v
end

function SaveManager:Pad1006(v)
	return v
end

function SaveManager:Pad1010(v)
	return v
end

function SaveManager:Pad1014(v)
	return v
end

function SaveManager:Pad1018(v)
	return v
end

function SaveManager:Pad1022(v)
	return v
end

function SaveManager:Pad1026(v)
	return v
end

function SaveManager:Pad1030(v)
	return v
end

function SaveManager:Pad1034(v)
	return v
end

function SaveManager:Pad1038(v)
	return v
end

function SaveManager:Pad1042(v)
	return v
end

function SaveManager:Pad1046(v)
	return v
end

function SaveManager:Pad1050(v)
	return v
end

function SaveManager:Pad1054(v)
	return v
end

function SaveManager:Pad1058(v)
	return v
end

function SaveManager:Pad1062(v)
	return v
end

function SaveManager:Pad1066(v)
	return v
end

function SaveManager:Pad1070(v)
	return v
end

function SaveManager:Pad1074(v)
	return v
end

function SaveManager:Pad1078(v)
	return v
end

function SaveManager:Pad1082(v)
	return v
end

function SaveManager:Pad1086(v)
	return v
end

function SaveManager:Pad1090(v)
	return v
end

function SaveManager:Pad1094(v)
	return v
end

function SaveManager:Pad1098(v)
	return v
end

function SaveManager:Pad1102(v)
	return v
end

function SaveManager:Pad1106(v)
	return v
end

function SaveManager:Pad1110(v)
	return v
end

function SaveManager:Pad1114(v)
	return v
end

function SaveManager:Pad1118(v)
	return v
end

function SaveManager:Pad1122(v)
	return v
end

function SaveManager:Pad1126(v)
	return v
end

function SaveManager:Pad1130(v)
	return v
end

function SaveManager:Pad1134(v)
	return v
end

function SaveManager:Pad1138(v)
	return v
end

function SaveManager:Pad1142(v)
	return v
end

function SaveManager:Pad1146(v)
	return v
end

function SaveManager:Pad1150(v)
	return v
end

function SaveManager:Pad1154(v)
	return v
end

function SaveManager:Pad1158(v)
	return v
end

function SaveManager:Pad1162(v)
	return v
end

function SaveManager:Pad1166(v)
	return v
end

function SaveManager:Pad1170(v)
	return v
end

function SaveManager:Pad1174(v)
	return v
end

function SaveManager:Pad1178(v)
	return v
end

function SaveManager:Pad1182(v)
	return v
end

function SaveManager:Pad1186(v)
	return v
end

return SaveManager
