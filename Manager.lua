local import = require(script.Parent.Utils.Import)

local mananger = {}

mananger.importrepo = function(GIT_REPO_OWNER :string, GIT_REPO_NAME :string)
	import.GET_REPO(GIT_REPO_OWNER,GIT_REPO_NAME)
end

return mananger
