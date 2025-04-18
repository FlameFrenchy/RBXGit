local HTTP = game:GetService("HttpService")
local Git = {}

-- Helper to detect script type from filename
local function getScriptType(filename)
	if filename:match("%.module%.lua$") then
		return "ModuleScript"
	elseif filename:match("%.lua$") then
		return "Script"
	else
		return nil
	end
end

-- Recursive fetcher
function Git.GET_REPO(user, repo, path, parent)
	path = path or ""
	parent = parent or game:GetService("ReplicatedStorage"):FindFirstChild("@"..user.."."..repo) or Instance.new("Folder")
	parent.Name = "@"..user.."."..repo
	parent.Parent = game:GetService("ReplicatedStorage")

	local apiUrl = "https://api.github.com/repos/"..user.."/"..repo.."/contents/"..path
	local success, result = pcall(function()
		return HTTP:JSONDecode(HTTP:GetAsync(apiUrl))
	end)

	if not success then
		error("[PACKAGE] Failed to get repo content at "..apiUrl)
	end

	for _, item in ipairs(result) do
		if item.type == "file" then
			local scriptType = getScriptType(item.name)
			if scriptType then
				local fileContentSuccess, code = pcall(function()
					return HTTP:GetAsync(item.download_url)
				end)
				if fileContentSuccess then
					local script = Instance.new(scriptType)
					script.Name = item.name:gsub("%.module%.lua$",""):gsub("%.lua$","")
					script.Source = code
					script.Parent = parent
				else
					warn("[PACKAGE] Failed to get file:", item.download_url)
				end
			else
				warn("[PACKAGE] Skipped non-script file:", item.name)
			end
		elseif item.type == "dir" then
			local newFolder = Instance.new("Folder")
			newFolder.Name = item.name
			newFolder.Parent = parent
			Git.GET_REPO(user, repo, item.path, newFolder)
		end
	end
end

return Git
