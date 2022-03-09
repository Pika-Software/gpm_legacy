local text1 = ""
function addLine(c)
    text1 = text1 .. "\n\t" .. c
end

addLine("    ______     ______   __    __")
addLine([[   /\  ___\   /\  == \ /\ "-./  \]])
addLine([[   \ \ \__ \  \ \  _-/ \ \ \-./\ \]])
addLine([[    \ \_____\  \ \_\    \ \_\ \ \_\]])
addLine([[     \/_____/   \/_/     \/_/  \/_/]])

local color1, color2 = Color(60, 125, 250), Color(250, 225, 60)
MsgC( color1, text1, "\n\n" )

local h = {color1, "\tGLua Package Manager by Pika Software\n\n"}

local insert = table.insert
local function addTag( title, text )
    insert( h, color2 )
    insert( h, "\t" .. title .. ": " )
    insert( h, color1 )
    insert( h, text .. "\n" )
end

addTag("GitHub","https://github.com/Pika-Software/gpm")
addTag("Discord","https://discord.gg/3UVxhZj")
addTag("Web Site","http://pika-soft.ru")
insert( h,"\n" )

MsgC( unpack( h ) )

if SERVER then
    AddCSLuaFile('gpm/sh_init.lua')
end

include('gpm/sh_init.lua')