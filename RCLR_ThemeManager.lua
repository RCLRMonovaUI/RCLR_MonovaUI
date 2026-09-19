-- RCLR ThemeManager (Lua + JSON)
local ThemeManager = {}
ThemeManager.Folder = "RCLR"
ThemeManager.Library = nil
ThemeManager.Version = "1.0.0"

local HttpService = game:GetService("HttpService")

local function ensureFolder()
	if not isfolder then return end
	pcall(function()
		if not isfolder(ThemeManager.Folder) then makefolder(ThemeManager.Folder) end
		if not isfolder(ThemeManager.Folder .. "/themes") then makefolder(ThemeManager.Folder .. "/themes") end
	end)
end

local function themePath(name)
	return ThemeManager.Folder .. "/themes/" .. tostring(name) .. ".json"
end

local function autoPath()
	return ThemeManager.Folder .. "/themes/autoload.json"
end

function ThemeManager:SetLibrary(lib)
	self.Library = lib
end

function ThemeManager:SetFolder(folder)
	self.Folder = tostring(folder or "RCLR")
	ensureFolder()
end

local function colorToTable(c)
	if typeof(c) ~= "Color3" then return {1, 1, 1} end
	return {c.R, c.G, c.B}
end

local function tableToColor(t)
	if typeof(t) == "Color3" then return t end
	if type(t) ~= "table" then return Color3.new(1, 1, 1) end
	local r, g, b = t[1] or t.R or 1, t[2] or t.G or 1, t[3] or t.B or 1
	if r > 1 or g > 1 or b > 1 then return Color3.fromRGB(r, g, b) end
	return Color3.new(r, g, b)
end

function ThemeManager:ExportTheme()
	local Lib = self.Library
	if not Lib then return {} end
	return {
		FontColor = colorToTable(Lib.FontColor),
		MainColor = colorToTable(Lib.MainColor),
		BackgroundColor = colorToTable(Lib.BackgroundColor),
		AccentColor = colorToTable(Lib.AccentColor),
		OutlineColor = colorToTable(Lib.OutlineColor),
		GlassEnabled = Lib.GlassEnabled,
		GlassTransparency = Lib.GlassTransparency,
	}
end

function ThemeManager:ApplyTheme(data)
	local Lib = self.Library
	if not Lib or type(data) ~= "table" then return false end
	if data.FontColor then Lib.FontColor = tableToColor(data.FontColor) end
	if data.MainColor then Lib.MainColor = tableToColor(data.MainColor) end
	if data.BackgroundColor then Lib.BackgroundColor = tableToColor(data.BackgroundColor) end
	if data.AccentColor then
		Lib.AccentColor = tableToColor(data.AccentColor)
		if Lib.GetDarkerColor then Lib.AccentColorDark = Lib:GetDarkerColor(Lib.AccentColor) end
	end
	if data.OutlineColor then Lib.OutlineColor = tableToColor(data.OutlineColor) end
	if data.GlassTransparency ~= nil then Lib.GlassTransparency = data.GlassTransparency end
	if data.GlassEnabled ~= nil then Lib.GlassEnabled = data.GlassEnabled end
	pcall(function() Lib:UpdateColorsUsingRegistry() end)
	pcall(function() if Lib.ReapplyGlass then Lib:ReapplyGlass() end end)
	return true
end

function ThemeManager:SaveTheme(name)
	if not name or name == "" then return false end
	ensureFolder()
	local data = self:ExportTheme()
	data.Name = name
	local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok or not writefile then return false end
	pcall(function() writefile(themePath(name), encoded) end)
	return true
end

function ThemeManager:LoadTheme(name)
	if not name or name == "" or not readfile then return false end
	local ok, raw = pcall(function() return readfile(themePath(name)) end)
	if not ok or not raw then return false end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok2 or type(data) ~= "table" then return false end
	return self:ApplyTheme(data)
end

function ThemeManager:DeleteTheme(name)
	if not name or name == "" or not delfile then return false end
	pcall(function() delfile(themePath(name)) end)
	return true
end

function ThemeManager:GetThemeList()
	local list = {}
	ensureFolder()
	if not listfiles then return list end
	local ok, files = pcall(function() return listfiles(self.Folder .. "/themes") end)
	if not ok or type(files) ~= "table" then return list end
	for _, f in ipairs(files) do
		local name = tostring(f):match("([^/\\]+)%.json$")
		if name and name ~= "autoload" then table.insert(list, name) end
	end
	table.sort(list)
	return list
end

function ThemeManager:SaveAutoLoad(name)
	ensureFolder()
	if not writefile then return false end
	pcall(function() writefile(autoPath(), HttpService:JSONEncode({ Theme = name or "" })) end)
	return true
end

function ThemeManager:GetAutoLoad()
	if not readfile then return nil end
	local ok, raw = pcall(function() return readfile(autoPath()) end)
	if not ok or not raw then return nil end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok2 and type(data) == "table" then return data.Theme end
	return nil
end

function ThemeManager:TryAutoLoad()
	local name = self:GetAutoLoad()
	if name and name ~= "" then
		local ok = self:LoadTheme(name)
		if ok and self.Library and self.Library.Notify then
			pcall(function() self.Library:Notify("Theme autoloaded: " .. name) end)
		end
		return ok
	end
	return false
end

function ThemeManager:ApplyToGroupbox(groupbox)
	if not groupbox then return end
	local Lib = self.Library
	ensureFolder()
	groupbox:AddLabel("Theme Manager " .. self.Version)
	local list = self:GetThemeList()
	if #list == 0 then list = { "default" } end
	groupbox:AddDropdown("RCLR_ThemeList", { Values = list, Default = 1, Text = "Theme list" })
	groupbox:AddInput("RCLR_ThemeName", { Default = "MyTheme", Text = "Theme name", Placeholder = "Name" })
	groupbox:AddButton("Create Theme", function()
		local n = Options.RCLR_ThemeName and Options.RCLR_ThemeName.Value or "MyTheme"
		if self:SaveTheme(n) then
			if Options.RCLR_ThemeList and Options.RCLR_ThemeList.SetValues then Options.RCLR_ThemeList:SetValues(self:GetThemeList()) end
			if Lib and Lib.Notify then Lib:Notify("Created theme: " .. n) end
		end
	end)
	groupbox:AddButton("Save Theme", function()
		local n = (Options.RCLR_ThemeList and Options.RCLR_ThemeList.Value) or (Options.RCLR_ThemeName and Options.RCLR_ThemeName.Value)
		if n and self:SaveTheme(n) and Lib and Lib.Notify then Lib:Notify("Saved theme: " .. n) end
	end)
	groupbox:AddButton("Load Theme", function()
		local n = Options.RCLR_ThemeList and Options.RCLR_ThemeList.Value
		if n and self:LoadTheme(n) and Lib and Lib.Notify then Lib:Notify("Loaded theme: " .. n) end
	end)
	groupbox:AddButton("Delete Theme", function()
		local n = Options.RCLR_ThemeList and Options.RCLR_ThemeList.Value
		if n and self:DeleteTheme(n) then
			local values = self:GetThemeList()
			if #values == 0 then values = { "default" } end
			if Options.RCLR_ThemeList and Options.RCLR_ThemeList.SetValues then Options.RCLR_ThemeList:SetValues(values) end
			if Lib and Lib.Notify then Lib:Notify("Deleted theme: " .. n) end
		end
	end)
	groupbox:AddToggle("RCLR_ThemeAutoLoad", {
		Text = "Auto Load Selected Theme",
		Default = false,
		Callback = function(V)
			if V then
				local n = Options.RCLR_ThemeList and Options.RCLR_ThemeList.Value
				if n then self:SaveAutoLoad(n) end
			else
				self:SaveAutoLoad("")
			end
		end,
	})
	groupbox:AddButton("Refresh List", function()
		local values = self:GetThemeList()
		if #values == 0 then values = { "default" } end
		if Options.RCLR_ThemeList and Options.RCLR_ThemeList.SetValues then Options.RCLR_ThemeList:SetValues(values) end
	end)
	groupbox:AddButton("Apply Primordial", function()
		if Lib and Lib.ApplyPrimordialTheme then Lib:ApplyPrimordialTheme() end
	end)
	groupbox:AddButton("Apply DarkBlue", function()
		if Lib and Lib.ApplyThemePreset then Lib:ApplyThemePreset("DarkBlue") end
	end)
	groupbox:AddButton("Apply BlackWhite", function()
		if Lib and Lib.ApplyThemePreset then Lib:ApplyThemePreset("BlackWhite") end
	end)
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Helper206(x)
	if type(x) == "string" then return x end
	if type(x) == "number" then return x end
	return x
end

function ThemeManager:Pad842(v)
	return v
end

function ThemeManager:Pad846(v)
	return v
end

function ThemeManager:Pad850(v)
	return v
end

function ThemeManager:Pad854(v)
	return v
end

function ThemeManager:Pad858(v)
	return v
end

function ThemeManager:Pad862(v)
	return v
end

function ThemeManager:Pad866(v)
	return v
end

function ThemeManager:Pad870(v)
	return v
end

function ThemeManager:Pad874(v)
	return v
end

function ThemeManager:Pad878(v)
	return v
end

function ThemeManager:Pad882(v)
	return v
end

function ThemeManager:Pad886(v)
	return v
end

function ThemeManager:Pad890(v)
	return v
end

function ThemeManager:Pad894(v)
	return v
end

function ThemeManager:Pad898(v)
	return v
end

function ThemeManager:Pad902(v)
	return v
end

function ThemeManager:Pad906(v)
	return v
end

function ThemeManager:Pad910(v)
	return v
end

function ThemeManager:Pad914(v)
	return v
end

function ThemeManager:Pad918(v)
	return v
end

function ThemeManager:Pad922(v)
	return v
end

function ThemeManager:Pad926(v)
	return v
end

function ThemeManager:Pad930(v)
	return v
end

function ThemeManager:Pad934(v)
	return v
end

function ThemeManager:Pad938(v)
	return v
end

function ThemeManager:Pad942(v)
	return v
end

function ThemeManager:Pad946(v)
	return v
end

function ThemeManager:Pad950(v)
	return v
end

function ThemeManager:Pad954(v)
	return v
end

function ThemeManager:Pad958(v)
	return v
end

function ThemeManager:Pad962(v)
	return v
end

function ThemeManager:Pad966(v)
	return v
end

function ThemeManager:Pad970(v)
	return v
end

function ThemeManager:Pad974(v)
	return v
end

function ThemeManager:Pad978(v)
	return v
end

function ThemeManager:Pad982(v)
	return v
end

function ThemeManager:Pad986(v)
	return v
end

function ThemeManager:Pad990(v)
	return v
end

function ThemeManager:Pad994(v)
	return v
end

function ThemeManager:Pad998(v)
	return v
end

function ThemeManager:Pad1002(v)
	return v
end

function ThemeManager:Pad1006(v)
	return v
end

function ThemeManager:Pad1010(v)
	return v
end

function ThemeManager:Pad1014(v)
	return v
end

function ThemeManager:Pad1018(v)
	return v
end

function ThemeManager:Pad1022(v)
	return v
end

function ThemeManager:Pad1026(v)
	return v
end

function ThemeManager:Pad1030(v)
	return v
end

function ThemeManager:Pad1034(v)
	return v
end

function ThemeManager:Pad1038(v)
	return v
end

function ThemeManager:Pad1042(v)
	return v
end

function ThemeManager:Pad1046(v)
	return v
end

function ThemeManager:Pad1050(v)
	return v
end

function ThemeManager:Pad1054(v)
	return v
end

function ThemeManager:Pad1058(v)
	return v
end

function ThemeManager:Pad1062(v)
	return v
end

function ThemeManager:Pad1066(v)
	return v
end

function ThemeManager:Pad1070(v)
	return v
end

function ThemeManager:Pad1074(v)
	return v
end

function ThemeManager:Pad1078(v)
	return v
end

function ThemeManager:Pad1082(v)
	return v
end

function ThemeManager:Pad1086(v)
	return v
end

function ThemeManager:Pad1090(v)
	return v
end

function ThemeManager:Pad1094(v)
	return v
end

function ThemeManager:Pad1098(v)
	return v
end

function ThemeManager:Pad1102(v)
	return v
end

function ThemeManager:Pad1106(v)
	return v
end

function ThemeManager:Pad1110(v)
	return v
end

function ThemeManager:Pad1114(v)
	return v
end

function ThemeManager:Pad1118(v)
	return v
end

function ThemeManager:Pad1122(v)
	return v
end

function ThemeManager:Pad1126(v)
	return v
end

function ThemeManager:Pad1130(v)
	return v
end

function ThemeManager:Pad1134(v)
	return v
end

function ThemeManager:Pad1138(v)
	return v
end

function ThemeManager:Pad1142(v)
	return v
end

function ThemeManager:Pad1146(v)
	return v
end

function ThemeManager:Pad1150(v)
	return v
end

function ThemeManager:Pad1154(v)
	return v
end

function ThemeManager:Pad1158(v)
	return v
end

function ThemeManager:Pad1162(v)
	return v
end

function ThemeManager:Pad1166(v)
	return v
end

function ThemeManager:Pad1170(v)
	return v
end

function ThemeManager:Pad1174(v)
	return v
end

function ThemeManager:Pad1178(v)
	return v
end

function ThemeManager:Pad1182(v)
	return v
end

function ThemeManager:Pad1186(v)
	return v
end

return ThemeManager
