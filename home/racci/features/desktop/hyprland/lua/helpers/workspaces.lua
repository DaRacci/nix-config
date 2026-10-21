local M = { }

M.NamedWorkspaces = {
  shadowRealm = "shadow-realm",
  special = "special",
  terminal = 1,
  browser = 2,
  files = 3,
  knowledge = 4,
  chat = 5,
  media = 6,
  development = 7,
  game = 8,
}

_G.NamedWorkspaces = M.NamedWorkspaces

return M
