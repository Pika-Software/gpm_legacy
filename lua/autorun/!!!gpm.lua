module( "GPM", package.seeall )

-- Package Manager Version
Version = "2.2.0"

local col1, col2 = Color(60, 125, 250), Color(250, 225, 60)
function Logo()
    local t=""local function l(c)t=t.."\n\t"..c end l([[    ______     ______   __    __]])l([[   /\  ___\   /\  == \ /\ "-./  \]])l([[   \ \ \__ \  \ \  _-/ \ \ \-./\ \]])l([[    \ \_____\  \ \_\    \ \_\ \ \_\]])l([[     \/_____/   \/_/     \/_/  \/_/]])MsgC(col1,t,"\n\n")
end

local d, i = {col1, "\tgLua Package Manager by Pika Software\n\n"}, table.insert
function AddDescription(tl,tx)i(d,col2)i(d,"\t"..tl..": ")i(d,col1)i(d,tx.."\n")end
function Description()i(d,"\n")MsgC(unpack(d))end

AddDescription( "GitHub","https://github.com/Pika-Software/gpm" )
AddDescription( "Discord","https://discord.gg/3UVxhZj" )
AddDescription( "Web Site","http://pika-soft.ru" )

AddDescription( "\n\tDevelopers", "Retro & PrikolMen:-b" )
AddDescription( "Version", Version )
AddDescription( "License", "MIT" )

Logo()
Description()

if (SERVER) then
    AddCSLuaFile('gpm/sh_init.lua')
end

include('gpm/sh_init.lua')