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

local text2, table_insert = {color1, "\tGLua Package Manager by Pika Software\n\n"}, table.insert
local function addTag( title, text )
    table_insert( text2, color2 )
    table_insert( text2, "\t" .. title .. ": " )
    table_insert( text2, color1 )
    table_insert( text2, text .. "\n" )
end

addTag("GitHub","https://github.com/Pika-Software/gpm")
addTag("Discord","https://discord.gg/3UVxhZj")
addTag("Web Site","http://pika-soft.ru")
table_insert( text2,"\n" )

MsgC( unpack( text2 ) )

if SERVER then
    AddCSLuaFile('gpm/sh_init.lua')
end

include('gpm/sh_init.lua')