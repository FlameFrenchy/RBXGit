local HTTP = game:GetService("HttpService")
local GITHUB_TOKEN = nil -- Set this to use the script.

local Git = {}

-- Helper to detect script type from filename
local function getScriptType(filename)
	if filename:match("%.mlua$") then -- CUSTOM MADE FOR "MODULE LUA" for Module Scripts
		return "Module Script"
	elseif filename:match("%.lua$") then 
		return "Script"
	elseif filename:match("%.llua$") then -- CUSTOM MADE FOR "LOCAL LUA" for Local Scripts
		return "Local Script"
	else
		return nil
	end
end

local function getLatestReleaseVersion(user, repo)
	local apiUrl = "https://api.github.com/repos/"..user.."/"..repo.."/releases/latest"

	-- Fetch the latest release info
	local success, result = pcall(function()
		return HTTP:JSONDecode(HTTP:GetAsync(apiUrl))
	end)

	if not success then
		warn("[PACKAGE] Failed to get the latest release for repo "..user.."/"..repo)
	end

	if result and result.name then
		-- Return the name field (which can contain the version number)
		return result.name
	else
		warn("[PACKAGE] No releases found for repo "..user.."/"..repo)
		return "v?"
	end
end

local function getWithAuth(url)
	local headers = {}

	if GITHUB_TOKEN then
		headers["Authorization"] = "token " .. GITHUB_TOKEN
	end

	local response = HTTP:RequestAsync({
		Url = url,
		Method = "GET",
		Headers = headers,
	})

	if response.Success then
		return response.Body
	else
		error("[PACKAGE] HTTP Error: " .. response.StatusCode .. " - " .. response.StatusMessage)
	end
end


function Git.ConnectGithub(token)
	GITHUB_TOKEN = token
end

-- Recursive fetcher
function Git.GET_REPO(user, repo, path, parent, isParent :boolean, wasConfirmed:boolean)
	local p = path
	local pa = parent
	local i = isParent
	local c = wasConfirmed
	path = p or ""
	parent = pa or game:GetService("ReplicatedStorage"):FindFirstChild("@"..user.."."..repo) or Instance.new("Folder")
	isParent = i or true
	
	wasConfirmed = c or false
	-- Create the root folder only if isParent is true (this means we are at the top level of the repo)
	
	if isParent and not parent.Parent then
		local title = "@"..user.."."..repo
		print("Starting import for:", title)
		parent.Name = title.. " ("..getLatestReleaseVersion(user, repo)..")"
		parent.Parent = game:GetService("ReplicatedStorage")
	end
	

	-- Set subfolder names
	if not isParent then
		local folderName = string.match(path, "[^/]+$") or path
		parent.Name = folderName
	end

	-- Fetch repo contents
	local apiUrl = "https://api.github.com/repos/"..user.."/"..repo.."/contents/"..path
	
	local success, rawResponse = pcall(function()
		return getWithAuth(apiUrl)
	end)

	if not success then
		error("[PACKAGE] Failed to fetch from GitHub: "..tostring(rawResponse))
	end

	local decodeSuccess, result = pcall(function()
		return HTTP:JSONDecode(rawResponse)
	end)

	if not decodeSuccess then
		warn("[PACKAGE] Failed to decode JSON response:")
		warn("Raw Response: ", rawResponse)
		error("[PACKAGE] Invalid JSON returned from GitHub API at "..apiUrl)
	end
	
	--print("Confirmed: ", wasConfirmed)
	local Compatible = wasConfirmed
	
	if Compatible == false then
		for _, item in ipairs(result) do
			if item.type == "file" and item.name == "Compatible.RBXGit" then
				-- Handle COMPATIBLE.RBXGit found
				print("[PACKAGE] Repo is compatible with RBXGIT.")
				Compatible = true

			end
		end
	end
	--print(Compatible)
	if Compatible == false then
		return warn("[PACKAGE] Repo is not compatible with RBXGIT. Cancelled download.")
	end


	-- Iterate through repo contents
	for _, item in ipairs(result) do
		if item.type == "file" then
			local iname :string = item.name
			local scriptType = getScriptType(item.name)
			if scriptType then
				-- Fetch file content
				local fileContentSuccess, code = pcall(function()
					return getWithAuth(item.download_url)
				end)

				if fileContentSuccess then
					-- Create and store script content as StringValue
					local scripta = Instance.new("StringValue")
					scripta.Name = item.name:gsub("%.module%.lua$",""):gsub("%.lua$","").. " (".. scriptType.. ")"
					scripta.Value = code
					scripta.Parent = parent
					
				else
					warn("[PACKAGE] Failed to get file:", item.download_url)
				end
				
			elseif iname:match("%.part$") then
				local rawJsonSuccess, rawJson = pcall(function()
					return getWithAuth(item.download_url)
				end)

				if rawJsonSuccess then
					local dataSuccess, data = pcall(function()
						return HTTP:JSONDecode(rawJson)
					end)

					if dataSuccess and typeof(data) == "table" then
						local part = Instance.new("Part")

						-- Size (expects array like [x, y, z])
						if data.Size then
							local ok, size = pcall(function()
								return Vector3.new(unpack(data.Size))
							end)
							if ok then part.Size = size end
						end

						-- Color (expects array like [r, g, b])
						if data.Color then
							local ok, color = pcall(function()
								return Color3.fromRGB(unpack(data.Color))
							end)
							if ok then part.Color = color end
						end

						-- Direct assignments with checks
						for prop, default in pairs({
							Transparency = 0,
							Reflectance = 0,
							CastShadow = true,
							Locked = false,
							Archivable = true,
							CanCollide = true,
							Anchored = false,
							CanTouch = true,
							}) do
							if typeof(data[prop]) == typeof(default) then
								part[prop] = data[prop]
							end
						end

						-- Enum-based fields
						if typeof(data.Material) == "string" and Enum.Material[data.Material] then
							part.Material = Enum.Material[data.Material]
						end

						if typeof(data.Shape) == "string" and Enum.PartType[data.Shape] then
							part.Shape = Enum.PartType[data.Shape]
						end

						part.Name = item.name:gsub("%.part$", "")
						part.Parent = parent
					else
						warn("[PACKAGE] Failed to decode JSON .part data: ", item.name)
						warn("Decode: ", data)
					end
				else
					warn("[PACKAGE] Failed to get .part file content:", item.download_url)
				end
			
			else
				if item.name == "Compatible.RBXGit" then
					continue
				end
				
				local fileContentSuccess, data = pcall(function()
					return getWithAuth(item.download_url)
				end)
				
				if fileContentSuccess then
					local val = Instance.new("StringValue")
					val.Value = data
					val.Name = item.name
					val.Parent = parent
				else
					warn("[PACKAGE] Failed to import (Non-Script) File content.")
				end
			end
		elseif item.type == "dir" then
			-- Create subfolder for directories
			local newFolder = Instance.new("Folder")
			newFolder.Name = item.name
			newFolder.Parent = parent

			-- Recurse into the subdirectory
			Git.GET_REPO(user, repo, item.path, newFolder, false, Compatible)
		end
	end
	if isParent then
		print("[PACKAGE] [🟢OK] Import Succesfull")
	end
end

return Git
