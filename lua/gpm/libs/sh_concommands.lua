
module( "GPM", package.seeall )

CreateConVar("gpm_level", "3", FCVAR_NONE, "Minimal level of logging.", 1)

CreateConVar("gpm_developer", FCVAR_NONE, "Developer mode.", 0)
